function check-alloverlaping
{
    [cmdletbinding()]

    $CMBoundaries=(Get-CMBoundary | where {$_.boundarytype -eq 3})

    foreach($CMboundary in $CMBoundaries)
    {
        if($text=check-overlaping -IPBoundary $CMBoundary.value -ignorePerfectMatch)
        {
            "$($CMboundary.Value) : $($CMboundary.DisplayName) -> $($text.match) $($text.BoundaryName)"
        }        
    }
}

function check-overlaping
{
    [cmdletbinding()]

    param (
        [Parameter(Mandatory=$true)][IPRange] $IPBoundary,
        [Parameter(Mandatory=$false)][switch] $ignorePerfectMatch=$false
    )
    $CMBoundaries=(Get-CMBoundary | where {$_.boundarytype -eq 3})

    $Found = [System.Collections.ArrayList]::new()

    foreach($existingIPBoundary in $CMBoundaries)
    {
        if(-not($existingIPBoundary.value -match '(.*)-(.*)'))
        {
            continue
        }

        if(($result=$IPBoundary.CompareTo([IPRange] ($existingIPBoundary.value))) -ne "NONE")
        {
            if(-not($ignorePErfectMatch) -or $result -ne "PERFECT_MATCH")
            {
                $null=$Found.Add(@{"match" = $result; "BoundaryName" = $existingIPBoundary.DisplayName; "IPRange" = ($existingIPBoundary.value)})
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
    if((Get-Module ConfigurationManager) -eq $null) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
    }

    # Connect to the site's drive if it is not already present
    if((Get-PSDrive -Name $PrimarySiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $PrimarySiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
    }

    # Set the current location to be the site code.
    Set-Location "$($PrimarySiteCode):\" @initParams
}

function Retry-FailedPackages
{
    [cmdletbinding()]

    Param(
        [string][Parameter(Mandatory=$true)] $DP
    )
    $FailedPackages = Get-WmiObject -Namespace "Root\SMS\Site_$PrimarySiteCode" -Query "select * from SMS_PackageStatusDistPointsSummarizer where state = 3" -ComputerName $ProviderMachineName

    if ($FailedPackages)
    {
        foreach ($FailedPackage in $FailedPackages | where {$_.ServerNALPath -match "$DP"})
        {
            try
            {
                $DistributionPointObj = Get-WmiObject -Namespace "root\SMS\Site_$($SiteCode)" -Class SMS_DistributionPoint -Filter "PackageID='$($FailedPackage.PackageID)' and ServerNALPath like '%$($FailedPackage.ServerNALPath.Substring(12,7))%'" -ComputerName INFFRPA3017
                $DistributionPointObj.RefreshNow = $True
                $result = $DistributionPointObj.Put()
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

function identify-MostProbableSiteCode
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

function New-IPRBoundary
{
    [cmdletbinding()]

    param(
        [string][Parameter(Mandatory=$true)] $IPRange,
        [string][Parameter(Mandatory=$false)] $SiteCode,
        [string][Parameter(Mandatory=$true)] $Country,
        [string][Parameter(Mandatory=$true)] $SiteName
    )

    if(-not($SiteCode))
    {
        $BGSite=identify-MostProbableSiteCode -CountryCode $Country -MinScore 90
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
    if(-not($CMBoundary=Get-CMBoundary | Where-Object {((($_.BoundaryType -eq 3) -and ($_.Value -eq $IPRange)) -and $_.DisplayName -eq $BoundaryName)}))
    {
        $CMBoundary=New-CMBoundary -Type IPRange -Value $IPRange -Name $BoundaryName
    }    
    if(-not($CMBoundaryGroup=Get-CMBoundaryGroup -Name $BGName))
    {
        "creating Boundary group $BGName"
        $CMBoundaryGroup=New-CMBoundaryGroup -Name "$BGName"
    }

    Add-CMBoundaryToGroup -BoundaryId ($cmboundary.BoundaryID) -BoundaryGroupName "$BGName"
    Add-CMBoundaryToGroup -BoundaryId ($cmboundary.BoundaryID) -BoundaryGroupName "$BGSite"
    Add-CMBoundaryToGroup -BoundaryId ($cmboundary.BoundaryID) -BoundaryGroupName "BG-SUP-Default"
}

class IPAddress : System.IComparable
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
    IPAddress()
    {
        $this.Constructor_common()
    }
    IPAddress([string] $Address)
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
            $IPAddress=[IPAddress] $IPAddress
        }
        if($IPAddress -is [IPAddress])
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
}

Class IPrange : System.IComparable
{
    [IPAddress] $IPStart
    [IPAddress] $IPEnd
    [int] $size=0

    IPRange ([IPAddress] $StartIP, [IPAddress] $EndIP)
    {
        $this.IPStart=[IPAddress] $StartIP
        $this.IPEnd=[IPAddress] $EndIP
        $this.size=$this.IPEndID - $this.IPStartID
    }
    IPRange ([string] $IPrange)
    {
        $IPrange=$IPrange.Replace(' ','')
        if($IPrange -match '^(\d*\.\d*\.\d*\.\d*)-(\d*\.\d*\.\d*\.\d*)$')
        {
            $this.IPStart=[IPAddress] $matches[1]
            $this.IPEnd=[IPAddress] $matches[2]
        } elseif($IPrange -match '^(\d*\.\d*\.\d*\.\d*)/(\d*)$')
        {
            $IP=[IPAddress] $IPrange
            $this.IPStart=$IP.startIP
            $this.IPEnd=$IP.EndIP
        } elseif($IPrange -match '^(\d*\.\d*\.\d*\.\d*)/(\d*\.\d*\.\d*\.\d*)$')
        {
            $IP=[IPAddress] $IPrange
            $this.IPStart=$IP.startIP
            $this.IPEnd=$IP.EndIP
        }
        $this.size=$this.IPEndID.IPID - $this.IPStartID.IPID
    }
    [IPRAnge] Merge([IPRange] $extension)
    { 
        if(($extension.IPStart.IPID -le ($this.IPEnd.IPID + 1)) -and ($extension.IPEnd.IPID -gt $this.IPEnd.IPID))
        {
            $this.IPEnd = $extension.IPEnd
        }
        if(($extension.IPEnd.IPID -ge ($this.IPStart.IPID - 1)) -and ($extension.IPStart.IPID -lt $this.IPStart.IPID))
        {
            $this.IPStart = $extension.IPStart
        }
        return $this
    }
    [int] CompareTo($val)
    {
        return 0
    }
    [string] CompareTo([IPRange] $testedIPRange)
    {
        $found="NONE"
        if(($testedIPRange.IPStart.IPID -eq $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -eq $this.IPEnd.IPID))
        {
            $found= "PERFECT_MATCH"
        }
        elseif(($testedIPRange.IPStart.IPID -le $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -ge $this.IPEnd.IPID))
        {
            # means the IPRange tested is bigger and enveloping the actual IPRange
            $found= "INCLUDING"
        }
        elseif(($testedIPRange.IPStart.IPID -ge $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -le $this.IPEnd.IPID))
        {
            $found= "INCLUDED"
        }
        elseif((($testedIPRange.IPStart.IPID -ge $this.IPStart.IPID) -and ($testedIPRange.IPStart.IPID -le $this.IPEnd.IPID)) -or (($testedIPRange.IPEnd.IPID -ge $this.IPStart.IPID) -and ($testedIPRange.IPEnd.IPID -le $this.IPEnd.IPID)))
        {
            $found= "OVERLAP"
        } 
        elseif(($testedIPRange.IPStart.IPID -eq ($this.IPEnd.IPID + 1)) -or ($testedIPRange.IPEnd.IPID -eq ($this.IPStart.IPID - 1)))
        {
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
    static [IPRange] op_Substraction([IPRange] $a, [IPRange] $b) 
    { 
        $return=[IPRange] "$($b)" 
        $isExtended=$false
        if(($a.IPStart.IPID -le ($b.IPEnd.IPID + 1)) -and ($a.IPEnd.IPID -gt $b.IPEnd.IPID))
        {
            $b.IPEnd = $a.IPEnd
            $isExtended=$true
        }
        if(($a.IPEnd.IPID -ge ($b.IPStart.IPID - 1)) -and ($a.IPStart.IPID -lt $b.IPStart.IPID))
        {
            $b.IPStart = $a.IPStart
            $isExtended=$true
        }
        if($isExtended)
        {
            return $b
        } else {
            throw("$a and $b have no common subnet to build merge")
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

function replace-IPRangeBoundary
{
    Param(
        [Parameter(Mandatory=$true)][string] $IPRangeSource,
        [Parameter(Mandatory=$true)][string] $IPRangeTarget,
        [Parameter(Mandatory=$true)][string] $BoundaryName,
        [Parameter(Mandatory=$false)][switch] $force
    )
    # nom de la boundary, pas d'autre boundary exotique écrasée
    $overlaps=check-overlaping -IPBoundary ($IPRangeTarget)
    $exoticBoundaryName=0
    foreach($o in $overlaps)
    {
        if($o.BoundaryName -notmatch $BoundaryName)
        {
            $exoticBoundaryName++
        }
    }
    # TBD: etre plus explicite sur les actions (couvertures de range deja existentes....)
    if(($exoticBoundaryName -eq 0) -or $force)
    {
        write-host "trying to replace $IPRangeSource with $IPRangeTarget for $BoundaryName"
        $CMBoundary=Get-CMBoundary | where-object {($_.Value -match $IPRangeSource) -and ($_.DisplayName -match $BoundaryName)}
        $CMBoundary | Set-CMBoundary -NewValue $IPRangeTarget
    }
    else
    {
        # throw("some boundaries ($exoticBoundaryName) not matching $BoundaryName are present in the range $IPRangeTarget")
        write-host "some boundaries ($exoticBoundaryName) not matching $BoundaryName are present in the range $IPRangeTarget"
    }
}


function import-csv2boundaries
{
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$false)][string] $filePath="$env:USERPROFILE\Documents\export_subnets.csv",
        [parameter(Mandatory=$false)][string] $filter
    )
    Write-Progress -Activity "importing $filepath"
    $ADSubnets=Import-Csv -Path $filepath -Delimiter "`t" | Where-Object {$_.Site -match "$filter"}
    $count=0

    write-host "`n`n`n`n`n`n"


    foreach($ADSubnet in ($ADSubnets))
    {
        # TBD: ajouter des infos d'action (creation/replace) dans la barre de progression
        write-progress -Activity "Importing subnet : $IPRange ($((100*[math]::round($count/($ADSubnets.count), 2)))%)" -PercentComplete (100*[math]::round($count/$ADSubnets.count, 4)) -Status "checking"
        $count++

        $IPRange=[IPRange] ($ADSubnet.Name)
        $country=($ADSubnet.Site).Substring(0, ($ADSubnet.Site.IndexOf(","))).remove(0,3).Substring(0,2)
        $Name=($ADSubnet.Site).Substring(0, ($ADSubnet.Site.IndexOf(","))).remove(0,6)
        $BoundaryName="$($country)-IPR_$($Name)"

        # check existence in SCCM
        $overlap=check-overlaping -IPBoundary ($IPRange.ToString())
        if(-not($overlap))
        {
            write-verbose "NONE: creating range $IPRange on $BoundaryName" 
            New-IPRBoundary -IPRange $IPRange -Country $country -SiteName $Name
        } else {
            foreach($o in $overlap)
            {
                write-verbose "$($o.match) $IPRange $($o.IPRange) $($o.BoundaryName)"
                switch($o.match)
                {
                # on est a priori bon, reste a check les boundary quand on veut remplacer/etendre
                    "INCLUDING" 
                    {
                        # la range proposée est incluse dans une range existente, rien à faire
                        # Amelioration : vérifier que la range est cohérente
                        write-verbose " $IPRange is included in $($o.IPRange) - $($o.BoundaryName)" 
                        if($o.BoundaryName -ne $BoundaryName)
                        {
                            "Boundary $($o.IPRange) already exist inside a different Boundary : $($o.BoundaryName)"
                        }

                    }
                    "INCLUDED" 
                    {
                        # La range proposée inclus une range existante dans SCCM
                        # vérifier que la range existante est cohérente (nom de la range)
                        # vérifier que le supernet ne couvre pas d'autres range incompatible
                        # galère
                        replace-IPRangeBoundary -IPRangeSource $o.IPRange -IPRangeTarget ($IPRange.Merge($o.IPRange)) -BoundaryName "$BoundaryName"
                    }
                    "OVERLAP" 
                    { 
                        # vérifier la cohérence de l'overlap avant de l'etendre 
                        # nom de la boundary, pas d'autre boundary exotique incluse
                        replace-IPRangeBoundary -IPRangeSource $o.IPRange -IPRangeTarget ($IPRange.Merge($o.IPRange)) -BoundaryName "$BoundaryName"
                    }
                    "EXTENDING" 
                    {
                        # vérifier la cohérence de l'overlap avant de l'etendre 
                        # nom de la boundary, pas d'autre boundary exotique écrasée
                        replace-IPRangeBoundary -IPRangeSource $o.IPRange -IPRangeTarget ($IPRange.Merge($o.IPRange)) -BoundaryName "$BoundaryName"
                    }
                    "PERFECT_MATCH" 
                    { 
                        # une range identique existe, vérifier la cohérence du nom
                        write-verbose "PERFECT_MATCH, do nothing ($IPRange)" 
                        if($o.BoundaryName -ne $BoundaryName)
                        {
                            "Boundary $($o.IPRange) already exist with a different Name : $($o.BoundaryName)"
                        }
                    }
                    default 
                    {
                        "erreur : $($o.match)"
                    }
                }
            }
        }
    }
}

