Describe 'Check class SCCM is working as expected' {
    BeforeAll {
        Import-Module -Force $PSScriptRoot\..\..\SCCM_Library.ps1
    }
    BeforeEach {
    }
    It 'SCCM instance creation - Site/Server' {
        Mock Set-Location { return $true }
        Mock New-PSDrive {return $true}
        ([SCCM]::new("X01", "server.fqdn")) | Should -Be "SCCM"
    }
}