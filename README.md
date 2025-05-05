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
    Purpose: Installs all required PowerShell modules.

---

### - Exchange

- `ConvertSharedMailboxes.ps1`  
    Purpose: Load CSV, assign license, convert to shared mailbox, remove license.  
    Config: `convert-to-shared.json`  
    CSV: `full-active-users.csv`  
    Expected Columns:  
    - `EmailAddress`

- `CreateMigrationEndpoint.ps1`  
    Purpose: Creates Gmail migration endpoint for Exchange Online MMT.  
    Config: `create-migration-endpoint.json`

- `LoadMigrationBatch.ps1`  
    Purpose: Loads a Gmail-to-O365 migration batch via endpoint.  
    Config: `load-migration-batch.json`  
    CSV: Gmail-format CSV with EmailAddress, Username, and Password.

- `DeltaSync.ps1`  
    Purpose: Starts all batches listed in MigrationBatchList.csv  
    CSV: `MigrationBatchList.csv`  
    Expected Columns:  
    - `BatchName`

---

### - Entra

- `Onboard.ps1`  
    Purpose: Interactively creates user, applies metadata, assigns license, and adds to DL.  
    Config: `onboarding-defaults.json`

- `Offboard.ps1`  
    Purpose: Disables user, revokes sessions, removes license, clears profile, converts mailbox to shared, deletes user.  
    Config: `onboarding-defaults.json`

- `MassDepartmentApplication.ps1`  
    Purpose: Creates users from CSV and applies default profile values.  
    Config: `onboarding-defaults.json`  
    CSV: `Users_WithUPN.csv`  
    Expected Columns:  
    - `UPN`  
    - `User` (Full Name)  
    - `Department`  
    - `JobTitle` *(optional)*

- `FindOrphanedUsers.ps1`  
    Purpose: Identifies users not in any department group.  
    Config: `find-orphaned-users.json`  
    Output: `orphaned-users.csv`

- `MassMoveOrphanedUsersViaCSV.ps1`  
    Purpose: Adds a list of users (e.g. orphans) to a specific Entra group.  
    Config: `orphaned-massmove.json`  
    CSV:  
    - `UserPrincipalName`

- `SetDefaultAddress.ps1`  
    Purpose: Applies default location and contact fields to all users.  
    Config: `onboarding-defaults.json`

---

### - Gmail to 365 Migration Automation

- `LoadMigrationBatch.ps1`  
    Purpose: Creates and starts a Gmail migration batch.  
    Config: `load-migration-batch.json`  
    CSV:  
    - `EmailAddress`  
    - `UserName`  
    - `Password`

- `CreateMigrationEndpoint.ps1`  
    Purpose: Creates a Google Workspace Endpoint for MMT.  
    Config: `create-migration-endpoint.json`

- `DeltaSync.ps1`  
    Purpose: Syncs all migration batches listed in a CSV.  
    CSV: `MigrationBatchList.csv`  
    Columns:  
    - `BatchName`

- `CreateDistributionLists.ps1`  
    Purpose: Creates distribution lists (with external receiving enabled) loaded from a CSV.  
    Expected Columns:  
    - `email`  
    - `name`  
    - `description`

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
    Purpose: Unsuspends users listed in a CSV.  
    CSV: `StaleAccounts.csv`  
    Expected Columns:  
    - `Email`

- `AllUsersWithNames.bat`  
    Purpose: Outputs all users with full names.

- `ForwardingAddress.bat`  
    Purpose: Lists forwarding addresses on all accounts.

- `DistributionListsAutomation.bat`  
    Purpose: Exports all distribution lists and their members from Google Workspace.

---

### - Intune & Device Security
 - `IntuneDeployment.ps1`
    Purpose: Creates Intune Deployments, and the necessary groups for said deployments.
            Group membership is not required at the time of deployment, just the groups creation, which is a part of the script.
                All Devices - Not Servers (dynamic)
                Allow USB
                Block USB

## - Usage

Update hardcoded paths and values before executing:
```powershell
$logPath      = "C:\ARStack\AutomationLogs\logs"
$gamPath      = "C:\GAMADV-XTD3\gam.exe"
$skuId        = "Use Get-MgSubscribedSku | Select SkuPartNumber, SkuId"
$domain       = "contoso.onmicrosoft.com"
$batchName    = "InitialUserMigration"
$endpointName = "gmailEndpoint"
```

To check license SKUs:
```powershell
Get-MgSubscribedSku | Select SkuPartNumber, SkuId, ConsumedUnits
```

---
