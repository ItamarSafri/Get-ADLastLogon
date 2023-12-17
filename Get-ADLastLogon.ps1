Function Get-ADLastLogon {
    <#
    .SYNOPSIS
        Retrieves the last logon information for user or computer objects in Active Directory.

    .DESCRIPTION
        This function queries the last logon information for user or computer objects in Active Directory.
        It supports specifying the object type (User or Computer), the object name, search base, and optional filter.

    .PARAMETER ObjectType
        Specifies the type of objects to retrieve last logon information for.
        Valid values are "User" or "Computer".

    .PARAMETER ObjectName
        Specifies the name of the specific object to retrieve last logon information for.
        Use this parameter in conjunction with ObjectType "User" or "Computer".

    .PARAMETER SearchBase
        Specifies the search base for the query. Use this parameter when retrieving objects within a specific organizational unit (OU).

    .PARAMETER Filter
        Specifies an optional filter for the query.

    .PARAMETER Throttle
        Specifies the maximum number of concurrent queries to Domain Controllers. Default value is 5.

    .EXAMPLE
        Get-ADLastLogon -ObjectType User -SearchBase "OU=test,DC=domain,DC=local" -Filter {Enabled -eq $true}
        Retrieves last logon information for enabled user objects within the specified OU.

    .NOTES
        File Name      : Get-ADLastLogon.ps1
        Prerequisite   : PowerShell 5.1 or later
        Author         : Itamar Safri

#>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("User","Computer")]
        [string]$ObjectType, 
        [Parameter(Position=1,Mandatory=$false, ParameterSetName='Object')]
        [string]$ObjectName,
        [Parameter(Position=1,Mandatory=$false, ParameterSetName='OU')]
        [string]$SearchBase,
        [Parameter(Mandatory=$false)]
        [String]$Filter,
        [Parameter(Mandatory=$false)]
        [int]$Throttle = 5
    )

    $WarningPreference = "SilentlyContinue"

    # Check if the Active Directory module is available
    try{
        Import-Module ActiveDirectory -ErrorAction Stop
    }catch{
        throw "Can't find AD Module. Please install it first"
    }

    try{
        Import-Module Invoke-Parallel -ErrorAction Stop
    }catch{
        throw "Error: Can't find Invoke-Parallel Module. Please install it first"
    }

    if ($ObjectType -eq "User"){
        $global:command = "Get-ADUser"
    } elseif ($ObjectType -eq "Computer"){
        $global:command = "Get-ADComputer"
    }

    if ($SearchBase){
        $global:command += " -SearchBase `"$($SearchBase)`""
    } elseif ($ObjectName){
        $global:command += " -Identity `"$($ObjectName)`""
    }

    if ($Filter){
        $global:command += " -Filter {$Filter}"
    } elseif ($SearchBase){
        $global:command += " -Filter *"
    }

    $global:command += ' -Server {} -Properties lastlogon, lastlogondate, WhenCreated -ErrorAction Stop'
    $DC = Get-ADDomainController
    $DCou = $DC.ComputerObjectDN.Replace("CN=$($DC.Name),", "")
    $DCs = Get-ADComputer -SearchBase $DCou -Filter *

    $all = $DCs.Name | Invoke-Parallel -ImportVariables -ImportModules -Throttle $Throttle -WarningAction SilentlyContinue {
        $tempCMD = $global:command.Replace("{}", $_)
        Write-Verbose "Running Command: $tempCMD"
        $scriptBlock = [ScriptBlock]::Create($tempCMD)
        try {
            $result = Invoke-Command $scriptBlock -ErrorAction Stop
            Write-Verbose "Successfully retrieved data from $_"
            $result
        } catch {
            Write-Warning "Failed to query DC $_. Will try again in 10 seconds."
            Write-Warning "Error: $($_.Exception.Message)"
            Sleep -Seconds 10
            Invoke-Command $scriptBlock -ErrorAction Stop
        }
    }

    $groups = $all | Group-Object SamAccountName

    $groups | Invoke-Parallel -ImportModules -ImportVariables -WarningAction SilentlyContinue -ErrorAction Ignore {
        $group = $_
        $times = @()

        foreach ($obj in $group.Group){
            if ($obj.lastlogon -ne $null){
                $times += [datetime]::FromFileTime($obj.lastlogon)
            } else {
                Write-Verbose "$($obj.Name) - no lastlogon"
            }
        }

        $adlastlogon = $times | Sort-Object -Descending | Select-Object -First 1
        if ($adlastlogon){
            $group.Group | Where-Object { $_.LastLogon -eq $adlastlogon.ToFileTime() } | 
                Select-Object * , @{N="RealLastLogonDate";E={[datetime]::FromFileTime($_.lastlogon)}} -ExcludeProperty PropertyNames, AddedProperties, RemovedProperties, ModifiedProperties, PropertyCount
        } else {
            Write-Verbose "$($obj.Name) - no lastlogon"
        }
    }
}
