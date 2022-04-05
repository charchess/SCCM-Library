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
