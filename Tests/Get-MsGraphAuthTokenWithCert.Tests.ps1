[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
[CmdletBinding()]
param()

BeforeAll {
    # Import the script file
    $sPath = ($PSScriptRoot).Replace("Tests","Public") + "\Get-MsGraphAuthTokenWithCert.ps1"

    . $sPath
}


Describe "Get-MsGraphAuthTokenWithCert" {
    Context "Good certificate and mock request" {
        BeforeAll {
            $sCertName = "TestCert_" + (Get-Random).toString()
            $objCert = New-SelfSignedCertificate -FriendlyName $sCertName -NotAfter ((Get-Date).adddays(730)) -Subject $sCertName -CertStoreLocation "Cert:\CurrentUser\" -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -KeyLength 2048 -KeySpec KeyExchange -KeyExportPolicy NonExportable
        
            Mock Invoke-RestMethod { return "SuccessfulTest"}
        }

        It "Should return test string" {
            Get-MsGraphAuthTokenWithCert -TenantName "NoSuchTenant" -AppId "123456789" -CertificateThumbprint $objCert.Thumbprint | Should -be "SuccessfulTest"
        }

        AfterAll {
            # Remove cert
            $sCertPath = "Cert:\CurrentUser\My\" + $objCert.Thumbprint 
            Remove-Item $sCertPath 
        }
    }

    Context "Bad certificate" {
        BeforeAll {
            Mock Invoke-RestMethod { return "SuccessfulTest" }
        }

        It "Should return certificate error" {
            try {
                Get-MsGraphAuthTokenWithCert -TenantName "NoSuchTenant" -AppId "123456789" -CertificateThumbprint "NoCert"
            }
            catch {
                $Error[0].Exception.Message | Should -BeLike "Certificate was not found or could not be loaded*"
            }
        }
    }

    Context "Bad URI" {
        BeforeAll {
            $sCertName = "TestCert_" + (Get-Random).toString()
            $objCert = New-SelfSignedCertificate -FriendlyName $sCertName -NotAfter ((Get-Date).adddays(730)) -Subject $sCertName -CertStoreLocation "Cert:\CurrentUser\" -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -KeyLength 2048 -KeySpec KeyExchange -KeyExportPolicy NonExportable

            Mock Invoke-RestMethod { throw "Bad URI" }
        }

        It "Should return failed to request data from MSGraph" {
            try {
                Get-MsGraphAuthTokenWithCert -TenantName "NoSuchTenant" -AppId "123456789" -CertificateThumbprint $objCert.Thumbprint
            }
            catch {
                $Error[0].Exception.Message | Should -BeLike "Failed to request a token from MSGraph*"
            }
        }

        AfterAll {
            # Remove cert
            $sCertPath = "Cert:\CurrentUser\My\" + $objCert.Thumbprint 
            Remove-Item $sCertPath 
        }        
    }       
}

AfterAll {
    Remove-Item function:Get-MsGraphAuthTokenWithCert   
}