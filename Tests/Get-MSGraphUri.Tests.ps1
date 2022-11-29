[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
param()

BeforeAll {
    # Import the script file
    $sPath = ($PSScriptRoot).Replace("Tests","Public") + "\Get-MSGraphUri.ps1"

    . $sPath
}

Describe "Get-MSGraphUri" {
    Context "Return valid string" {
        BeforeAll {
            $sUri = Get-MSGraphUri
        }

        It "Should return default user uri" {
            $sUri | Should -be 'https://graph.microsoft.com/v1.0/users'
        }

        AfterAll {
            Remove-Variable sUri
        }
    }

    Context "Request specific attributes" {
        BeforeAll {
            $sUri = Get-MSGraphUri -Select "Name,Id"
        }

        It "Should return uri with specific attributes" {
            $sUri | Should -be 'https://graph.microsoft.com/v1.0/users?$select=Name,Id'
        }

        AfterAll {
            Remove-Variable sUri
        }
    }

    Context "Request specific attributes" {
        BeforeAll {
            $sUri = Get-MSGraphUri -Select "Name,Id"
        }

        It "Should return uri with specific attributes" {
            $sUri | Should -be 'https://graph.microsoft.com/v1.0/users?$select=Name,Id'
        }

        AfterAll {
            Remove-Variable sUri
        }
    }

    Context "Request specific attributes" {
        BeforeAll {
            $sUri = Get-MSGraphUri -Filter "Id eq '1234'"
        }

        It "Should return uri with filter" {
            $sUri | Should -be "https://graph.microsoft.com/v1.0/users?`$filter=Id eq '1234'"
        }

        AfterAll {
            Remove-Variable sUri
        }
    }

    Context "Request all attributes" {
        BeforeAll {
            $sUri = Get-MSGraphUri -SelectAll
        }

        It "Should return uri with filter" {
            $sUri | Should -BeLike "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,accountEnabled,assignedLicenses,*"
        }

        AfterAll {
            Remove-Variable sUri
        }
    } 
}

AfterAll {
    Remove-Item function:\Get-MSGraphUri
}