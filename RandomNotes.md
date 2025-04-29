For the automation to deploy Unifed Audit Logs via Azure Automation to SharePoint:

-- Created the App Registration for the automation
-- Generate self signed certificate
        # 1) Create a self-signed cert in your local store, marked Exportable
        $cert = New-SelfSignedCertificate `
        -Subject         "CN=RunbookAutomationCert" `
        -KeyAlgorithm    RSA `
        -KeyLength       2048 `
        -NotAfter        (Get-Date).AddYears(5) `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -KeyUsage        DigitalSignature,KeyEncipherment `
        -HashAlgorithm   SHA256

        # 2) Export the .pfx (includes private key) — ensure you pick a strong password
        $pfxPath = "$PWD\RunbookAutomationCert.pfx"
        $pfxPwd  = ConvertTo-SecureString -String "YourP@ssw0rd!" -AsPlainText -Force
        Export-PfxCertificate `
        -Cert   $cert `
        -FilePath $pfxPath `
        -Password $pfxPwd

        # 3) Export the .cer (public key only)
        $cerPath = "$PWD\RunbookAutomationCert.cer"
        Export-Certificate `
        -Cert     $cert `
        -FilePath $cerPath

        Write-Output "Generated and exported PFX + CER to $pfxPath / $cerPath"
-- Upload the exported .cer to the App Registration Certificates
-- Grant API permissions Sites.ReadWrite.All (Microsoft Graph), AuditLog.Read.All (Office 365 Management APIs), Exchange.ManageAsApp (Office 365 Exchange Online)
-- Store private key (the pfx) in the Automation Account, Certificates section. Make sure it's marked as exportable.
-- Turn on System-Assigned Managed Identity for the Automation Account (so you can run Connect-AzAccount -Identity)

