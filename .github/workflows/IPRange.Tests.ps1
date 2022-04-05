Describe 'Check class IPRange is working as expected' {
    # TBD: no check for size
    # TBD : add overlapin method test
    BeforeAll {
            Import-Module -Force $PSScriptRoot\..\..\SCCM_Library.ps1
        }
    BeforeEach {
        $IP1=[IP] "11.0.0.1/8"
        $IP2=[IP] "10.0.0.1/255.255.255.0"
        $IP3=[IP] "192.168.0.0"
        $IPRA=[IPRange] "127.0.0.1/8"
        $IPRB=[IPRange] "$IP2-$IP1"                 
        $IPR0=[IPRange] "10.0.0.0-11.255.255.255"   # 10.0.0.0-11../|===============|
        $IPR1=[IPRange] "1.1.1.1/30"                #    |====|
        $IPR2=[IPRange] "9.0.0.0/8"                 #        |===]
        $IPR3=[IPRange] "9.0.0.0-10.126.144.123"    #       |==========|
        $IPR4=[IPRange] "11.128.0.0-11.200.0.0"     #                  |======|
        $IPR5=[IPRange] "10.255.255.255-13.5.5.5"   #                       |===========|
        $IPR6=[IPRange] "12.0.0.0/8"                #                             [======|   
        $IPR7=[IPRange] "192.168.0.0/24"            #                                          |=====|
        $IPR8=[IPRange] "0.0.0.0-255.255.255.255"   #         |==========================|
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
