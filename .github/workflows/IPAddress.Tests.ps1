. $PSScriptRoot\..\SCCM_Library.ps1
. $PSScriptRoot\SCCM_Library.ps1
write-host "test $(get-currentlocation)"


BeforeAll { 
    $IP1=[IPAddress] "127.0.0.1/8"
    $IP2=[IPAddress] "10.0.0.1/255.255.255.0"
}

Describe 'Check IPAddress class is working as expected' {
    It 'Check Prefix to mask is working' {
        $IP1.Mask | Should -Be "255.0.0.0"
    }
    It 'Check Mask to Prefix is working' {
        $IP2.Prefix | Should -Be 24
    }
    It 'test path' {
        $path | should -Be 0
    }
}
