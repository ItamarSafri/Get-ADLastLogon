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

    .PARAMETER DCou
        Specifies the distinguished name (DN) of the Organizational Unit (OU) containing Domain Controllers.
        Default value is "OU=Domain Controllers,DC=domain,DC=local".

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
    
        if ($ObjectType -eq "User"){
            $global:command = "Get-ADUser"
        }elseif($ObjectType -eq "Computer"){
            $global:command = "Get-ADComputer"
        }else{
        }
        if ($SearchBase){
            $global:command += " -SearchBase `"$($SearchBase)`""
        }elseif($ObjectName){
            $global:command += " -Identity `"$($ObjectName)`""
        }
        if ($Filter){
            $global:command += " -Filter {$Filter}"
        }elseif($SearchBase){
            $global:command += " -Filter *"
        }
    
    
        $global:command += ' -Server {} -Properties lastlogon, lastlogondate, WhenCreated -ErrorAction Stop'
        $DCou = "OU=Domain Controllers,DC=domain,DC=local"

        $DCs = Get-ADComputer -SearchBase $DCou -Filter *
    
        $all = $DCs.Name | Invoke-Parallel -ImportVariables -ImportModules -Throttle $Throttle -WarningAction SilentlyContinue {
            $tempCMD = $global:command.Replace("{}", $_)
            $scriptBlock = [ScriptBlock]::Create($tempCMD)
            Write-verbose "Running Command: $tempCMD"
            try{
                Invoke-Command $scriptBlock
            }catch{
                Write-Host "Failed to Query DC - $($_). Will try again in 10 seconds .."
                Write-Host "Error: $($Error[0])"
                Sleep -Seconds 10
                Invoke-Command $scriptBlock -ErrorAction Stop
            }
        }
    
        $groups = $all | Group SamAccountName
    
        $groups | Invoke-Parallel -ImportModules -ImportVariables -WarningAction SilentlyContinue -ErrorAction Ignore {
            $group = $_
            $times = @()
            foreach ($obj in $group.Group){
                if ($obj.lastlogon -ne $null){
                    $times += [datetime]::FromFileTime($obj.lastlogon)
                }else{
                    Write-Verbose "$($obj.Name) - no lastlogon"
                }
            }
            $adlastlogon = $times | Sort -Descending | Select -First 1
            if ($adlastlogon){
                $group.Group | ? {$_.LastLogon -eq $adlastlogon.ToFileTime()} | Select * , @{N="RealLastLogonDate";E={[datetime]::FromFileTime($_.lastlogon)}} -ExcludeProperty PropertyNames, AddedProperties, RemovedProperties, ModifiedProperties, PropertyCount
            }else{
                Write-Verbose "$($obj.Name) - no lastlogon"
            }
        }
    }
