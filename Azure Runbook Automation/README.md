Unified Audit Log Export Automation

This Azure Automation solution retrieves **Unified Audit Logs** from Microsoft 365 every 24 hours, converts them into a CSV file, uploads them to **SharePoint**, and sends an **email notification** using Microsoft Graph — all without requiring interactive login or MFA.

Fully modular. HIPAA-aligned. Built for lean, secure IT ops.

---

## What It Does

- Authenticates to **Exchange Online** and **Microsoft Graph** using a certificate
- Pulls **24 hours of Unified Audit Logs**
- Converts results to CSV
- Uploads file to **SharePoint** under `/Audit Logs/YYYY/MM/DD/`
- Sends a confirmation email to designated recipients
- Designed for daily, automated compliance reporting

---

## Setup Instructions

### 1. App Registration (Microsoft Entra ID)

Create an app registration for the automation.

- **Platform:** None (headless automation)
- **Authentication:** Upload `.cer` file (see below)
- **Permissions** (Application type, admin-consent required):

#### Microsoft Graph
- `Mail.Send`
- `Sites.ReadWrite.All`
- `User.Read`

#### Office 365 Exchange Online
- `Exchange.ManageAsApp`

#### Office 365 Management APIs
- `ActivityFeed.Read`
- `ActivityFeed.ReadDlp`

> *Admin consent is required for all application-level permissions above.*

---

### 2. Create and Upload the Certificate

Generate a self-signed certificate (5 years recommended):

```powershell
# Generate cert in current user's store
$cert = New-SelfSignedCertificate -Subject "CN=RunbookAutomationCert" `
  -KeyAlgorithm RSA -KeyLength 2048 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -KeyExportPolicy Exportable `
  -KeyUsage DigitalSignature,KeyEncipherment `
  -NotAfter (Get-Date).AddYears(5) `
  -HashAlgorithm SHA256

# Export public key (.cer)
Export-Certificate -Cert $cert -FilePath "$PWD\RunbookAutomationCert.cer"

# Export private key (.pfx)
$pfxPassword = ConvertTo-SecureString "StrongPasswordHere" -AsPlainText -Force
Export-PfxCertificate -Cert $cert -FilePath "$PWD\RunbookAutomationCert.pfx" -Password $pfxPassword
```

- Upload the `.cer` to the **App Registration** in Entra ID
- Upload the `.pfx` to your **Azure Automation Account → Certificates**
  - Name: `ExchangeAutoCert`
  - Must be **Exportable**

---

### 3. Azure Automation Setup

- **Enable System-Assigned Managed Identity** on the Automation Account
- **Import Required Modules** from the Gallery:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Users.Actions`
  - `Microsoft.Graph.Sites`

> These are needed for `Connect-MgGraph`, `Send-MgUserMail`, and SharePoint upload.

---

### 4. Define Automation Variables

Go to **Automation Account → Variables**, and define:

ToEmail	- Email recipient address
FromEmail - Email sender address
ExchangeAppId - Application (client) ID of the App Registration
TenantId - Azure AD tenant ID
OrgDomain - Microsoft 365 domain (e.g., contoso.onmicrosoft.com)
SharePointSitePath - Site path after the domain (e.g., /sites/CompanySite)
SharePointSiteDomain - Domain prefix for SharePoint/Graph UR (e.g. contoso.sharepoint.com)
ExchangeAutomationCert - Name of the certificate asset in the Automation Account

You can access them in your runbook with:

```powershell
$toEmail            = Get-AutomationVariable -Name "ToEmail"
$fromEmail          = Get-AutomationVariable -Name "FromEmail"
$exchangeAppId      = Get-AutomationVariable -Name "ExchangeAppId"
$tenantId           = Get-AutomationVariable -Name "TenantId"
$orgDomain          = Get-AutomationVariable -Name "OrgDomain"
$sharePointDomain   = Get-AutomationVariable -Name "SharePointDomain"
$sitePath           = Get-AutomationVariable -Name "SharePointSitePath"
$automationCertName = Get-AutomationVariable -Name "ExchangeAutomationCert"

```

---

### 5. Runbook Notes

- **Runbook Type:** PowerShell
- **Authentication:** `Connect-AzAccount -Identity`
- Uses `Connect-MgGraph` and `Connect-ExchangeOnline` with `-Certificate` and `-AppId`
- Emails are sent using `Send-MgUserMail` (no SMTP, no MFA)

---

## Sample Workflow Output

```
→ Exchange Online OK.
→ Retrieved 1437 audit records.
→ Logs converted to CSV.
→ Uploaded to SharePoint at /Audit Logs/2025/05/01
→ Email sent to sec-audit-group@yourdomain.com
```

---

## Schedule the Runbook

Create a daily schedule:
- **Frequency:** Once per day
- **Time:** Early AM before users start activity (e.g. 2:00 AM)

---

## Folder Structure in SharePoint

```
/Audit Logs/
  └── 2025/
      └── 05/
          └── 01/
              └── UnifiedAuditLogs_20250501_020000.csv
```

---

## Security Notes

- All authentication is handled via cert-based **Application Permissions**
- No user MFA or stored credentials required
- Safe to use in regulated or HIPAA environments
- Automation certificate should be rotated every 1–3 years

---

## Author

**Patrick Woodward**  
Cloud Engineer | ARStack  
_This module is used in production for HIPAA-aligned environments and is available for reuse or consulting._

---

## Questions or Help?

Feel free to fork, reuse, or contact if you'd like help automating your Microsoft 365 compliance stack.
