Function Request-MsGraphData() {
	[CmdletBinding()]
	param (
		[Parameter (mandatory=$false)]$objAuth,
		[Parameter (dontshow)]$objRequest,
		[Parameter (mandatory=$true)][string]$Uri,
		[Parameter (mandatory=$false)][switch]$HideProgress
	)

	BEGIN {
		# Create the return variable
		$arrData = @()

		# This handles the legacy parameter name for objAuth which prior to v1.2 was objRequest
		if (($null -eq $objAuth) -and ($null -eq $objRequest)) {
			throw "You must provide an authentication object to the function. Run Get-MsGraphAuthTokenWithCert first to obtain the authentication token."
		}
		elseif ($null -eq $objAuth) {
			$objAuth = $objRequest
		}

		# Set the header that will be passed with the request
		try {
			Write-Verbose "Creating header containing the access token from the connection request."

            if (($null -eq $objAuth.token_type) -or ($null -eq $objAuth.access_token)) {
                throw "The access token must include the properties token_type and access_token"
            }

			$objHeader = @{ Authorization = "$($objAuth.token_type) $($objAuth.access_token)" }

			Write-Verbose "Header created"
		}
		catch {
			$sErrMsg = ("Failed to create request header. Error: " + $Global:Error[0].Exception.toString())

			Throw $sErrMsg
		}
	}
	PROCESS {
		# Attempt the initial request
		try {
			if ($HideProgress -eq $false) {
				Write-Progress -Activity "Requesting initial data from MSGraph" -Status "Requesting $sUri"
			}

			# Request the uri from graph
			$objInfoRequest = Invoke-RestMethod -Uri $Uri -Headers $objHeader -Method Get -ContentType "application/json"

			if ($HideProgress -eq $false) {
				Write-Progress -Activity "Requesting initial data from MSGraph" -Status "Request successful"
			}

			# Add the returned data to the array - this will change according to whether a single object or an array has been returned
			if ($null -eq $objInfoRequest) {
				throw "No data returned (null)"
			}
			elseif (!(($objInfoRequest | Get-Member -MemberType Properties | Select-Object Name).Name -contains "value")) {
				Write-Verbose "Single object returned"
				$arrData += $objInfoRequest
			}
			else {
				Write-Verbose "Array object returned"
				$arrData += $objInfoRequest.value
			}
		}
		catch {
			$sErrMsg = ("Failed to request data. Error: " + $Global:Error[0].Exception.toString())

			Throw $sErrMsg
		}

		# Attempt the request to MS Graph for any remaining "pages" of data
		if (!($null -eq $objInfoRequest.'@odata.nextLink')) {
			try {
				# This is a counter of the "pages" of data returned by @odata.nextLink. It is only used within the Write-Progress status
				$iPageCount = 1

				# Loop until there is no more data available from the request
				Do {
					Write-Verbose "Requesting page: $($objInfoRequest.'@odata.nextLink')"

					if ($HideProgress -eq $false) {
						Write-Progress -Activity "Requesting available page data from MSGraph" -Status "Page $iPageCount"
					}

					# Perform the request against the next link from the previous data
					$objInfoRequest = Invoke-RestMethod -Uri $objInfoRequest.'@odata.nextLink' -Headers $objHeader -Method Get -ContentType "application/json"

					# Add the returned data to the
					if (($objInfoRequest | Get-Member -MemberType Properties | Select-Object Name).Name -contains "value") {
						$arrData += $objInfoRequest.value
					}
					else {
						$arrData += $objInfoRequest
					}

					Write-Verbose "... Successfully requested data"

					# increment the count of the pages returned by MSGraph - this is only used in the write-progress status
					$iPageCount ++
				} While (!($null -eq $objInfoRequest.'@odata.nextLink'))
			}
			catch {
				$sErrMsg = ("Failed to request page $iPageCount of data from MSGraph. Error: " + $Global:Error[0].Exception.toString())

				Throw $sErrMsg
			}
		}
		else {
			Write-Verbose "No further pages of data returned"
		}
	}
	END {
		# Tidy up
		$objHeader = $null

		Write-Verbose "Returning data"

		# Return the array containing the data
		return Write-Output $arrData -NoEnumerate
	}


	<#
        .SYNOPSIS
        Function to request data from MS Graph - requires an auth token and a Uri to request from. Use the functions in this module to create these (Get-MsGraphAuthTokenWithCert and Get-MSGraphUri). If no data is returned then $null will be returned

		.DESCRIPTION
		Version history

		v1.0 - Production release
		v1.1 - Found instance where a single object is returned which needed to be handled differently
		v1.2 - Changed the authentication token object parameter from objRequest to objAuth. The old param is still supported but hidden from intellisense suggestion.

        .PARAMETER objAuth
        Mandatory. This object should contain the MS Graph auth token connection object. This can be obtained by using the function Get-MsGraphAuthTokenWithCert. Before v1.2 of this script the parameter "objRequest" was used. This is still supported but new scripts should use objAuth

		.PARAMETER objRequest
		Legacy. Prior to v1.2 of this script the authentication

		.PARAMETER Uri
        Mandatory. This is the MS Graph Uri (e.g. https://graph.microsoft.com/v1.0/users). This can be manually entered or you can use the function Get-MSGraphUri to build the Uri.

        .PARAMETER HideProgress
        Optional. If this switch is used then the PowerShell progress bar will not be displayed when requesting data from MS Graph

        .EXAMPLE
		$objAuth = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172"
		$sUri = Get-MSGraphUri -Select "displayName,mail"
		$arrData = Request-MsGraphData -objAuth $objAuth -Uri $sUri

		This would return the array variable $arrData containing the results from the Uri request in $sUri

        .EXAMPLE
		$objAuth = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172"
		$sUri = Get-MSGraphUri -Select "displayName,mail"
		$arrData = Request-MsGraphData -objAuth $objAuth -Uri $sUri -HideProgress

		Same as last example but will not display the progress bars.

		.EXAMPLE
		$objAuth = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172"
		$sUri = Get-MSGraphUri -Select "displayName,mail"
		$arrData = Request-MsGraphData -objAuth $objAuth -Uri $sUri -Verbose

		Same as first example but will display the verbose information from the function

        .LINK
        Martin Vogwell - https://github.com/mvogwell
    #>
}