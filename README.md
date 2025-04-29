# ARStack Migration & Compliance Toolkit

PowerShell automation scripts to assist with:
- Microsoft 365 user onboarding
- Email migration (Gmail to M365)
- Litigation Hold rotation for HIPAA compliance
- Google Drive ownership audit and selective migration

> No actual client data is included. CSVs in `/Examples` are for structure reference only.

---

## - Included Modules

### - Dependencies
-`PowershellDependencyInstall.ps1`
    Purpose: Installs all Powershell Module Dependencies.

### - Exchange
- `LitHoldE3Apply.ps1`  
    Purpose: Applies E3 license + litigation hold to 25 accounts at a time.
    CSV: AccountsPendingLitHold.csv
    Expected Columns:
        Email
    Outputs:
        C:\AutomationLogs\output\ProcessedLitHolds.csv — Summary of holds applied
        C:\AutomationLogs\logs\LitHoldApplyLog.csv — Line-by-line operation log (success, skip, or error)

- `RemoveE3.ps1`  
    Purpose:
        Removes E3 license only if Litigation Hold is confirmed, for accounts in the most recent batch.
    CSV: 
        C:\AutomationLogs\output\ProcessedLitHolds.csv (← produced by LitHoldE3Apply.ps1)
    Required Columns:
        Email
    Output File:
        C:\AutomationLogs\log\RemoveE3Results.csv — results and log of license removals

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

-`AllUsersWithNames.bat`
    Purpose: Grabs all users with their Full Names

-`DistributionListsAutomation.bat`
    Purpose: Grabs all the distribution groups from GWorkspace with descriptions, then pulls all the members from the groups and exports to a file.


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

- `CreateDistributionLists.ps1`
    Purpose: Create distribution lists (with external receiving enabled) loaded from a csv.
    Expected Columns:
        email
        name
        description

### - OnAndOffboarding
- `Onboard.ps1`  
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

- `ApplyLitHold.ps1` 
    Purpose: Applies E3 and Litigation Hold to new user.
    Embedded in Onboard.ps1
    Requires SKU hardcoded into script.
    Remove if not required for client.

- `RemoveLitHold.ps1`
    Purpose: Checks all users to see who still has an E3 and Lit Hold is valid. Removes E3 is both apply.

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

    ## Cheat Sheet ##
    - `Find SKUs for licenses`
        Get-MgSubscribedSku | Select SkuPartNumber, SkuId, ConsumedUnits

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
