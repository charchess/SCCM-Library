class IP : System.IComparable
{
    hidden static $_maskType = 
    @{
        MemberType = 'ScriptProperty'
        Name = 'mask'
        Value = 
        {
          return $this._mask
        }
        SecondValue = 
        {
            param($value)
            $this.setMask($value)
        }
    }
    hidden [string]$_mask
    
    hidden static $_addressType = 
    @{
        MemberType = 'ScriptProperty'
        Name = 'address'
        Value = 
        {
          return $this._address
        }
        SecondValue = 
        {
            param($value)
            $this.setAddress($value)
        }
    }
    hidden [string]$_address
    
    hidden static $_prefixType = 
    @{
        MemberType = 'ScriptProperty'
        Name = 'prefix'
        Value = 
        {
          return $this._prefix
        }
        SecondValue = 
        {
            param($value)
            $this.setPrefix($value)
        }
    }
    hidden [uint32]$_prefix

    hidden static $_IPIDType = 
    @{
        MemberType = 'ScriptProperty'
        Name = 'IPID'
        Value = 
        {
          return $this._IPID
        }
        SecondValue = 
        {
            param($value)
            $this.setIPID($value)
        }
    }
    hidden [uint32]$_IPID


    [string] $startIP
    [string] $EndIP
    [uint32] $startIPID
    [uint32] $EndIPID
    

    Constructor_common()
    {
        $mask = $this::_maskType
        $this |Add-Member @mask
        $address = $this::_addressType
        $this |Add-Member @address
        $prefix = $this::_prefixType
        $this |Add-Member @prefix
        $IPID = $this::_IPIDType
        $this |Add-Member @IPID
    }
    IP()
    {
        $this.Constructor_common()
    }
    IP([string] $Address)
    {
        $this.Constructor_common()
        if($Address -match '^[\s]*(\d*.\d*.\d*.\d*)[\s]*$')
        {
            $this.setAddress($matches[1])
        } elseif ($Address -match '^[\s]*(\d*.\d*.\d*.\d*)[\s]*\/[\s]*(\d*)[\s]*$')
        {
            $tmpIP=$matches[1]
            $tmpPrefix=$matches[2]
            $this.setAddress($tmpIP)
            $this.setPrefix($tmpPrefix)
        } elseif ($Address -match '^[\s]*(\d*.\d*.\d*.\d*)[\s]*\/[\s]*(\d*.\d*.\d*.\d*)[\s]*$')
        {
            $tmpIP=$matches[1]
            $tmpmask=$matches[2]
            $this.setAddress($tmpIP)
            $this.setMask($tmpMask)
        }
    }
    SetAddress([string] $Address)
    {
        if($this._address -eq $address)
        {
            return
        }
        $this._address=$address
        $this.refreshIPID()
        $this.refreshInfos()
    }

    SetPrefix([uint32] $prefix)
    {
        if($this._prefix -eq $prefix)
        {
            return
        }
        $this._prefix=$prefix
        $this.refreshMask()
        $this.refreshInfos()
    }
    
    SetMask([string] $mask)
    {
        if($this._mask -eq $mask)
        {
            return
        }
        $this._mask=$mask
        if(($tmpPrefix=$this.mask2prefix($mask)) -ne $this.prefix)
        {
            $this._prefix=$tmpPrefix
        }
        $this.refreshInfos()
    }

    SetIPID([uint32] $IPID)
    {
        if($this._IPID -eq $IPID)
        {
            return
        }
        $this._IPID=$IPID
        $this.refreshAddress()
        $this.refreshInfos()
    }

    refreshIPID()
    {
        $id=$this.ip2id($this._address)
        $this.setIPID($id)
    }

    refreshMask()
    {
        if(($tmpMask=$this.prefix2Mask($this._prefix)) -ne $this._mask)
        {
            $this._mask=$tmpMask
        }
    }

    refreshAddress()
    {
        if(($tmpAddress=$this.ID2IP($this._IPID)) -eq $this._address)
        {
            return
        }
        $this._address=$tmpAddress
    }

    refreshInfos()
    {
        if(($this._mask -eq 0) -or ($this._address -eq 0))
        {
            return
        }
        $this.startIPID=($this._IPID -band ([uint32]::MaxValue - (([math]::pow(2,(32 - $this.prefix))-1))))
        $this.startIP=$this.ID2IP($this.startIPID)
        $this.EndIPID=($this._IPID -bor (([math]::pow(2,(32 - $this.prefix))-1)))
        $this.EndIP=$this.ID2IP($this.EndIPID)
    }

    [string] prefix2mask ([uint32]$prefix)
    {
        if($prefix -eq 0) {return "0.0.0.0"}
        elseif($prefix -gt 0 -and $prefix -le 32)
        {
            return $this.ID2IP(([uint32]::MaxValue) -shl (32 - $prefix))
        } else {
            throw "invalid prefix : $prefix"
        }
    }
    [uint32] IP2ID([string] $IP)
    {
        $blocks=$IP.split(".")
        $ID=0
        foreach($i in $blocks)
        {
            $ID*=256
            $ID+=$i
        }
        return [uint32] $ID
    }
    [string] ID2IP([uint32] $ID)
    {
        $IP=""
        for($i=1;$i -le 4;$i++)
        {
            $IP=[string]($ID -band 255) + ".$($IP)"
            $ID = [math]::Floor($ID / 256)
        }
        return $IP.Substring(0,$IP.Length-1)
    }

    [int] mask2prefix ([string] $mask)
    {
        $mask=$mask.replace(' ','')
        $maskID=$this.ip2id($mask)
        for($i=0;($i -le 32);$i++)
        {
            $k=[math]::pow(2, 32) - [math]::Pow(2,(32-$i))
            if($k -eq $maskID)
            {
                return [int] $i
            }
        }
        throw("this mask $mask is not a proper mask")
    }
    
    [int] CompareTo($IPAddress) 
    { 
        if($IPAddress -is [string])
        {
            $IPAddress=[IP] $IPAddress
        }
        if($IPAddress -is [IP])
        {
            if($IPAddress.IPID -lt $this.IPID)
            {
                return 1
            } 
            elseif($IPAddress.IPID -gt $this.IPID)
            {
                return -1
            } 
            elseif($IPAddress.IPID -eq $this.IPID)
            {
                return 0
            }
        } else {
            throw("unsoppored type ($($IPAddress.gettype())) for $IPAddress")
        }
        return $false
    }
    [string] ToString()
    {
        return $this.Address
    }
}

Class IPrange : System.IComparable
{
    [IP] $IPStart
    [IP] $IPEnd
    [uint32] $size=0

    IPRange ([IP] $StartIP, [IP] $EndIP)
    {
        $this.IPStart=[IP] $StartIP
        $this.IPEnd=[IP] $EndIP
        $this.size=$this.IPEnd.IPID - $this.IPStart.IPID
    }
    IPRange ([string] $IPrange)
    {
        $IPrange=$IPrange.Replace(' ','')
        if($IPrange -match '^(\d*\.\d*\.\d*\.\d*)-(\d*\.\d*\.\d*\.\d*)$')
        {
            $this.IPStart=[IP] $matches[1]
            $this.IPEnd=[IP] $matches[2]
        } elseif($IPrange -match '^(\d*\.\d*\.\d*\.\d*)/(\d*)$')
        {
            $IP=[IP] $IPrange
            $this.IPStart=$IP.startIP
            $this.IPEnd=$IP.EndIP
        } elseif($IPrange -match '^(\d*\.\d*\.\d*\.\d*)/(\d*\.\d*\.\d*\.\d*)$')
        {
            $IP=[IP] $IPrange
            $this.IPStart=$IP.startIP
            $this.IPEnd=$IP.EndIP
        }
        $this.size=$this.IPEnd.IPID - $this.IPStart.IPID
    }
    IPRange ()
    {
    }
    [bool] Merge([IPRange] $extension)
    { 
        $isMerged=$false
        if(($extension.IPStart.IPID -le ($this.IPEnd.IPID + 1)) -and ($extension.IPEnd.IPID -gt $this.IPEnd.IPID))
        {
            $this.IPEnd = $extension.IPEnd
            $isMerged=$true
        }
        if(($extension.IPEnd.IPID -ge ($this.IPStart.IPID - 1)) -and ($extension.IPStart.IPID -lt $this.IPStart.IPID))
        {
            $this.IPStart = $extension.IPStart
            $isMerged=$true
        }
        if(($extension.IPStart.IPID -ge ($this.IPStart.IPID)) -and ($extension.IPEnd.IPID -le $this.IPEnd.IPID))
        {
            $isMerged=$true
        }
        return $isMerged
    }
    [int] CompareTo($val)
    {
        return 0
    }
    [string] Compare([IPRange] $testedIPRange)
    {
        $found="NONE" # the tested IP has no common ground with us
        if(($testedIPRange.IPStart.IPID -eq $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -eq $this.IPEnd.IPID))
        {
            # the tested IP is matching us perfectly
            $found= "PERFECT_MATCH"
        }
        elseif(($testedIPRange.IPStart.IPID -le $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -ge $this.IPEnd.IPID))
        {
            # the tested IP is covering us
            $found= "INCLUDED"
        }
        elseif(($testedIPRange.IPStart.IPID -ge $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -le $this.IPEnd.IPID))
        {
            # the tested IP is covered by us
            $found= "COVERED"
        }
        elseif((($testedIPRange.IPStart.IPID -ge $this.IPStart.IPID) -and ($testedIPRange.IPStart.IPID -le $this.IPEnd.IPID)) -or (($testedIPRange.IPEnd.IPID -ge $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -le $this.IPEnd.IPID)))
        {
            # the tested IP and us are partially covering each over
            $found= "OVERLAP"
        } 
        elseif(($testedIPRange.IPStart.IPID -eq ($this.IPEnd.IPID + 1)) -or ($testedIPRange.IPEnd.IPID -eq ($this.IPStart.IPID - 1)))
        {
            # the tested IP is just after or before us
            $found= "EXTENDING"
        }
        return $found
    }
    [string] ToString()
    {
        return "$($this.IPStart.Address)-$($this.IPEnd.Address)"
    }
    static [IPRange] op_Addition([IPRange] $a, [IPRange] $b) 
    { 
        $return=[IPRange] "$($b)" 
        $isExtended=$false
        if(($a.IPStart.IPID -ge ($return.IPStart.IPID)) -and ($a.IPEnd.IPID -le $return.IPEnd.IPID))
        {
            $isExtended=$true
        }
        if(($a.IPStart.IPID -le ($return.IPEnd.IPID + 1)) -and ($a.IPEnd.IPID -gt $return.IPEnd.IPID))
        {
            $return.IPEnd = $a.IPEnd
            $isExtended=$true
        }
        if(($a.IPEnd.IPID -ge ($return.IPStart.IPID - 1)) -and ($a.IPStart.IPID -lt $return.IPStart.IPID))
        {
            $return.IPStart = $a.IPStart
            $isExtended=$true
        }
        if($isExtended)
        {
            return $return
        } else {
            throw("$a and $b have no common subnet to build merge on ")
        }
    }
}

Class IPRanges : System.IComparable
{
    [System.Collections.Generic.List[IPRange]] $Ranges

    IPRanges ($IPRange)
    {
        $this.Ranges = [System.Collections.Generic.List[IPRange]]::new()        
        $this.Ranges.add($IPRange)
    }

    IPRanges ()
    {
        $this.Ranges = [System.Collections.Generic.List[IPRange]]::new()        
    }

    AddRange ([IPRange] $IPRange)
    {
        $this.Ranges.add($IPRange)
        $this.FullMergeRanges()
        # TBD: optimiser en faisant un merge selectif/recursif
    }
    RemoveRange ([IPRange] $IPRangeToRemove)
    {
        for($i = 0; $i -lt ($this.Ranges).Count; $i++)
        {
            if($IPRangeToRemove.IPStart.IPID -le $this.Ranges[$i].IPStart.IPID )
            {
                # le debut du segment a supprimer commence avant le debut du segment cible 
                if($IPRangeToRemove.IPEnd.IPID -ge $this.Ranges[$i].IPEnd.IPID)
                {
                    # ET la fin du segment a supprimer est apr??s la fin du segment cible
                    $this.Ranges.removeat($i)
                } 
                elseif($IPRangeToRemove.IPEnd.IPID -ge $this.Ranges[$i].IPStart.IPID)
                {
                    # ET la fin du segment a supprimer est avant la fin du segment cible 
                    $this.Ranges[$i].IPStart.IPID=$IPRangeToRemove.IPEnd.IPID+1
                }
            }
            elseif($IPRangeToRemove.IPStart.IPID -le $this.Ranges[$i].IPEnd.IPID)
            {
                # le debut du segment a supprimer est avant la fin du segment cible (mais apr??s le d??but car "else")
                if($IPRangeToRemove.IPEnd.IPID -ge $this.Ranges[$i].IPEnd.IPID)
                {
                    # La fin du segment a supprimer est au dela du segment cible 
                    $this.Ranges[$i].IPEnd.IPID=$IPRangeToRemove.IPStart.IPID-1
                } 
                else
                {
                    # on a un segment a supprimer au milieu d'un autre segment -> split de segment
                    $newIPStart=[IP] ($IPRangeToRemove.IPEnd.Address)
                    $newIPStart.IPID=$newIPStart.IPID+1
                    $newIPEnd=[IP] ($this.Ranges[$i].IPEnd.Address)
                    $newIPRange=[IPRange] "$newIPStart-$newIPEnd"
                    $this.Ranges.Add($newIPRange)
                    $this.Ranges[$i].IPEnd.IPID=$IPRangeToRemove.IPStart.IPID-1
                }
            }
        }
    }
    SplitRange ([int] $val)
    {
        # TBD
    }
    FullMergeRanges()
    {
        for($j = 0; $j -lt ($this.Ranges).Count; $j++)
        {
            for($i = 0; $i -lt ($this.Ranges).Count; $i++)
            {
                if($i -eq $j)
                {
                    continue
                }
                if(($null -ne $this.Ranges[$i]) -and ($this.Ranges[$i].Merge($this.Ranges[$j])))
                {
                    $this.Ranges.removeat($j)
                }
            }
        }
    }
    [string] ToString()
    {  
        [string] $string=""
        foreach($IPRange in $this.Ranges)
        {
            $string+="$IPRange "
        }
        if($string.length -gt 0)
        {
            $string=$string.Substring(0, $string.Length-1)
        }
        return $string
    }
    [int] CompareTo($val)
    {
        return 0
    }
    [bool] isCoveredBy([IPRange] $range)
    {
        foreach($r in $this.Ranges)
        {
            switch($err=$r.Compare($range))
            {
                "PERFECT_MATCH" {return $true}
                "INCLUDED" {return $true}
                "COVERED" {return $false}
                "NONE" {return $false}
                "OVERLAP" {return $false}
                "EXTENDING" {return $false}
                default {throw("error : $err")}
            }
        }
        return $false
    }
    [bool] isCovering([IPRange] $range)
    {
        foreach($r in $this.Ranges)
        {
            switch($err=$range.Compare($r))
            {
                "PERFECT_MATCH" {return $true}
                "INCLUDED" {return $true}
                "COVERED" {return $false}
                "NONE" {return $false}
                "OVERLAP" {return $false}
                "EXTENDING" {return $false}
                default {throw("error : $err")}
            }
        }
        return $false
    }
    [bool] isOverlaping([IPRange] $range)
    {
        foreach($r in $this.Ranges)
        {
            switch($err=$range.Compare($r))
            {
                "PERFECT_MATCH" {return $true}
                "INCLUDED" {return $true}
                "COVERED" {return $true}
                "NONE" {return $false}
                "OVERLAP" {return $true}
                "EXTENDING" {return $false}
                default {throw("error : $err")}
            }
        }
        return $false
    }

}

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

function Add-ComputerFromCollectionToADGroup
{
    Param(
        [Parameter(Mandatory=$true)] $ADGroup,
        [Parameter(Mandatory=$true)] $CollectionName
    )    
    foreach($d in Get-CMDevice -CollectionName $CollectionName)
    {
        # TBD : add some collection existence control
        $sAMAccountName="$($d.Name)$"

        # multidomain specifics
        $server="$($d.domain).DIR.GRPLEG.COM"

        if($null -eq ($ADComputer=Get-ADComputer -filter "sAMAccountName -eq '$sAMAccountName'" -Server $server))
        {
            "$sAMAccountName not found in AD"
            continue
        }
        # TBD : add some already present in group check
        if(Add-ADGroupMember -Identity $ADGroup -Members $ADComputer)
        {
            "Successfully added ($ADComputer) to $ADGroup"
        }
    }
}

function find-alloverlaping
{
    [cmdletbinding()]

    $CMBoundaries=(Get-CMBoundary | Where-Object {$_.boundarytype -eq 3})

    foreach($CMboundary in $CMBoundaries)
    {
        if($text=find-overlaping -IPBoundary $CMBoundary.value -ignorePerfectMatch)
        {
            "$($CMboundary.DisplayName) ( $($CMboundary.Value) ) $($text.match) $($text.BoundaryName) ($($text.IPRange))"
        }        
    }
}

function find-overlaping
{
    [cmdletbinding()]

    param (
        [Parameter(Mandatory=$true)][IPRange] $IPBoundary,
        [Parameter(Mandatory=$false)][switch] $ignorePerfectMatch=$false,
        [Parameter(Mandatory=$false)][switch] $NoExtending=$false
    )
    $CMBoundaries=(Get-CMBoundary | where-object {$_.boundarytype -eq 3})

    $Found = [System.Collections.ArrayList]::new()

    foreach($existingIPBoundary in $CMBoundaries)
    {
        if(-not($existingIPBoundary.value -match '(.*)-(.*)'))
        {
            continue
        }

        if(($result=$IPBoundary.Compare([IPRange] ($existingIPBoundary.value))) -ne "NONE")
        {
            if((-not($ignorePErfectMatch) -or $result -ne "PERFECT_MATCH"))
            {
                if(-not($noExtending) -or $result -ne "EXTENDING")
                {
                    $null=$Found.Add(@{"match" = $result; "BoundaryName" = $existingIPBoundary.DisplayName; "IPRange" = ($existingIPBoundary.value)})
                }
            }
        }
    }
    switch($Found.count)
    {
        0 { return $false }
        default { return $Found }
    }
}

function connect-SCCM
{
    [cmdletbinding()]

    param(
        [Parameter(Mandatory=$true)][string] $PrimarySiteCode,
        [Parameter(Mandatory=$true)][string] $ProviderMachineName
    )
    #
    # Press 'F5' to run this script. Running this script will load the ConfigurationManager
    # module for Windows PowerShell and will connect to the site.
    #
    # This script was auto-generated at '12/15/2021 10:22:06 AM'.

    # Site configuration

    # Customizations
    $initParams = @{}
    #$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
    #$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

    # Do not change anything below this line

    # Import the ConfigurationManager.psd1 module 
    if($null -eq (Get-Module ConfigurationManager)) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
    }

    # Connect to the site's drive if it is not already present
    if($null -eq (Get-PSDrive -Name $PrimarySiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $PrimarySiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    }

    # Set the current location to be the site code.
    Set-Location "$($PrimarySiteCode):\" @initParams
}

function monitor
{
    [cmdletbinding()]

    param(
        [string][Parameter(Mandatory=$true)] $computer
    )

    if(Test-Connection -ComputerName $computer -Count 1 -Quiet -Delay 1)
    {
        $on=$false
    } else {
        $on=$true
    }

    while($true)
    {
        if(Test-Connection -ComputerName $computer -Count 1 -Quiet -Delay 1)
        {
            if($on -eq $false)
            {
                write-host "($computer) $(get-date) : ON"
                $on=$true
            }
        } else {
            if($on -eq $true)
            {
                write-host "($computer) $(get-date) : OFF"
                $on=$false
            }
        }
    }
}

function Log
{
    Param(
        [Parameter(Mandatory=$true)][string] $message,
        [Parameter(Mandatory=$false)][string] $LogFile,
        [Parameter(Mandatory=$false)][string] $Level="INFO"
    )
    switch($Global:DebugLevel)
    {
        4 {$filter="(ERROR|WARNING|INFO|DEBUG)"}
        3 {$filter="(ERROR|WARNING|INFO)"}
        2 {$filter="(ERROR|WARNING)"}
        1 {$filter="(ERROR|)"}
        0 {$filter="(ERROR|WARNING|INFO)"}
        default {$filter=""}
    }
    if($Level -match $filter)
    {
        if($LogFile)
        {
            "($Level) $message" | Out-File -Append -FilePath $LogFile
        }
        else
        {
            write-host "($Level) $message)"
        }
    }
}

function backup-boundaries
{
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$false)][string] $filePath="$env:USERPROFILE\Documents\backup_boundaries.csv"
    )
    Get-CMBoundary | Select-Object -Property DisplayName,Value,BoundaryType | Export-CSV -Path $filepath -NoTypeInformation
}

function restore-boundaries
{
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$false)][string] $filePath="$env:USERPROFILE\Documents\backup_boundaries.csv"
    )
    # not tested, need to add some cleaning option ?
    # Import-CSV -Path $filePath | ForEach-Object { New-CMBoundary -Name $_.DisplayName -Type $_.BoundaryType -Value $_.Value }
}

function import-csv2boundaries
{
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$false)][string] $filePath="$env:USERPROFILE\Documents\export_subnets.csv",
        [parameter(Mandatory=$false)][string] $filter="",
        [parameter(Mandatory=$false)][string] $LogFile 
    )
#    Write-Progress -Activity "importing $filepath"
    $ADSubnets=Import-Csv -Path $filepath -Delimiter "`t" | Where-Object {$_.Site -match "$filter"}
    Log -message "-------------------------------------------`n" -LogFile $LogFile
    Log -message "Starting new import. ($(get-date)) filter : $filter, lines : $($ADSubnets.count)" -Level "INFO" -LogFile $LogFile 


    $ADSites=$ADSubnets.Site | Sort-object -unique
    
    foreach($ADSite in $ADSites)
    {
        if(-not-($ADSite -match '^CN=((..)-([^,]*)),.*$'))
        {
            Log -message "Could not work with $ADSite" -Level "ERROR" -LogFile $LogFile
            continue
        }
        Log -message "Working on $ADSite" -Level "INFO" -LogFile $LogFile
        $ADSiteName=$matches[1]
        $country=$matches[2]
        $sitename=$matches[3]
        $BoundaryName="$($country)-IPR_$($sitename)"
        Log -message "Trying to guess SiteCode for $country" -Level "DEBUG" -LogFile $LogFile
        if(-not($sitecode=Guess-MostProbableSiteCode -CountryCode $country -MinScore 90))
        {
            Log -message "Could not guess SiteCode for $country" -Level "ERROR"-LogFile $LogFile
            if($country -eq "FR")
            {
                $SiteCode="B01"
            } else {
                continue
            }
        }
        Log -message "Guessed SiteCode for $country is $sitecode" -Level "INFO"-LogFile $LogFile
        
        $IPRanges2Add=[IPRanges]::new()
        # on cr??er une collection de tous les subnets du site
        foreach($ADSubnet in $ADSubnets | where-object {$_.Site -match $ADSiteName})
        {
            Log -message "Adding $($ADSubnet.Name) for $($BoundaryName) -> $($IPRAnges2Add)" -Level "DEBUG" -LogFile $LogFile
            $IPRanges2Add.AddRange($ADSubnet.Name)
        }
        Log -message "Working on $BoundaryName" -Level "INFO" -LogFile $LogFile

        # on cherche les boundaries existantes qui correspondent au meme boundaryname et on les ajoute ?? nos range cible
        foreach($CMBoundary in (Get-CMBoundary | where-object {($_.boundarytype -eq 3) -and ($_.DisplayName -match $BoundaryName)}))
        {
            Log -message "Adding $($CMBoundary.Value) to current scope" -Level "DEBUG" -LogFile $LogFile
            $IPRanges2Add.AddRange($CMBoundary.Value)
        }

        $IPRanges2Remove=[IPRanges]::new()
        # on cherche les conflits existants avec ces subnets dans SCCM
        foreach($IPRange in ($IPRanges2Add.Ranges))
        {
            Log -message "Working on $IPRange" -Level "DEBUG" -LogFile $LogFile
            $Conflicts=find-CMIPRange -IPRange $IPRange
            foreach($Conflict in $Conflicts)
            {
                if($Conflict.BoundaryName -ne $BoundaryName)
                {
                    # Le subnet conflictuel est etranger, donc on s'adapte en reduisant notre cible
                    $IPRanges2Remove.AddRange($Conflict.IPRange)
                } 
                else
                {
                    # Le subnet conflictuel est dans notre cible donc on le supprime
                    Log -message "Removing IPRange $($Conflict.BoundaryName) : $($Conflict.IPRange)" -Level "DEBUG" -LogFile $LogFile
                    if($BoundaryToRemove=Get-CMBoundary | where-object {($_.Value -match $conflict.IPrange) -and ($_.DisplayName -match $Conflict.BoundaryName)})
                    {  
                        if($BoundaryToRemove.count -ge 5)
                        {
                            throw("we are supposed to remove more than 5 IPRange, that`'s REALLY suspicious")
                        }
                        foreach($b in $BoundaryToRemove)
                        {
                            Log -message "Removing boundary $($b.DisplayName) - $($b.Value)" -Level "INFO" -LogFile $LogFile
                            $b | Remove-CMBoundary -force
                        }
                    }
                }
            }
        }
        # on nettoie la range cible des range ?? supprimer
        Log -message "IPRange to remove from our target : $IPRanges2Remove" -Level "INFO" -LogFile $LogFile
        foreach($IPRange in ($IPRanges2Remove.Ranges))
        {
            if($null -ne $IPRange)
            {
                Log -message "Removing $IPRange from the target scope" -Level "DEBUG"-LogFile $LogFile
                $IPRanges2Add.RemoveRange($IPRange)
            }
        }
        Log -message "IPRanges to add : $IPRanges2Add" -Level "DEBUG" -LogFile $LogFile
        foreach($IPRange in ($IPRanges2Add.Ranges))
        {
            # finalement on ajoute la Range nettoy??e
            Log -message "Adding IPRange $($BoundaryName) : $($IPRange)" -Level "DEBUG"-LogFile $LogFile
            New-IPRBoundary -IPRange $IPRange -Country $Country -SiteName $sitename -SiteCode $sitecode
        }
    }
    Log -message "End of Script" -Level "INFO" -LogFile $LogFile
}

class SCCM 
{
    hidden [string] $PrimarySiteCode
    hidden [string] $ProviderMachineName
    SCCM ([string] $PrimarySiteCode, [string] $ProviderMachineName)
    {
        $this.InitConnection($PrimarySiteCode, $ProviderMachineName)
    }
    InitConnection([string] $PrimarySiteCode, [string] $ProviderMachineName)
    {
        $this.PrimarySiteCode = $PrimarySiteCode        
        $this.ProviderMachineName = $ProviderMachineName
        $initParams = @{}
        # Import the ConfigurationManager.psd1 module 
        if($null -eq (Get-Module ConfigurationManager)) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
        }

        # Connect to the site's drive if it is not already present
        if($null -eq (Get-PSDrive -Name $PrimarySiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name $PrimarySiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
        }

        # Set the current location to be the site code.
        Set-Location "$($PrimarySiteCode):\" @initParams
    }
    deployDistributionPoint([string] $DistributionPoint, [string] $DPSiteCode, [string] $CountryCode, [string] $City, [string] $PXEPass)
    {
        # TBD: ajout de la gestion des pull DP
        # TBD: Ajout de la description du DP (peut etre ajouter un tag d'identification du stage ? "distribution in progress")
        # TBD: ajout et activation du dedupe
    
        if(-not($DistributionPoint -match '^([^\.]+)\.(.+)$'))
        {
            throw("invalid format for DistributionPoint : $DistributionPoint")
        }
        $DPShortName = $matches[1]
        $Domain = $matches[2]
        $DPsAMAccountName = $DPShortName + '$'
    
        # prerequisite checks
        # TBD: check sitecode is good
    
        # check machine up
        if(-not(Test-Connection -quiet -Count 1 -ComputerName $DistributionPoint))
        {
            throw("$DistributionPoint is down")
        }

        AddLocalAdmin("EU\GUS-SCCM-Servers-Admins-$($Domain)")
        AddLocalAdmin("EU\INFFRPA3017$")
        AddLocalAdmin(((Get-CMSite -SiteCode $($this.DPSiteCode)).ServerName.Split("."))[0])

        # Client Specific
        # adding the computer object to the proper AD group
        $group=""
        switch($Domain)
        {
            "AM.DIR.GRPLEG.COM" {$group="ADM-US-WES-SCCM-AllServers"}
            "AS.DIR.GRPLEG.COM" {$group="ADM-AS-FRLGS-SCCM-AllServers"}
            "EU.DIR.GRPLEG.COM" {$group="ADM-FRLGS-SCCM-AllServers"}
            default {throw("cannot identify domain $Domain")}
        }
    
        if(-not((Get-ADGroupMember -Server $Domain -Identity $group).Name.contains($DPShortName)))
        {
            "adding $DPShortName to $group on $Domain"
            Add-ADGroupMember -server $Domain -Identity $group -Members $DPsAMAccountName
        }
    
        #Install Site System Server
        if(-not($CMSiteSystemServer=Get-CMSiteSystemServer -AllSite | Where-Object {$_.NALPath -match "$DPShortName"}))
        {
            "Creating $DistributionPoint on $($this.PrimarySiteCode)"
            $CMSiteSystemServer=New-CMSiteSystemServer -ServerName $DistributionPoint -SiteCode $($this.PrimarySiteCode)
        } else {
            write-warning "$DistributionPoint is already a site system"
        }
    
        #Optional - Install SCCM IIS Base components
        Invoke-Command -ComputerName $DistributionPoint -ScriptBlock {dism.exe /online /norestart /enable-feature /ignorecheck /featurename:"IIS-WebServerRole" /featurename:"IIS-WebServer" /featurename:"IIS-CommonHttpFeatures" /featurename:"IIS-StaticContent" /featurename:"IIS-DefaultDocument" /featurename:"IIS-DirectoryBrowsing" /featurename:"IIS-HttpErrors" /featurename:"IIS-HttpRedirect" /featurename:"IIS-WebServerManagementTools" /featurename:"IIS-IIS6ManagementCompatibility"  /featurename:"IIS-Metabase" /featurename:"IIS-WindowsAuthentication"  /featurename:"IIS-WMICompatibility"  /featurename:"IIS-ISAPIExtensions" /featurename:"IIS-ManagementScriptingTools" /featurename:"MSRDC-Infrastructure" /featurename:"IIS-ManagementService"}
    
        #Install Distribution Point Role
        write-host "The Distribution Point Role is being Installed on $DistributionPoint"
        if(-not($CMDistributionPoint=Get-CMDistributionPoint -SiteSystemServerName $DistributionPoint -SiteCode $($this.PrimarySiteCode)))
        {
            "creating DP on $DistributionPoint"
            $CMDistributionPoint=Add-CMDistributionPoint -CertificateExpirationTimeUtc ((get-date).addyears(5)) -SiteCode $($this.PrimarySiteCode) -SiteSystemServerName $DistributionPoint -MinimumFreeSpaceMB 1024 -ClientConnectionType 'Intranet' -PrimaryContentLibraryLocation Automatic -PrimaryPackageShareLocation Automatic -SecondaryContentLibraryLocation Automatic -SecondaryPackageShareLocation Automatic
        } else {
            "DP already created on $DistributionPoint"
        }
    
    
        #Define PXE Password
        $PXEpass = convertto-securestring -string "password" -asplaintext -force
    
        #Enable PXE, Unknown Computer Support, Client Communication Method
        Set-CMDistributionPoint -SiteSystemServerName $DistributionPoint -SiteCode $($this.PrimarySiteCode) -EnablePxe $True -PXEpassword $PXEpass -PxeServerResponseDelaySeconds 0 -AllowPxeResponse $True -EnableUnknownComputerSupport $True -UserDeviceAffinity "AllowWithAutomaticApproval" -EnableContentValidation $True -ClientCommunicationType Http -EnableAnonymous $true -EnableBranchCache $true -EnableDoinc $true -DiskSpaceDoinc 50 -AgreeDoincLicense $true
    
    
        #Enable Multicast Feature
        # Add-CMMulticastServicePoint -SiteSystemServerName $DistributionPoint -SiteCode $($this.PrimarySiteCode)
    
    
    
        # post install task
        # add DP to groups (all et OSD)
        Start-Sleep -Seconds 60
        "adding $DistributionPoint to content groups"
        Add-CMDistributionPointToGroup -DistributionPointName $DistributionPoint -DistributionPointGroupName "All On-Premises Distribution Points"
        Add-CMDistributionPointToGroup -DistributionPointName $DistributionPoint -DistributionPointGroupName "OSD_Win10_PROD_Distribution_Point_Group"
    
    
        # add or create boundary group
        $BGName="BG-Content-$CountryCode-$city"
        if(-not($CMBoundaryGroup=Get-CMBoundaryGroup -Name $BGName))
        {
            "Creating boundary group $BGName"
            $CMBoundaryGroup=New-CMBoundaryGroup -AddSiteSystemServer $CMSiteSystemServer -Name $BGName
        } else {
            "$BGName already exists"
        }
        
        # check or create boundary / IPRange
    
        $IP=[IP] (Invoke-Command -ComputerName $DistributionPoint -ScriptBlock { (Get-NetIPAddress).where({$_.IPAddress -match "10\.\d+\.\d+\.\d+"}).IPAddress })
        $IP.prefix=(Invoke-Command -ComputerName $DistributionPoint -ScriptBlock { (Get-NetIPAddress).where({$_.IPAddress -match "10\.\d+\.\d+\.\d+"}).PrefixLength })
    
    
        $IPRange="$($IP.startIP)-$($IP.EndIP)"
    
        $IPRName="$CountryCode-IPR_$City"
        if(-not($CMBoundary=Get-CMBoundary -BoundaryName $IPRName))
        {
            "creating boundary $IPRName with range $IPRange for $DPShortName / $($this.PrimarySiteCode)"
            $CMBoundary=New-CMBoundary -Name $IPRName -Type IPRange -Value $IPRange
        } else {
            "boundary $IPRName already exist with IPRange : $($CMBoundary.Value)"
        }
    
        # we add the proper BG to that boundary
        Add-CMBoundaryToGroup -InputObject $CMBoundary -BoundaryGroupInputObject $CMBoundaryGroup
        Add-CMBoundaryToGroup -InputObject $CMBoundary -BoundaryGroupName "BG-SUP-Default"
        Add-CMBoundaryToGroup -InputObject $CMBoundary -BoundaryGroupName "BG-Site-$($this.PrimarySiteCode)"
    }
    AddLocalAdmin([string] $Computer, [string] $item)
    {
        # on test que l'item est non vide
        if($item.Length -le 0)
        {
            throw ("$item is invalid")
        }
        
        # on ajoute l'item a la liste des admins locaux
        if(-not(Invoke-Command -ComputerName $Computer -ScriptBlock{Get-LocalGroupMember -SID S-1-5-32-544 -Member $args[0] -ErrorAction SilentlyContinue} -ArgumentList $item))
        {
            "Adding $item to local admin on $Computer"
            Invoke-Command -ComputerName $Computer -ScriptBlock {add-LocalGroupMember -SID S-1-5-32-544 -Member $args[0]} -ArgumentList $item 
        }
    }
<#    
    checkDistribution()
    {
        [cmdletbinding()]
    
        Param(
            [string][Parameter(Mandatory=$true)] $DP,
            [string][Parameter(Mandatory=$false)] $PrimarySiteCode,
            [string][Parameter(Mandatory=$false)] $ProviderMachineName
        )
        $PackagesStatus = (Get-WmiObject -Namespace "Root\SMS\Site_$PrimarySiteCode" -Query "select * from SMS_PackageStatusDistPointsSummarizer where ServerNALPath like '%$DP%'" -ComputerName $ProviderMachineName | Group-Object -Property state)
        "in progress : $((($PackagesStatus.where{$_.Name -eq 7})[0]).count)"
        "retrying    : $((($PackagesStatus.where{$_.Name -eq 2})[0]).count)"
        "failed      : $((($PackagesStatus.where{$_.Name -eq 3})[0]).count)"
        "success     : $((($PackagesStatus.where{$_.Name -eq 0})[0]).count)"
    }
    RetryFailedPackages()
    {
        [cmdletbinding()]
    
        Param(
            [string][Parameter(Mandatory=$true)] $DP,
            [string][Parameter(Mandatory=$false)] $PrimarySiteCode,
            [string][Parameter(Mandatory=$false)] $ProviderMachineName
        )
        $PSDrive=Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue
        if(-not($PrimarySiteCode) -and -not($ProviderMachineName) -and -not($PSDrive))
        {
            throw("no PSDrive detected or set")
        } 
        elseif(-not($PrimarySiteCode) -or -not($ProviderMachineName))
        {
            $PrimarySiteCode=$PSDrive.Name
            $ProviderMachineName=$PSRdrive.root
        } 
        else 
        {
            connect-SCCM -ProviderMachineName $ProviderMachineName -PrimarySiteCode $PrimarySiteCode
        }
    
        $FailedPackages = Get-WmiObject -Namespace "Root\SMS\Site_$PrimarySiteCode" -Query "select * from SMS_PackageStatusDistPointsSummarizer where state = 3" -ComputerName $ProviderMachineName
    
        if ($FailedPackages)
        {
            foreach ($FailedPackage in $FailedPackages | where-object {$_.ServerNALPath -match "$DP"})
            {
                try
                {
                    $DistributionPointObj = Get-WmiObject -Namespace "root\SMS\Site_$($($this.PrimarySiteCode))" -Class SMS_DistributionPoint -Filter "PackageID='$($FailedPackage.PackageID)' and ServerNALPath like '%$($FailedPackage.ServerNALPath.Substring(12,7))%'" -ComputerName INFFRPA3017
                    $DistributionPointObj.RefreshNow = $True
                    $null = $DistributionPointObj.Put()
                    Write-Host "Refreshed $($FailedPackage.PackageID) on $($FailedPackage.ServerNALPath) - State was: $($FailedPackage.State)"
                }
                catch
                {
                    Write-Host "Unable to refresh package $($FailedPackage.PackageID) on $($FailedPackage.ServerNALPath.Substring(12,7)) - State was: $($FailedPackage.State)"
                    write-host $Error
                }
            }
        }
    }
    
    GuessMostProbableSiteCode()
    {
        [cmdletbinding()]
    
        param (
            [string][Parameter(Mandatory=$true)] $CountryCode,
            [uint16] $MinScore=0,
            [uint16] $MinMatches=0
        )
        
        $filter="^(DIR.GRPLEG.COM/)?$($CountryCode)-"
        $MaxHits=0
        $BGWithMaxHit=""
        foreach($BG in (Get-CMBoundaryGroup | Where-Object {$_.Name -match "BG-Site"}))
        {
            $CountHits=(Get-CMBoundary -BoundaryGroupName $BG.Name | Where-Object {$_.DisplayName -match "$filter"}).count
            if($CountHits -gt $MaxHits)
            {
                $PreviousMaxHit=$MaxHits
                $MaxHits=$CountHits
                $BGWithMaxHit=$BG.Name
            }  
        }
        $score=[math]::round(100*$MaxHits/($MaxHits + $PreviousMaxHit),0)
        if(($MaxHits -ge $MinMatches) -and ($score -ge $MinScore))
        {
            return "$BGWithMaxHit"
        } else {
            return ""
        }
    }
    
    NewIPRBoundary()
    {
        [cmdletbinding()]
    
        param(
            [string][Parameter(Mandatory=$true)] $IPRange,
            [string][Parameter(Mandatory=$false)] $SiteCode,
            [string][Parameter(Mandatory=$true)] $Country,
            [string][Parameter(Mandatory=$true)] $SiteName,
            [string][Parameter(Mandatory=$false)] $LogFile="$env:userprofile\documents\boundaries.log"
        )
    
        if(-not($SiteCode))
        {
            $BGSite=Guess-MostProbableSiteCode -CountryCode $Country -MinScore 90
        } else {
            $BGSite="$SiteCode"
        }
        if(-not($BGSite))
        {
            write-host "No SiteCode Provided/Detected"
            break
        }
        $BoundaryName="$country-IPR_$($SiteName)"
        $BGName="BG-Content-$Country-$SiteName"
        if(-not($CMBoundary=Get-CMBoundary | Where-Object {((($_.BoundaryType -eq 3) -and ($_.Value -eq $IPRange)) -and ($_.DisplayName -eq $BoundaryName))}))
        {
            Log -message "creating Boundary $IPRange in $BoundaryName" -Level "INFO" -LogFile $LogFile
            $CMBoundary=New-CMBoundary -Type IPRange -Value $IPRange -Name $BoundaryName
        }    
        if(-not(Get-CMBoundaryGroup -Name $BGName))
        {
            Log -message "creating Boundary group $BGName" -Level "INFO" -LogFile $LogFile
            $null=New-CMBoundaryGroup -Name "$BGName"
        }
    
        Log -message "adding $($CMBoundary.DisplayName) $($CMBoundary.Value) to $BGName, $BGSite and BG-SUP-default" -Level "INFO" -LogFile $LogFile
        Add-CMBoundaryToGroup -BoundaryId ($CMBoundary.BoundaryID) -BoundaryGroupName "$BGName"
        Add-CMBoundaryToGroup -BoundaryId ($CMBoundary.BoundaryID) -BoundaryGroupName "$BGSite"
        Add-CMBoundaryToGroup -BoundaryId ($CMBoundary.BoundaryID) -BoundaryGroupName "BG-SUP-Default"
    }
    findCMIPRange()
    {
        [cmdletbinding()]
    
        param (
            [Parameter(Mandatory=$true)][IPRange] $IPRange
        )
        $CMBoundaries=(Get-CMBoundary | where-object {$_.boundarytype -eq 3})
    
        $Found = [System.Collections.ArrayList]::new()
    
        foreach($CMBoundary in $CMBoundaries)
        {
            switch -regex ($IPRange.Compare([IPRange] ($CMBoundary.value)))
            {
                "(NONE|EXTENDING)" {}
                default {$null=$Found.Add(@{"BoundaryName"=$CMBoundary.DisplayName;"IPRange"=$CMBoundary.Value})}
            }
        }
        return $Found
    }
#>    
}