Describe 'Check IP class is working as expected' {
    BeforeAll {
        import-module -Name $env:USERPROFILE\repos\SCCM-Library\SCCM_Library.ps1 -Force
        $IP1=[IP] "127.0.0.1/8"
        $IP2=[IP] "10.0.0.1/255.255.255.0"
        $IP3=[IP] "192.168.0.0"
    }
    It 'Check Prefix to mask is working' {
        $IP1.Mask | Should -Be "255.0.0.0"
    }
    It 'Check Mask to Prefix is working' {
        $IP2.Prefix | Should -Be 24
    }
    IT 'Check the IPID is working' {
        $IP3.IPID | Should -Be 3232235520
    }
 }

 Describe 'Check IPRange class is working as expected' {
    BeforeAll {
        import-module -Name $env:USERPROFILE\repos\SCCM-Library\SCCM_Library.ps1 -Force
        $IP1=[IP] "127.0.0.1/8"
        $IP2=[IP] "10.0.0.1/255.255.255.0"
        $IP3=[IP] "192.168.0.0"
        $IPR1=[IPRange] "127.0.0.1/8"
        $IPR2=[IPRange] "$IP2-$IP1"
    }
    It 'Check Prefix to mask is working' {
        "$IPR1" | Should -Be "127.0.0.0-127.255.255.255"
    }
    It 'Check Mask to Prefix is working' {
        "$IPR2" | Should -Be "10.0.0.1-127.0.0.1"
    }
 }