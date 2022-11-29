Function Get-MSGraphUri() {
	[CmdletBinding()]
	param (
		[Parameter (mandatory=$false)][string]$Filter = "*",
		[Parameter (mandatory=$false)][string]$Select = "*",
		[Parameter (mandatory=$false)][string]$ResourceType = "users",
		[Parameter (mandatory=$false)][string]$GraphVer = "v1.0",
		[Parameter (mandatory=$false)][switch]$SelectAll
	)

	BEGIN {
		# Parse the input data (filter)
		if ([string]::IsNullOrEmpty($Filter)) {
			[string]$sFilter = "*"
		}
		else {
			[string]$sFilter = $Filter
		}

		Write-Verbose "Filter = $sFilter"

		# Parse the input data (select)
		if ($SelectAll -eq $true) {
			$sSelect = "id,displayName,accountEnabled,assignedLicenses,assignedPlans,businessPhones,city,companyName,country,createdDateTime,creationType,deletedDateTime,department,displayName,employeeHireDate,employeeId,employeeOrgData,employeeType,externalUserState,givenName,identities,imAddresses,isResourceAccount,jobTitle,lastPasswordChangeDateTime,licenseAssignmentStates,mail,mailNickname,mobilePhone,officeLocation,onPremisesDistinguishedName,onPremisesDomainName,onPremisesExtensionAttributes,onPremisesImmutableId,onPremisesLastSyncDateTime,onPremisesProvisioningErrors,onPremisesSamAccountName,onPremisesSecurityIdentifier,onPremisesSyncEnabled,onPremisesUserPrincipalName,otherMails,passwordPolicies,postalCode,preferredLanguage,proxyAddresses,showInAddressList,state,streetAddress,surname,usageLocation,userPrincipalName,userType"
		}
		elseif ([string]::IsNullOrEmpty($Select)) {
			[string]$sSelect = "*"
		}
		else {
			[string]$sSelect = $Select
		}

		Write-Verbose "Select = $sSelect"
	}
	PROCESS {
		# Create the return variable in case the request fails
		$sUri = $null

		# Set the error action response for this function (will be reset at the end)
		$objErrActionPref = $ErrorActionPreference
		$ErrorActionPreference = "Stop"

		# Create the url
		try {
			$sUri = "https://graph.microsoft.com/" + $GraphVer + "/" + $ResourceType

			if (($sSelect -ne "*") -or ($sFilter -ne "*")){
				Write-Verbose "A filter or select statement are present, appending ? to end of statement"
				$sUri += "?"
			}

			# If the filter isn't * then append it to the Uri
			if ($sFilter -ne "*") {
				$sUri += "`$filter=" + $sFilter
			}

			# If the select isn't * then append it to the Uri
			if ($sSelect -ne "*") {
				if ($sFilter -ne "*") {	# if a filter is present then concatonate the filter and select statements with &
					$sUri += "&"
				}

				# Add the select statement
				$sUri += "`$select=" + $sSelect
			}
		}
		catch {
			$sErrMsg = ("Failed to create the uri. Error: " + $Global:Error[0].Exception.toString())

			Throw $sErrMsg
		}
	}
	END {
		# Reset the error action prefence
		$ErrorActionPreference = $objErrActionPref

		# Tidy up
        Remove-Variable sSelect,sFilter -ErrorAction "SilentlyContinue"

		return $sUri
	}

	<#
        .SYNOPSIS
        Function to generate a basic MSGraph request Uri from a query type (e.g. User,devices,etc), a Filter and Select parameters.

		.DESCRIPTION
		Version History

		1.0 - Initial released version
		1.1 - Added GraphVer to be able to specify which version of Graph API to use
        1.2 - Updated tidy up to remove variables rather than setting to null

        .PARAMETER Filter
        Optional. Into this section add a string of any MSGraph filters as per https://docs.microsoft.com/en-us/graph/query-parameters#filter-parameter.

		If this parameter is not specified a filter will not be added to the uri

        .PARAMETER Select
        Optional. Into this section add a string of any attributes to return in a select statement as per https://docs.microsoft.com/en-us/graph/query-parameters#select-parameter

		If this parameter is not specified a select statement will not be added to the uri

        .PARAMETER ResourceType
        Optional. This parameter allows you to change the resource type of data retured by MSGraph See https://docs.microsoft.com/en-us/graph/call-api for more information.

		If this parameter is not specified the "users" resource type is used.

		.PARAMETER SelectAll
		Optional. Is this switch parameter is used then all user attributes will be returned - it just saves typing them in manually.

        .EXAMPLE
		[string]$Uri = Get-MSGraphUri

		This would return https://graph.microsoft.com/v1.0/users

        .EXAMPLE
		[string]$Uri = Get-MSGraphUri -Filter "startsWith(displayName,'Bob')"

		This would return https://graph.microsoft.com/v1.0/users?$filter=startsWith(displayName,'Bob')

        .EXAMPLE
		[string]$Uri = Get-MSGraphUri -Select "displayName,mail"

		This would return https://graph.microsoft.com/v1.0/users?$select=displayName,mail

        .EXAMPLE
		[string]$Uri = Get-MSGraphUri -Filter "startsWith(displayName,'Bob')" -Select "displayName,mail"

		This would return https://graph.microsoft.com/v1.0/users?$filter=startsWith(displayName,'Bob')&$select=displayName,mail

        .LINK
        Martin Vogwell - https://github.com/mvogwell
    #>
}