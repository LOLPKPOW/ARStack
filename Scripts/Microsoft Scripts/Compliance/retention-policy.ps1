# Connect to Compliance Center (Microsoft Purview)
Connect-IPPSSession

# Define policy settings for Exchange, SharePoint, and Teams
$policySettings = @(
    @{
        Name = "7 Year Hold and Delete - Exchange/SharePoint"
        Description = "Retention policy for Exchange and SharePoint data"
        Locations = "Exchange mailboxes, SharePoint sites"
        RetentionAction = "Delete"
        RetentionDuration = "7 Years"
    },
    @{
        Name = "7 Year Hold and Delete - Teams"
        Description = "Retention policy for Teams data"
        Locations = "Microsoft Teams"
        RetentionAction = "Delete"
        RetentionDuration = "7 Years"
    },
    @{
        Name = "7 Year Hold and Delete - Teams Private Chats"
        Description = "Retention policy for Teams Private Chats"
        Locations = "Teams Private Chats"
        RetentionAction = "Delete"
        RetentionDuration = "7 Years"
    }
)

# Loop through each policy setting and create the retention policy
foreach ($policy in $policySettings) {
    # Check if the policy already exists
    $existingPolicy = Get-RetentionCompliancePolicy | Where-Object { $_.Name -eq $policy.Name }
    
    # If the policy exists, update it; if not, create a new one
    if ($existingPolicy) {
        Set-RetentionCompliancePolicy -Identity $policy.Name `
            -RetentionAction $policy.RetentionAction `
            -RetentionDuration $policy.RetentionDuration `
            -Enabled $true
        Write-Output "Policy '$($policy.Name)' updated and enabled."
    } else {
        New-RetentionCompliancePolicy -Name $policy.Name `
            -Description $policy.Description `
            -RetentionAction $policy.RetentionAction `
            -RetentionDuration $policy.RetentionDuration `
            -Enabled $true `
            -Locations $policy.Locations
        Write-Output "New policy '$($policy.Name)' created and enabled."
    }
}
