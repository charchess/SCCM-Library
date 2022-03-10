clear
#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '12/15/2021 10:22:06 AM'.

# Site configuration
$SiteCode = "M01" # Site code 
$ProviderMachineName = "INFFRPA3017.EU.DIR.GRPLEG.COM" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

$OUTPUT_FOLDER="$env:APPDATA\..\Local\Temp\"
Remove-Item $OUTPUT_FOLDER\pam_extract.csv -ErrorAction SilentlyContinue


function get-ADGroupAllMembers
{
    Param(
        [Parameter(Mandatory=$true)][string] $DN
    )
    [System.Collections.ArrayList] $Users = @()

    $null=$DN -match '^.*?,((DC=.+)+)$'
    $root=($matches[$matches.count-1]).replace("DC=","").replace(",",".")

    $ADObject=get-adobject -Identity $DN -Server $root -ErrorAction SilentlyContinue
    switch($ADObject.objectClass)
    {
        "group" 
        {
            $ADObjects=get-adobject -Identity $DN -Server $root -Properties member -ErrorAction SilentlyContinue
            foreach($item in ($ADObjects.member))
            {
                $null=$Users+=(get-ADGroupAllMembers -DN $item)
            }
        }
        "user" 
        {
            $Users+=$ADObject
        }
        default {write-host "Error with $DN $($ADObject.objectClass) $($ADObject.DistinguishedName)"}
    }
    return $Users
}

Class User
{
    [string] $sAMAccountName
    [string] $Name
    [string] $Domain=''
    [bool] $LocalAdmin=$false
    [bool] $RDPUser=$false
    
    User([string] $sAMAccountName, [string] $Name, [string] $Domain, [bool] $LocalAdmin, [bool] $RDPUser)
    {
        $this.sAMAccountName=$sAMAccountName
        $this.Name=$Name
        $this.Domain=$Domain
        $this.LocalAdmin=$LocalAdmin
        $this.RDPUser=$RDPUser
    }
}


function query-Device
{
    # failing for group on domainA nesting group of domainB
    # TBD : rewrite get-adgroupmember function ....
    param(
        [string] $device
    )
    $Users=[System.Collections.Generic.List[User]]::new()
    
    $SCCMserver="INFFRPA3017"
    $SCCMnameSpace = "root\SMS\site_M01"
    
    $filter_RDPUsers="SMS_G_System_HWINV_RDPUSERS"
    $filter_LocalAdmins="SMS_G_System_LEGRAND_HWINV_LocalAdmins_1_0"

    # for that device, return a list of users and their status as admin/RDP users

    $CMdevice=Get-CMDevice -Name $device

    # we get data from AD
    $server="$($CMDevice.domain).DIR.GRPLEG.COM"
    $ADDevice=Get-ADComputer -filter "sAMAccountName -eq `'$($Device + '$')`'" -server $server -properties Description

    # we get LocalAdmins from SCCM
    $qry_LocalAdmins = "Select * from $filter_LocalAdmins where ResourceID = '$($CMdevice.ResourceID)'"
    $LocalAdmins = Get-WmiObject -ComputerName $SCCMserver -Namespace $SCCMnameSpace -Query $qry_LocalAdmins

    # We get RDP Users from SCCM
    $qry_RDPUsers = "Select * from $filter_RDPUsers where ResourceID = '$($CMdevice.ResourceID)'"
    $RDPUsers = Get-WmiObject -ComputerName $SCCMserver -Namespace $SCCMnameSpace -Query $qry_RDPUsers

    # On parcours la liste des local admins
    foreach($LocalAdmin in $LocalAdmins)
    {
        if(($Users.Count -eq 0) -or -not($Users.Name.contains($LocalAdmin)))
        {
            $split=($LocalAdmin.Member).Split("\\")
            $userDomain=$split[0]
            $userName=$split[1]
            $userServer="$userDomain.DIR.GRPLEG.COM"
            if(@("EU", "AS", "AM") -notcontains $userDomain)
            {
                # on ne traite que les comptes et groupes du domaine
                continue
            }
            if($userName -match '\$$')
            {
                # on ne traite pas les comptes machines
                continue
            }

            $Root = [adsi] "LDAP://$userServer"
            $Searcher = new-object System.DirectoryServices.DirectorySearcher($root)
            $Searcher.filter = "(&(objectClass=user)(sAMAccountName= $userName))"

            if($Searcher.FindOne())
            {
                # il s'agit d'un user AD
                $ADuser=Get-ADUser -Server $server -Filter "SAMAccountName -eq '$username'" -Properties Manager, Department, Description
                if(($Users.count -eq 0) -or -not($Users.sAMAccountName.contains("$userName")))
                {
                    $null=$Users.Add([User]::new($username, "$($ADUser.givenName) $($ADUser.Surname)", $userDomain, $true, $false))
                }
            } else {
                $Searcher.filter = "(&(objectClass=group)(sAMAccountName= $userName))"
                if($Searcher.FindOne())
                {
                    $server="$userDomain.DIR.GRPLEG.COM"
                    # il s'agit d'un groupe AD
                    $DN=(Get-ADGroup -identity $userName -server $server).DistinguishedName
                    foreach($ADMember in (get-ADGroupAllMembers -DN $DN))
                    {
                        $ADuser=Get-ADUser -Server $server -Filter "SAMAccountName -eq '$($ADMember.Name)'" -Properties Manager, Department, Description
                        if(($Users.count -eq 0) -or -not($Users.sAMAccountName.Contains("$($ADMember.Name))")))
                        {
                            # l'utilisateur n'est pas encore dans la liste
                            $null=$ADMember.distinguishedName -match "(..),DC=DIR,DC=GRPLEG,DC=COM"
                            $userDomain=$matches[1]
                            $null=$Users.Add([User]::new($ADUser.sAMAccountName, "$($ADUser.givenName) $($ADUser.Surname)", $userDomain, $false, $true))
                        }
                    }
                }
            }
        }
    }

    # On parcours la liste des RDPUsers
    foreach($RDPUser in $RDPUsers)
    {
        $split=($RDPUser.Member).Split("\\")
        $userDomain=$split[0]
        $userName=$split[1]
        $userServer="$userDomain.DIR.GRPLEG.COM"

        if(@("EU", "AS", "AM") -notcontains $userDomain)
        {
            # on ne traite que les comptes et groupes du domaine
            continue
        }
        if($userName -match '\$$')
        {
            # on ne traite pas les comptes machines
            continue
        }
        $Root = [adsi] "LDAP://$userServer"
        $Searcher = new-object System.DirectoryServices.DirectorySearcher($root)
        $Searcher.filter = "(&(objectClass=user)(sAMAccountName= $userName))"
        if($Searcher.FindOne())
        {
            # c'est un user
            $ADuser=Get-ADUser -Server $userserver -Filter "SAMAccountName -eq '$username'" -Properties Manager, Department, Description
            if($Users.sAMAccountName.contains("$($ADUser.samAccountName)"))
            {
                ($Users.where({$_.sAMAccountName -eq "$($ADUser.samAccountName)"}))[0].RDPUser=$true
            } else {
                $null=$Users.Add([User]::new($ADUser.sAMAccountName, "$($ADUser.givenName) $($ADUser.Surname)", $userDomain, $false, $true))
            }
        } else {
            $Searcher.filter = "(&(objectClass=group)(sAMAccountName= $userName))"
            if($Searcher.FindOne())
            {
                # il s'agit d'un groupe AD
                $server="$userDomain.DIR.GRPLEG.COM"
                $DN=(Get-ADGroup -identity $userName -server $server).DistinguishedName
                foreach($ADMember in(get-ADGroupAllMembers -DN $DN))
                {
                    $ADuser=Get-ADUser -Server $server -Filter "SAMAccountName -eq '$($ADMember.Name)'" -Properties Manager, Department, Description
                    # l'utilisateur n'est pas encore dans la liste
                    $null=$ADMember.distinguishedName -match "(..),DC=DIR,DC=GRPLEG,DC=COM"
                    $userDomain=$matches[1]
                    if($Users.sAMAccountName.contains("$($ADUser.samAccountName)"))
                    {
                        ($Users.where({$_.sAMAccountName -eq "$($ADUser.samAccountName)"}))[0].RDPUser=$true
                    } else {
                        $null=$Users.Add([User]::new($($ADUser.samAccountName), "$($ADUser.givenName) $($ADUser.Surname)", $userDomain, $false, $true))
                    }
                }
            }
        }     
    }    
    return $Users
}


function export-wavestone 
{
    param(
        [Parameter(Mandatory=$false)][string] $FilePath="$env:USERPROFILE\documents\wavestone.csv",
        [Parameter(Mandatory=$true)][string]  $CollectionName

    )
    "Datacenter, sAMAccountName, User, Domain, isLocalAdmin, isRDPUser"| Out-File -FilePath $FilePath

    $devices=Get-CMDevice -CollectionName $CollectionName
    $count=0
    foreach($device in $devices)
    {
        Write-Progress -PercentComplete ([math]::round(100*$count/$devices.count,4)) -Activity "Checking $($device.Name) from collection $collectionName" -Status "$count / $($devices.count) ($([math]::round(100*$count/$devices.count,4))%)"
        $ADComputer=Get-ADComputer -Server "$($device.Domain).DIR.GRPLEG.COM" "$($device.Name)"
        if(($ADComputer.DistinguishedName) -match "OU=Servers,OU=([^,]*)")
        {
            $Datacenter=$matches[1]
        } else {
            $Datacenter="unknown"
        }
        $deviceInfos=query-Device($device.Name)
        foreach($di in $deviceInfos)
        {
            "$Datacenter, $($device.Name), $($di.sAMAccountName), $($di.Name), $($di.Domain), $($di.LocalAdmin), $($di.RDPUser)" | Out-File -Append -FilePath $FilePath
        }
        $count++
    }
}


