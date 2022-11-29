[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "")]
param()

BeforeAll {
    # Import the script file
    $sPath = ($PSScriptRoot).Replace("Tests","Public") + "\Request-MsGraphData.ps1"

    . $sPath

    $sRequestUri = "https://NoSuchUriExists101010101.com/TestUri"
}

Describe "Request-MsGraphData" {
    Context "Return data successfully" {
        BeforeAll {
            $objReturnValue = [PSCustomObject]@{
                Name = "SomeUser"
                Id = "123456"
            }

            $objExpectedReturn = [PSCustomObject]@{
                Req = "SomeReq"
                Value = $objReturnValue
                '@odata.nextLink' = $null
            }

            $objAuth = [PSCustomObject]@{
                token_type = "abc"
                access_token = "abcdefghij123"
            }

            Mock Invoke-RestMethod { return $objExpectedReturn }

            $objReturn = Request-MsGraphData -objAuth $objAuth -Uri $sRequestUri -HideProgress
        }

        It "Should return test user data" {
            $objReturn.Name | Should -be "SomeUser"
            $objReturn.Id | Should -be "123456"
        }
    }

    Context "Invalid auth object" {
        BeforeAll {
            $objAuth = [PSCustomObject]@{}
        }

        It "Should return an error with auth object" {
            try {
                $objReturn = Request-MsGraphData -objAuth $objAuth -Uri $sRequestUri -HideProgress
            }
            catch {
                $Error[0].Exception.Message | Should -belike "Failed to create request header*"
            }
        }
    }

    Context "Handle error with bad uri request" {
        BeforeAll {
            $objReturnValue = [PSCustomObject]@{
                Name = "SomeUser"
                Id = "123456"
            }

            $objExpectedReturn = [PSCustomObject]@{
                Req = "SomeReq"
                Value = $objReturnValue
                '@odata.nextLink' = $null
            }

            $objAuth = [PSCustomObject]@{
                token_type = "abc"
                access_token = "abcdefghij123"
            }

            Mock Invoke-RestMethod { throw "Failed to access URI" }

            
        }

        It "Should return error accessing uri" {
            try {
                $objReturn = Request-MsGraphData -objAuth $objAuth -Uri $sRequestUri -HideProgress
            }
            catch {
                $Error[0].Exception.Message | Should -BeLike "Failed to request data*Failed to access URI"
            }
        }
    }    
}

AfterAll {
    Remove-Item function:Request-MsGraphData
}