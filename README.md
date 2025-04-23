# ARStack Migration & Compliance Toolkit

PowerShell automation scripts to assist with:
- Microsoft 365 user onboarding
- Email migration (Gmail to M365)
- Litigation Hold rotation for HIPAA compliance
- Google Drive ownership audit and selective migration

> No actual client data is included. CSVs in `/Examples` are for structure reference only.

---

## - Included Modules

### - Exchange
- `ApplyLitHold.ps1`  
    Purpose: Applies E3 license + litigation hold to 25 accounts at a time.
    CSV: StaleAccounts.csv
    Expected Columns:
        Email

- `RemoveE3IfHeld.ps1`  
    Purpose: Checks if Litigation Hold was applied, removes E3 license if so.
    CSV: ProcessedLitHolds.csv (output of ApplyLitHold)
    Expected Columns:
        Email
        HoldApplied (true/false)
        LicenseStatus

- `ConvertSharedMailboxes.ps1`
    Purpose: Load CSV, assign license, convert to shared mailbox, remove license.
    CSV: OldAccountSharedMailboxConversion.csv
    Expected Columns:
        Email

### - GDrive Auditing
- `DriveSummary.ps1`  
    Purpose: Uses GAMADV-XTD3 to query user Drive file sizes.
    CSV: StaleAccounts.csv
    Expected Columns:
        Email

- `FileOwnershipAudit.ps1` *(TBD)*  
    Purpose: Parse Drive file exports, group by owner, prep for migration.

- `MassUnsuspendViaCSV.ps1`
    Purpose: Unsuspends users loaded from CSV.
    CSV: StaleAccounts.csv
    Expected Columns:
        Email

- `AllUsersWithNames.bat`
    Purpose: Retrieves all users with their full names.

- `ForwardingAddress.bat`
    Purpose: Retrieves all mailboxes and any forwarding addresses associated with each mailbox.

### - Gmail to 365 Migration Automation
- `LoadMigrationBatch.ps1`  
    Purpose: Creates a migration batch using Gmail endpoint.
    CSV: OldAccountConversionBatch.csv
    Expected Columns:
        EmailAddress
        UserName
        Password

- `CreateEndpoint.ps1`
    Purpose: Creates a Google Workspace Endpoint in Microsoft MMT (Microsoft Migration Tool)

- `DeltaSync.ps1`
    Purpose: Add migration batches as you create them. Run this file to sync all batches 
    Expected Columns:
        This script has batch names hardcoded. Edit the script directly to add/remove batches.

### - OnAndOffboarding
- `OnboardUser.ps1`  
    Purpose: Full user creation, group placement, profile updates, and license assignment.
    Prompts Interactively.

- `BulkImportFull Name.ps1`
    Purpose: Adds user First Name, Last Name, and Display Name imported via CSV
    CSV: BulkFullName.csv
    Expected Columns:
        primaryEmail
        name.givenName
        name.familyName
        name.fullName

### - Entra
  `FindOrphanedUsers.ps1`
    Purpose: Helps you find users that don't belong to any groups. Hardcoded object IDs.

- `MassMoveOrphanedUsersViaCSV.ps1`
    Purpose: Adds users to Entra ID group using hardcoded object ID.
    CSV: UsersToGroup.csv
    Expected Columns:
        Email
---

##  Usage

Update all hardcoded paths before running:
```powershell
$csvPath = "C:\YourFolder\StaleAccounts.csv"
$gamPath = "C:\GAMADV-XTD3\gam.exe"
$outputPath = "C:\YourPath\StaleAccounts_log.csv"
$skuID = "WhateverTheCrazyLongSKUIs" (Use Get-MsolAccountSku to get the SKU)
$objectID = "The Object ID for an Entra Group"
$Domain = "The domain you want to use"
$batchName = "Whatever you want to call your batch"
$endpointName = "Whatever you want to call your Endpoint for the migration"

## Dependencies

Microsoft Graph PowerShell SDK
https://github.com/taers232c/GAMADV-XTD3

ExchangeOnlineManagement
Install-Module ExchangeOnlineManagement -AllowClobber -Force

MSOnline
Install-Module MSOnline

MSGraph
Install-Module Microsoft.Graph

GAMADV-XTD3 (for Google Drive operations)
https://github.com/taers232c/GAMADV-XTD3

---
© 2025 ARStack. Internal use only. Not for public distribution.  
