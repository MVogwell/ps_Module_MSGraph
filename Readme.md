# ps_Module_MsGraph 

**Version 1.2 - Nov 2022**

_This module contains code by Alex Asplund - https://automativity.com - details within the code in-file help and this readme._

<br>

This module contains the following functions for interacting with MS Graph

* Get-MsGraphAuthTokenWithCert
  * This function will create a auth token for MS Graph using a certificate to authenticate with an Azure App Registration <br><br>
* Get-MSGraphUri
  * This function will generate a correctly formatted Uri string from resource type, filter and select inputs <br><br>
* Request-MsGraphData
  * This function will request data from MS Graph from a given auth token and requesting Uri <br><br>


## History

* Version 1.0 - Tested and working version for release
* Version 1.0.1 - Added an parameter "SelectAll" in Get-MsGraphUri which will automatically use all known, available, user attributes
* Version 1.1 - Update to Request-MsGraphData to handle single object return (as opposed to array return)
* Version 1.2 - Added pester unit tests and changed parameter objRequest to objAuth for Request-MsGraphData.ps1 whilst maintaining backwards compatility

<br><br>

## Requirements

For the functions in this module to work you must have a Azure App Registration created that contains a certificate in the Secret/Certificates section and authorisation to the resources you want to query.

Below is an example of the process for completing this to read Azure AD data

* Create a certificate on your machine under the user account you want to use to authenticate to Azure with (the certificate should be tied to the machine/account):
  * Run the PowerShell command: `$cert = New-SelfSignedCertificate -FriendlyName "ENTER A NAME HERE" -NotAfter ((get-date).adddays(730)) -Subject "ENTER THE SUBJECT NAME HERE" -CertStoreLocation "Cert:\CurrentUser\" -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -KeyLength 2048 -KeySpec KeyExchange -KeyExportPolicy NonExportable`
  * Export the public certificate for this certicate: `Export-Certificate -Type CERT -FilePath ($Env:Temp + "\MyExportedCert.cer") -Cert ("Cert:\CurrentUser\My\" + $cert.Thumbprint) -Force`
  * The exported certificate is saved to the %temp% folder
  * Still in PowerShell run the command $cert.Thumbprint | clip
  * Paste this value into notepad - you'll need this value for later
* Go to https://portal.azure.com/ and search and open "App registrations"
* Create a "new registration". The details for this will vary as Azure is updated and the settings will change as to your setup.
* Once the app registration has been created, go to "Certificates and Secrets" and select "Certificates". Upload the certificate you created in step 1
* Go to the menu item "API permissions" (normally on the left side of the screen)
* Select "Add a permission". At this point you want to select the permissions for the data you want to extract from MsGraph. For example if you want to read user,groups,etc data:
  * Select "Add a permission" then "Microsoft Graph"
  * Select Application permissions
  * Search for directory and select expand the item "Directory"
  * Select "Directory.ReadAll" then click "Add permission"
* To finish you must select the "Grant admin consent for YOURCOMPANY" button
* The Azure app is now ready to use.

The function Get-MsGraphAuthTokenWithCert in this module is used to authenticate to Azure. The Appid is available from the Overview section of the app registration. The certificate thumbprint was copied into notepad in an earlier step of these instructions but can also be retrieved using the PowerShell command `Get-ChildItem cert:\CurrentUser\My | Select thumbprint, FriendlyName`

<br><br>

## Example of using the functions together

The functions can be used together to request the auth token, create the request Uri and then request the data as seen below:

### Example 1 - Basic request for user resources returning the standard attributes

`Import-Module .\ps_Module_MsGraph.psd1`

`$objConnection = Get-MsGraphAuthTokenWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C9999"`

`$sUri = Get-MSGraphUri`

`$arrData = Request-MsGraphData -objRequest $objConnection -Uri $sUri`

`$arrData | Out-GridView`

<br><br>

### Example 2 - Request user resources for specific attributes (displayName and mail)

`Import-Module .\ps_Module_MsGraph.psd1`

`$objConnection = Get-MsGraphAuthTokenWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C9999"`

`$sUri = Get-MSGraphUri -Select "displayName,mail"`

`$arrData = Request-MsGraphData -objRequest $objConnection -Uri $sUri`

`$arrData | Out-GridView`

<br><br>

### Example 3 - Request a specific user resource using a filter

`Import-Module .\ps_Module_MsGraph.psd1`

`$objConnection = Get-MsGraphAuthTokenWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C9999"`

`$sUri = Get-MSGraphUri -Filter "id eq '2f3b5820-820a-411bd-bd43-43fed5d44455'`

`$arrData = Request-MsGraphData -objRequest $objConnection -Uri $sUri`

`$arrData | Out-GridView`

<br><br>

### Example 4 - Request group resources - this will return all groups and could take some time

`Import-Module .\ps_Module_MsGraph.psd1`

`$objConnection = Get-MsGraphAuthTokenWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C9999"`

`$sUri = Get-MSGraphUri -ResourceType "groups"`

`$arrData = Request-MsGraphData -objRequest $objConnection -Uri $sUri`

`$arrData | Out-GridView`

<br><br>

### Example 4 - Request a specific groups' members

`Import-Module .\ps_Module_MsGraph.psd1`

`$objConnection = Get-MsGraphAuthTokenWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C9999"`

`$sUri = (Get-MSGraphUri -ResourceType "groups") + "/0065198a-3443-4723-81f0-189f7f5d21b3/members"`

`$arrData = Request-MsGraphData -objRequest $objConnection -Uri $sUri`

`$arrData | Out-GridView`

<br><br>

## Get-MsGraphAuthTokenWithCert

**SYNOPSIS**

Function to connect to MSGraph using a certificate and retuns an authentication token. This function was written by Alex Asplund and reused from https://adamtheautomator.com/powershell-graph-api/ - and then I modified it to use paramaters for the connection details. His website is at https://automativity.com.


**DESCRIPTION**

This function accepts a certificate and creates a JWT auth token before attempting to authenticate against MSGraph. For this to work you must first create an Azure App Registration that has permission to MsGraph and you must also upload the certificate to Azure. See https://adamtheautomator.com/powershell-graph-api/ for more information on this.


**PARAMETER** `TenantName`

Mandatory. This string value is the Azure tenancy Name (not the id guid)


**PARAMETER** `AppId`

Mandatory. This is the guid id of the App Registrtaion that the authentication certificate and permissions have been assigned to.


**PARAMETER** `CertificateThumbprint`

Mandatory. This is the Certificate Thumbprint to use to authenticate with the Azure App Proxy. See this site for info on how to get the thumbprint of a cert using PowerShell: https://devblogs.microsoft.com/scripting/powertip-use-powershell-to-discover-certificate-thumbprints/


**PARAMETER** `CertificateLocation`

Optional. The function will, by default, check for the certificate in the current user certificate store. To specify another store use this parameter. Default = Cert:\CurrentUser\My\


**PARAMETER** `Scope`

Optional. This is the MSGraph scope - you shouldn't need to change this but have the option to here.


**EXAMPLE**

`$objRequest = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172"`

This example shows the minimum requirements for connecting to MSGraph and returning an authentication token


**EXAMPLE**

`$objRequest = Connect-MsGraphWithCert -TenantName "mytenant.onmicrosoft.com" -AppId "b5c3dab3-634a-49f9-9e70-d87faadf7a2c" -CertificateThumbprint "48504E974C0DAC5B5CD476C8202274B24C8C7172" -CertificateLocation = "Cert:\LocalMachine\My\"`

As above but specifying the computer certificate store rather than the user store.


**Further information**
Alex Asplund's original code : https://adamtheautomator.com/powershell-graph-api/

Martin Vogwell - https://github.com/mvogwell

\
<br><br>


## Get-MSGraphUri

**SYNOPSIS**

Function to generate a basic MSGraph request Uri from a query type (e.g. User,devices,etc), a Filter and Select parameters.

**PARAMETER** `Filter`

Optional. Into this section add a string of any MSGraph filters as per https://docs.microsoft.com/en-us/graph/query-parameters#filter-parameter.

If this parameter is not specified a filter will not be added to the uri

**PARAMETER** `Select`

Optional. Into this section add a string of any attributes to return in a select statement as per https://docs.microsoft.com/en-us/graph/query-parameters#select-parameter

If this parameter is not specified a select statement will not be added to the uri

**PARAMETER** `ResourceType`

Optional. This parameter allows you to change the resource type of data retured by MSGraph See https://docs.microsoft.com/en-us/graph/call-api for more information.

If this parameter is not specified the "users" resource type is used.

**PARAMETER** `ResourceType`

Optional. Is this switch parameter is used then all USER attributes will be returned - it just saves typing them in manually. Any attributes entered via the -Select parameter will be ignored.

**EXAMPLE**

`[string]$Uri = Get-MSGraphUri`

This would return https://graph.microsoft.com/v1.0/users

**EXAMPLE**

`[string]$Uri = Get-MSGraphUri -Filter "startsWith(displayName,'Bob')"`

This would return https://graph.microsoft.com/v1.0/users?$filter=startsWith(displayName,'Bob')

**EXAMPLE**

`[string]$Uri = Get-MSGraphUri -Select "displayName,mail"`

This would return https://graph.microsoft.com/v1.0/users?$select=displayName,mail

**EXAMPLE**

`[string]$Uri = Get-MSGraphUri -Filter "startsWith(displayName,'Bob')" -Select "displayName,mail"`

This would return "https://graph.microsoft.com/v1.0/users?\$filter=startsWith(displayName,'Bob')&$select=displayName,mail"

**LINK**

Martin Vogwell - https://github.com/mvogwell

\
<br><br>

## Request-MsGraphData
**SYNOPSIS**

Function to request data from MS Graph - requires an auth token and a Uri to request from. Use the functions in this module to create these (Get-MsGraphAuthTokenWithCert and Get-MSGraphUri). If no data is returned then $null will be returned

**PARAMETER** `objRequest`

Mandatory. This object should contain the MS Graph auth token connection object. This can be obtained by using the function Get-MsGraphAuthTokenWithCert

**PARAMETER** `Uri`

Mandatory. This is the MS Graph Uri (e.g. https://graph.microsoft.com/v1.0/users). This can be manually entered or you can use the function Get-MSGraphUri to build the Uri.

**PARAMETER** `HideProgress`

Optional. If this switch is used then the PowerShell progress bar will not be displayed when requesting data from MS Graph

**EXAMPLE**

`$arrData = Request-MsGraphData -objRequest $objRequest -Uri $sUri`

This would return the array variable $arrData containing the results from the Uri request in $sUri

**EXAMPLE**

`$arrData = Request-MsGraphData -objRequest $objRequest -Uri $sUri -HideProgress`

Same as last example but will not display the progress bars.

**EXAMPLE**

`$arrData = Request-MsGraphData -objRequest $objRequest -Uri $sUri -Verbose`

Same as first example but will display the verbose information from the function

**LINK**

Martin Vogwell - https://github.com/mvogwell