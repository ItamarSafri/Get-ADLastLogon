
# Get-ADLastLogon PowerShell Script
## Overview
The Get-ADLastLogon PowerShell script is designed to retrieve the last logon information for user or computer objects in Active Directory. The challenge in obtaining accurate last logon information is addressed by considering two primary attributes: Last-Logon and Last-Logon-Timestamp. Both attributes represent the last time a user logged on to a domain, but they come with different replication characteristics.

### The Challenge
#### LastLogon Attribute
The Last-Logon attribute contains a Windows FileTime representation of the last time a domain controller successfully authenticated the user. However, it is stored per domain controller, making it challenging to obtain accurate, real-time last logon information.

#### LastLogonTimestamp Attribute
The Last-Logon-Timestamp attribute is a replicated attribute introduced with Microsoft Windows Server 2003. Unlike Last-Logon, Last-Logon-Timestamp is synced to every domain controller, providing a more consistent view of user logon times. However, caution is advised as it may not always reflect the most recent logon due to specific replication intervals.

### The Solution
To address the challenge, the script leverages the Last-Logon attribute for its accuracy and retrieves this information from each domain controller. By querying each domain controller and determining the latest Last-Logon timestamp, the script provides a more accurate representation of the user's last logon in a multi-DC domain.

### Usage
#### Parameters
* ObjectType: Specifies the type of objects to retrieve last logon information for. Valid values are "User" or "Computer".
* ObjectName: Specifies the name of the specific object to retrieve last logon information for. Use this parameter in conjunction with ObjectType "User" or "Computer".
* SearchBase: Specifies the search base for the query. Use this parameter when retrieving objects within a specific organizational unit (OU).
* Filter: Specifies an optional filter for the query.
* Throttle: Specifies the maximum number of concurrent queries to Domain Controllers. Default value is 5.

### Examples
```
# Example 1: Retrieve accurate last logon information for enabled user objects within a specific OU
Get-ADLastLogon -ObjectType User -SearchBase "OU=test,DC=domain,DC=local" -Filter {Enabled -eq $true}

# Example 2: Retrieve accurate last logon information for computer objects containing the text "Backup" in the name
Get-ADLastLogon -ObjectType Computer -SearchBase "OU=Computers,DC=domain,DC=local" -Filter {Name -like "*Backup*"}
```
