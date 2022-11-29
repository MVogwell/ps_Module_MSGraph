Function Get-MsGraphAuthTokenWithCert {
	[CmdletBinding()]
	param (
		[Parameter (mandatory=$true)][string]$TenantName,
		[Parameter (mandatory=$true)][string]$AppId,
		[Parameter (mandatory=$true)][string]$CertificateThumbprint,
		[Parameter (mandatory=$false)][string]$CertificateLocation = "Cert:\CurrentUser\My\",
		[Parameter (mandatory=$false)][string]$Scope = "https://graph.microsoft.com/.default"
	)

    # IMPORTANT: This function builds on the excellent code by Alex Asplund.
    # Their original post can be found here : https://adamtheautomator.com/powershell-graph-api/

	BEGIN {
		# Set the error action response for this function
		$objErrActionPref = $ErrorActionPreference
		$ErrorActionPreference = "Stop"

		# Used to check the signature loaded from the private cert
		$bSigFailed = $false

		# Show the function being run in verbose
		Write-Verbose "*** Function: Get-MsGraphAuthTokenWithCert"

		# Set a value for the return object (if case it fails to be created)
		$objAuth = $null

		# Get the certificate from the local certificate store
		try {
			$sCertPath = ($CertificateLocation + $CertificateThumbprint)
			$Certificate = Get-Item $sCertPath

			Write-Verbose "`t+++ Certificate discovered $Certificate.Subject"
		}
		catch {
			$ErrorActionPreference = $objErrActionPref

			if (!($null -eq $Global:Error[0])) {
				$sErrMsg = ("Certificate was not found or could not be loaded. Error: " + $Global:Error[0].Exception.toString())
			}
			else {
				$sErrMsg = ("Certificate was not found or could not be loaded. No more details available")
			}

			Throw $sErrMsg
		}
	}
	PROCESS {
		# Create the request object
		try {
			Write-Verbose "`t+++ Creating the JWT object"

			# Create base64 hash of certificate
			$CertificateBase64Hash = [System.Convert]::ToBase64String($Certificate.GetCertHash())

			# Create JWT timestamp for expiration
			$StartDate = (Get-Date "1970-01-01T00:00:00Z" ).ToUniversalTime()
			$JWTExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End (Get-Date).ToUniversalTime().AddMinutes(2)).TotalSeconds
			$JWTExpiration = [math]::Round($JWTExpirationTimeSpan,0)

			# Create JWT validity start timestamp
			$NotBeforeExpirationTimeSpan = (New-TimeSpan -Start $StartDate -End ((Get-Date).ToUniversalTime())).TotalSeconds
			$NotBefore = [math]::Round($NotBeforeExpirationTimeSpan,0)

			# Create JWT header
			$JWTHeader = @{
				alg = "RS256"
				typ = "JWT"
				# Use the CertificateBase64Hash and replace/strip to match web encoding of base64
				x5t = $CertificateBase64Hash -replace '\+','-' -replace '/','_' -replace '='
			}

			# Create JWT payload
			$JWTPayLoad = @{
				# What endpoint is allowed to use this JWT
				aud = "https://login.microsoftonline.com/$TenantName/oauth2/token"

				# Expiration timestamp
				exp = $JWTExpiration

				# Issuer = your application
				iss = $AppId

				# JWT ID: random guid
				jti = [guid]::NewGuid()

				# Not to be used before
				nbf = $NotBefore

				# JWT Subject
				sub = $AppId
			}

			# Convert header and payload to base64
			$JWTHeaderToByte = [System.Text.Encoding]::UTF8.GetBytes(($JWTHeader | ConvertTo-Json))
			$EncodedHeader = [System.Convert]::ToBase64String($JWTHeaderToByte)

			$JWTPayLoadToByte =  [System.Text.Encoding]::UTF8.GetBytes(($JWTPayload | ConvertTo-Json))
			$EncodedPayload = [System.Convert]::ToBase64String($JWTPayLoadToByte)

			# Join header and Payload with "." to create a valid (unsigned) JWT
			$JWT = $EncodedHeader + "." + $EncodedPayload

			# Get the private key object of your certificate
			$PrivateKey = $Certificate.PrivateKey
		}
		catch {
			$ErrorActionPreference = $objErrActionPref

			if (!($null -eq $Global:Error[0])) {
				$sErrMsg = ("Failed to create the JWT Payload. Error: " + $Global:Error[0].Exception.toString())
			}
			else {
				$sErrMsg = ("Failed to create the JWT Payload. No error details returned")
			}

			Throw $sErrMsg
		}

		try {
			# Define RSA signature and hashing algorithm
			$RSAPadding = [Security.Cryptography.RSASignaturePadding]::Pkcs1
			$HashAlgorithm = [Security.Cryptography.HashAlgorithmName]::SHA256

			# Create a signature of the JWT
			$Signature = [Convert]::ToBase64String(
				$PrivateKey.SignData([System.Text.Encoding]::UTF8.GetBytes($JWT),$HashAlgorithm,$RSAPadding)
			) -replace '\+','-' -replace '/','_' -replace '='

			# Join the signature to the JWT with "."
			$JWT = $JWT + "." + $Signature

		}
		catch {
			Write-Verbose "`t+++ Failed to use hash algorithm SHA256... attempting with SHA1"
			$bSigFailed = $true
		}

		if ($bSigFailed -eq $true) {
			try {
				# Define RSA signature and hashing algorithm
				$RSAPadding = [Security.Cryptography.RSASignaturePadding]::Pkcs1
				$HashAlgorithm = [Security.Cryptography.HashAlgorithmName]::SHA1

				# Create a signature of the JWT
				$Signature = [Convert]::ToBase64String(
					$PrivateKey.SignData([System.Text.Encoding]::UTF8.GetBytes($JWT),$HashAlgorithm,$RSAPadding)
				) -replace '\+','-' -replace '/','_' -replace '='

				# Join the signature to the JWT with "."
				$JWT = $JWT + "." + $Signature

				Write-Verbose "`t+++ Successfully created the Signature with SHA1"
			}
			catch {
				$ErrorActionPreference = $objErrActionPref

				if (!($null -eq $Global:Error[0])) {
					$sErrMsg = ("Failed to create private signature. Error: " + $Global:Error[0].Exception.toString())
				}
				else {
					$sErrMsg = ("Failed to create private signature. No error details returned")
				}

				Throw $sErrMsg
			}
		}

		try {
			# Create a hash with body parameters
			$Body = @{
				client_id = $AppId
				client_assertion = $JWT
				client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
				scope = $Scope
				grant_type = "client_credentials"
			}

			Write-Verbose "`t+++ JWT Object created"

			$Url = "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token"

			Write-Verbose "`t+++ Uri to connect: $Url"

			# Use the self-generated JWT as Authorization
			$Header = @{
				Authorization = "Bearer $JWT"
			}

			# Splat the parameters for Invoke-Restmethod for cleaner code
			$PostSplat = @{
				ContentType = 'application/x-www-form-urlencoded'
				Method = 'POST'
				Body = $Body
				Uri = $Url
				Headers = $Header
			}
		}
		catch {
			$ErrorActionPreference = $objErrActionPref

			if (!($null -eq $Global:Error[0])) {
				$sErrMsg = ("Failed to create token request. Error: " + $Global:Error[0].Exception.toString())
			}
			else {
				$sErrMsg = ("Failed to create token request.")
			}

			Throw $sErrMsg
		}


		try {
			Write-Verbose "`t+++ Attempting to request auth token"

			$objAuth = Invoke-RestMethod @PostSplat

			Write-Verbose "`t+++ Successfully requested auth token"
		}
		catch {
			$ErrorActionPreference = $objErrActionPref

			if (!($null -eq $Global:Error[0])) {
				$sErrMsg = ("Failed to request a token from MSGraph. Error: " + $Global:Error[0].Exception.toString())
			}
			else {
				$sErrMsg = ("Failed to request a token from MSGraph. No further details available")
			}

			Throw $sErrMsg
		}
	}
	END {
		# Reset the error action prefence
		$ErrorActionPreference = $objErrActionPref

		Write-Verbose "`t+++ Returning auth token - function finishing"

		return Write-Output $objAuth -NoEnumerate
	}

	<#
        .SYNOPSIS
        Function to connect to MSGraph using a certificate and retuns an authentication token. This function was written by Alex Asplund and reused from https://adamtheautomator.com/powershell-graph-api/ - and then I modified it to use paramaters for the connection details. His website is at https://automativity.com.

        .DESCRIPTION
        This function accepts a certificate and creates a JWT auth token before attempting to authenticate against MSGraph. For this to work you must first create an Azure App Registration that has permission to MsGraph and you must also upload the certificate to Azure. See https://adamtheautomator.com/powershell-graph-api/ for more information on this.

        .PARAMETER TenantName
        Mandatory. This string value is the Azure tenancy Name (not the id guid)

        .PARAMETER AppId
        Mandatory. This is the guid id of the App Registrtaion that the authentication certificate and permissions have been assigned to.

        .PARAMETER CertificateThumbprint
        Mandatory. This is the Certificate Thumbprint to use to authenticate with the Azure App Proxy. See this site for info on how to get the thumbprint of a cert using PowerShell: https://devblogs.microsoft.com/scripting/powertip-use-powershell-to-discover-certificate-thumbprints/

        .PARAMETER CertificateLocation
        Optional. The function will, by default, check for the certificate in the current user certificate store. To specify another store use this parameter. Default = Cert:\CurrentUser\My\

		.PARAMETER Scope
        Optional. This is the MSGraph scope - you shouldn't need to change this but have the option to here.

        .EXAMPLE
		$objAuth = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172"

		This example shows the minimum requirements for connecting to MSGraph and returning an authentication token

        .EXAMPLE
		$objAuth = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172" -CertificateLocation = "Cert:\LocalMachine\My\"

		As above but specifying the computer certificate store rather than the user store.

        .LINK
        Alex Asplund's original code : https://adamtheautomator.com/powershell-graph-api/

        .LINK
        Martin Vogwell - https://github.com/mvogwell/ps_Module_MSGraph
    #>
}