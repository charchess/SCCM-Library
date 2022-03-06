Describe 'Check class IP is working as expected' {
    BeforeAll {
        Import-Module -Force $PSScriptRoot\..\..\SCCM_Library.ps1
    }
    BeforeEach {
        $IP1=[IP] "127.0.0.1/8"
        $IP2=[IP] "10.0.0.1/255.255.255.0"
        $IP3=[IP] "192.168.0.1"
    }
    It 'IPAddress creation - definition with mask' {
        ($IP2.Address) | Should -Be "10.0.0.1"
    }
    It 'IPAddress creation - Simple definition' {
        ($IP3.Address) | Should -Be "192.168.0.1"
    }
    It 'Check Prefix to mask is working' {
        $IP1.Mask | Should -Be "255.0.0.0"
    }
    It 'Check Mask to Prefix is working' {
        $IP2.Prefix | Should -Be 24
    }
    It 'Check IPID is working' {
        $IP3.IPID | Should -Be 3232235521
    }
    It 'Check StartIP is working' {
        $IP2.startIP | Should -Be "10.0.0.0"
    }
    It 'Check EndIP is working' {
        $IP2.EndIP | Should -Be "10.0.0.255"
    }
 }

Describe 'Check class IPRange is working as expected' {
    BeforeAll {
        Import-Module -Force $PSScriptRoot\..\..\SCCM_Library.ps1
    }
    BeforeEach {
        $IP1=[IP] "11.0.0.1/8"
        $IP2=[IP] "10.0.0.1/255.255.255.0"
        $IP3=[IP] "192.168.0.0"
        $IPRA=[IPRange] "127.0.0.1/8"
        $IPRB=[IPRange] "$IP2-$IP1"  # 10.0.0.0-11../          |===============|
        $IPR0=[IPRange] "10.0.0.0-11.255.255.255"
        $IPR1=[IPRange] "1.1.1.1/30"                # |====|
        $IPR2=[IPRange] "9.0.0.0/8"                 #     |===]
        $IPR3=[IPRange] "9.0.0.0-10.126.144.123"    #    |==========|
        $IPR4=[IPRange] "11.128.0.0-11.200.0.0"     #               |======|
        $IPR5=[IPRange] "10.255.255.255-13.5.5.5"   #                    |===========|
        $IPR6=[IPRange] "12.0.0.0/8"              #                          [======|   
        $IPR7=[IPRange] "192.168.0.0/24"            #                                       |=====|
        $IPR8=[IPRange] "0.0.0.0-255.255.255.255"  #      |==========================|
    }
    It 'Check IPRange creation - with prefix' {
        "$IPRA" | Should -Be "127.0.0.0-127.255.255.255"
    }
    It 'Check IPRange creation  - with range' {
        "$IPRB" | Should -Be "10.0.0.1-11.0.0.1"
    }
    Context "Compare" {
        It "Compare - Distinct Left" {
            $IPR0.Compare($IPR1) | Should -Be "NONE"
        }
        It "Compare - Touching Left" {
            $IPR0.Compare($IPR2) | Should -Be "EXTENDING"
        }
        It "Compare - Overlap Left" {
            $IPR0.Compare($IPR3) | Should -Be "OVERLAP"
        }
        It "Compare - Inside" {
            $IPR0.Compare($IPR4) | Should -Be "COVERED"
        }
        It "Compare - Overlap Right" {
            $IPR0.Compare($IPR5) | Should -Be "OVERLAP"
        }
        It "Compare - Touching Right" {
            $IPR0.Compare($IPR6) | Should -Be "EXTENDING"
        }
        It "Compare - Distinct Right" {
            $IPR0.Compare($IPR7) | Should -Be "NONE"
        }
        It "Compare - Outside" {
            $IPR0.Compare($IPR8) | Should -Be "INCLUDED"
        }
    }
    Context "Merging" {
        It "Merging range - Self" {
            $IPR0.Merge($IPR0) | Should -Be $true
        }
        It "Merging range - Distinct Left" {
            $IPR0.Merge($IPR1) | Should -Be $false
        }
        It "Merging range - Touching Left" {
            $IPR0.Merge($IPR2) | Should -Be $true
        }
        It "Merging range - Overlap Left" {
            $IPR0.Merge($IPR3) | Should -Be $true
        }
        It "Merging range - Inside" {
            $IPR0.Merge($IPR4) | Should -Be $true
        }
        It "Merging range - Overlap Right" {
            $IPR0.Merge($IPR5) | Should -Be $true
        }
        It "Merging range - Touching Right" {
            $IPR0.Merge($IPR6) | Should -Be $true
        }
        It "Merging range - Distinct Right" {
            $IPR0.Merge($IPR7) | Should -Be $false
        }
        It "Merging range - Outside" {
            $IPR0.Merge($IPR8) | Should -Be $true
        }
    }
    Context "Addition" {
        It "Adding range - Self" {
            $IPR0 + $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "Adding range - Distinct Left" {
            {$IPR0 + $IPR1} | Should -Throw
        }
        It "Adding range - Touching Left" {
            $IPR0 + $IPR2 | Should -Be "9.0.0.0-11.255.255.255"
        }
        It "Adding range - Overlap Left" {
            $IPR0 + $IPR3 | Should -Be "9.0.0.0-11.255.255.255"
        }
        It "Adding range - Inside" {
            $IPR0 + $IPR4 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "Adding range - Overlap Right" {
            $IPR0 + $IPR5 | Should -Be "10.0.0.0-13.5.5.5"
        }
        It "Adding range - Touching Right" {
            $IPR0 + $IPR6 | Should -Be "10.0.0.0-12.255.255.255"
        }
        It "Adding range - Distinct Right" {
            {$IPR0 + $IPR7} | Should -Throw
        }
        It "Adding range - Outside" {
            $IPR0 + $IPR8 | Should -Be "0.0.0.0-255.255.255.255"
        }
    }
}

Describe 'Check class IPRanges is working as expected' {
    BeforeAll {
        Import-Module -Force $PSScriptRoot\..\..\SCCM_Library.ps1
    }
    BeforeEach {
        $IPR0=[IPRanges] "10.0.0.0-11.255.255.255"  #         |================|
        $IPR1=[IPRange] "1.1.1.1/30"                # |====|
        $IPR2=[IPRange] "9.0.0.0/8"                 #     |===]
        $IPR3=[IPRange] "9.0.0.0-10.126.144.123"    #    |==========|
        $IPR4=[IPRange] "11.128.0.0-11.200.0.0"     #               |======|
        $IPR5=[IPRange] "10.255.255.255-13.5.5.5"   #                    |===========|
        $IPR6=[IPRange] "12.0.0.0/8"                #                          [======|   
        $IPR7=[IPRange] "192.168.0.0/24"            #                                       |=====|
        $IPR8=[IPRange] "0.0.0.0-255.255.255.255"   #      |==========================|
    }
    It 'Check IPRanges type' {
        $IPR0.GetType() | Should -Be "IPRanges"
    }
    It 'Check IPRanges Value' {
        $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
    }
    Context 'Check range addition' {
        It 'adding Self' {
            $IPR0.AddRange([IPRange] "10.0.0.0-11.255.255.255")
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "Adding range - Distinct Left" {
            $IPR0.AddRange($IPR1)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255 1.1.1.0-1.1.1.3"
        }
        It "Adding range - Touching Left" {
            $IPR0.AddRange($IPR2)
            $IPR0 | Should -Be "9.0.0.0-11.255.255.255"
        }
        It "Adding range - Overlap Left" {
            $IPR0.AddRange($IPR3)
            $IPR0 | Should -Be "9.0.0.0-11.255.255.255"
        }
        It "Adding range - Inside" {
            $IPR0.AddRange($IPR4)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "Adding range - Overlap Right" {
            $IPR0.AddRange($IPR5)
            $IPR0 | Should -Be "10.0.0.0-13.5.5.5"
        }
        It "Adding range - Touching Right" {
            $IPR0.AddRange($IPR6)
            $IPR0 | Should -Be "10.0.0.0-12.255.255.255"
        }
        It "Adding range - Distinct Right" {
            $IPR0.AddRange($IPR7)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255 192.168.0.0-192.168.0.255"
        }
        It "Adding range - Outside" {
            $IPR0.AddRange($IPR8)
            $IPR0 | Should -Be "0.0.0.0-255.255.255.255"
        }
    }
    Context 'Check range removal' {
        It 'removing Self' {
            $IPR0.RemoveRange([IPRange] "10.0.0.0-11.255.255.255")
            $IPR0 | Should -Be ""
        }
        It "removing range - Distinct Left" {
            $IPR0.RemoveRange($IPR1)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "removing range - Touching Left" {
            $IPR0.RemoveRange($IPR2)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "removing range - Overlap Left" {
            $IPR0.RemoveRange($IPR3)
            $IPR0 | Should -Be "10.126.144.124-11.255.255.255"
        }
        It "removing range - Inside" {
            $IPR0.RemoveRange($IPR4)
            $IPR0 | Should -Be "10.0.0.0-11.127.255.255 11.200.0.1-11.255.255.255"
        }
        It "removing range - Overlap Right" {
            $IPR0.RemoveRange($IPR5)
            $IPR0 | Should -Be "10.0.0.0-10.255.255.254"
        }
        It "removing range - Touching Right" {
            $IPR0.RemoveRange($IPR6)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "removing range - Distinct Right" {
            $IPR0.RemoveRange($IPR7)
            $IPR0 | Should -Be "10.0.0.0-11.255.255.255"
        }
        It "removing range - Outside" {
            $IPR0.RemoveRange($IPR8)
            $IPR0 | Should -Be ""
        }
    }
}

