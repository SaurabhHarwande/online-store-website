# Cross-platform script to retrieve SSH key from remote machine and output as JSON
# This PowerShell script runs on your LOCAL machine (Windows/Linux/Mac)
# It connects via SSH to the REMOTE Linux machine to retrieve the key

param(
    [string]$hostname = "devmachine.utho.saurabhharwande.com"
)

try {
    # Retrieve the SSH public key from the remote Linux machine via SSH
    $sshKey = ssh -o StrictHostKeyChecking=no root@$hostname "cat /root/.ssh/id_ed25519.pub" 2>$null

    if ($LASTEXITCODE -eq 0 -and $sshKey) {
        # Trim whitespace and output as JSON for Terraform external data source
        $trimmedKey = $sshKey.Trim()
        $json = @{
            key = $trimmedKey
        } | ConvertTo-Json -Compress
        Write-Output $json
        exit 0
    } else {
        Write-Error "Failed to retrieve SSH key from remote machine"
        exit 1
    }
} catch {
    Write-Error "Error: $_"
    exit 1
}
