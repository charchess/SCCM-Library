BeforeAll { 
    $IP1=[PAddress] "127.0.0.1/8"
}

Describe 'IPAddress' {
    It 'Check it is an IPAdress' {
        $IP1.Prefix | Should -Be 8
    }
}
