# Migration & Compliance Toolkit

PowerShell automation scripts to assist with:
- Microsoft 365 user onboarding
- Email migration (Gmail to M365)
- Litigation Hold rotation for HIPAA compliance
- Google Drive ownership audit and selective migration

> No actual client data is included. CSVs in `/Examples` are for structure reference only.

---

## - Included Modules

### - Dependencies
- `PowershellDependencyInstall.ps1`  
    Purpose: Installs all PowerShell Module Dependencies.

---

### - Exchange

- `ConvertSharedMailboxes.ps1`  
    Purpose: Load CSV, assign license, convert to shared mailbox, remove license.  
    CSV: `OldAccountSharedMailboxConversion.csv`  
    Expected Columns:  
    - `Email`

---

### - Entra

- `FindOrphanedUsers.ps1`  
    Purpose: Identify Entra ID users who are not a member of any department group.  
    Config: `find-orphaned-users.json`  
    Expected Output: `orphaned-users.csv`  
    Notes: Requires hardcoded group object IDs in config.

- `MassMoveOrphanedUsersViaCSV.ps1`  
    Purpose: Add a list of users (typically orphaned) to a specified Entra ID group.  
    Config: `orphaned-massmove.json`  
    CSV: `UsersToGroup.csv`  
    Expected Columns:  
    - `UserPrincipalName` or `Email`

- `MassDepartmentApplication.ps1`  
    Purpose: Creates new Entra ID users from CSV and applies department + location metadata.  
    Config: `onboarding-defaults.json`  
    CSV: `Users_WithUPN.csv`  
    Expected Columns:  
    - `UPN`  
    - `User` (Full name)  
    - `Department`  
    - `JobTitle` *(optional)*

---

### - GDrive Auditing

- `DriveSummary.ps1`  
    Purpose: Uses GAMADV-XTD3 to query user Drive file sizes.  
    CSV: `StaleAccounts.csv`  
    Expected Columns:  
    - `Email`

- `FileOwnershipAudit.ps1` *(TBD)*  
    Purpose: Parse Drive file exports, group by owner, prep for migration.

- `MassUnsuspendViaCSV.ps1`  
    Purpose: Unsuspends users loaded from CSV.  
    CSV: `StaleAccounts.csv`  
    Expected Columns:  
    - `Email`

- `AllUsersWithNames.bat`  
    Purpose: Retrieves all users with their full names.

- `ForwardingAddress.bat`  
    Purpose: Retrieves all mailboxes and any forwarding addresses associated with each mailbox.

- `DistributionListsAutomation.bat`  
    Purpose: Grabs all the distribution groups from GWorkspace with descriptions, then pulls all the members from the groups and exports to a file.

---

### - Gmail to 365 Migration Automation

- `LoadMigrationBatch.ps1`  
    Purpose: Creates a migration batch using Gmail endpoint.  
    CSV: `OldAccountConversionBatch.csv`  
    Expected Columns:  
    - `EmailAddress`  
    - `UserName`  
    - `Password`

- `CreateEndpoint.ps1`  
    Purpose: Creates a Google Workspace Endpoint in Microsoft MMT (Microsoft Migration Tool)

- `DeltaSync.ps1`  
    Purpose: Add migration batches as you create them. Run this file to sync all batches  
    Notes: Batch names are hardcoded; edit script directly.

- `CreateDistributionLists.ps1`  
    Purpose: Create distribution lists (with external receiving enabled) loaded from a CSV.  
    Expected Columns:  
    - `email`  
    - `name`  
    - `description`

---

### - OnAndOffboarding

- `Onboard.ps1`  
    Purpose: Full user creation, group placement, profile updates, and license assignment.  
    Prompts Interactively.

- `BulkImportFull Name.ps1`  
    Purpose: Adds user First Name, Last Name, and Display Name imported via CSV  
    CSV: `BulkFullName.csv`  
    Expected Columns:  
    - `primaryEmail`  
    - `name.givenName`  
    - `name.familyName`  
    - `name.fullName`

- `ApplyLitHold.ps1`  
    Purpose: Applies E3 and Litigation Hold to new user.  
    Embedded in `Onboard.ps1`.  
    Notes: Requires hardcoded SKU.

- `RemoveLitHold.ps1`  
    Purpose: Checks all users for E3+LitHold and removes E3 if both apply.

---

## Usage

Update all hardcoded paths before running:
```powershell
$csvPath = "C:\YourFolder\StaleAccounts.csv"
$gamPath = "C:\GAMADV-XTD3\gam.exe"
$outputPath = "C:\YourPath\StaleAccounts_log.csv"
$skuID = "WhateverTheCrazyLongSKUIs" # Use Get-MgSubscribedSku
$objectID = "The Object ID for an Entra Group"
$Domain = "The domain you want to use"
$batchName = "Whatever you want to call your batch"
$endpointName = "Whatever you want to call your Endpoint for the migration"

## Usage
Get-MgSubscribedSku | Select SkuPartNumber, SkuId, ConsumedUnits
