# Connect to Exchange Online
Connect-ExchangeOnline -UserPrincipalName youradmin@yourtenant.onmicrosoft.com # Don't forget to change this login username

# Create Gmail migration endpoint
New-MigrationEndpoint -Gmail `
  -ServiceAccountKeyFileData ([System.IO.File]::ReadAllBytes("C:\Path\To\Your\ServiceAccountKey.json")) ` # Change the path here for your generated json
  -EmailAddress adminuser@clientdomain.com ` # Use your Google Super Admin
  -Name gmailEndpoint
