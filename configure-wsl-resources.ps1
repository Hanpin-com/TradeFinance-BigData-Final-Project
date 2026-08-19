# ============================================================
# Configure WSL2 resources for Docker Desktop
# Target host:
#   RAM: ~16 GB
#   Logical CPUs: 12
#
# Configuration:
#   WSL RAM: 10 GB
#   WSL CPUs: 8
#   Swap: 4 GB
#   Automatic memory reclamation enabled
#
# IMPORTANT:
# This script DOES NOT restart WSL or Docker Desktop.
# Existing containers will not be stopped.
# ============================================================

$ErrorActionPreference = "Stop"

$WslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"

Write-Host ""
Write-Host "Configuring WSL2 resources for Docker Desktop..."
Write-Host "Target file: $WslConfigPath"
Write-Host ""

# ------------------------------------------------------------
# Backup existing configuration if one exists
# ------------------------------------------------------------

if (Test-Path $WslConfigPath) {

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $BackupPath = "$WslConfigPath.backup-$Timestamp"

    Copy-Item `
        -Path $WslConfigPath `
        -Destination $BackupPath `
        -Force

    Write-Host "Existing .wslconfig backed up:"
    Write-Host "  $BackupPath"
}
else {
    Write-Host "No existing .wslconfig found."
}

# ------------------------------------------------------------
# Define configuration
# ------------------------------------------------------------

$WslConfig = @"
[wsl2]
memory=10GB
processors=8
swap=4GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
"@

# ------------------------------------------------------------
# Write configuration
# ------------------------------------------------------------

Set-Content `
    -Path $WslConfigPath `
    -Value $WslConfig `
    -Encoding ASCII

Write-Host ""
Write-Host "WSL2 configuration written successfully."
Write-Host ""

# ------------------------------------------------------------
# Verify resulting file
# ------------------------------------------------------------

Write-Host "============================================================"
Write-Host "Current .wslconfig"
Write-Host "============================================================"

Get-Content $WslConfigPath

Write-Host "============================================================"
Write-Host ""

# ------------------------------------------------------------
# Display host resources for reference
# ------------------------------------------------------------

$Computer = Get-CimInstance Win32_ComputerSystem

$RamGB = [math]::Round(
    $Computer.TotalPhysicalMemory / 1GB,
    1
)

Write-Host "Host resources:"
Write-Host "  Physical RAM       : $RamGB GB"
Write-Host "  Logical processors : $($Computer.NumberOfLogicalProcessors)"
Write-Host ""
Write-Host "Configured for WSL2:"
Write-Host "  Memory              : 10 GB"
Write-Host "  Processors          : 8"
Write-Host "  Swap                : 4 GB"
Write-Host "  Memory reclamation  : gradual"
Write-Host "  Sparse VHD          : enabled"
Write-Host ""

Write-Host "Configuration complete."
Write-Host ""
Write-Host "IMPORTANT:"
Write-Host "WSL has NOT been restarted."
Write-Host "Docker Desktop has NOT been restarted."
Write-Host "Your running containers have NOT been intentionally stopped."
Write-Host ""
Write-Host "The new settings will take effect after the controlled"
Write-Host "WSL/Docker Desktop restart in the next step."