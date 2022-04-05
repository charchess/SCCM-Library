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

