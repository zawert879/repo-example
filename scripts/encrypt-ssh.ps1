# PowerShell Script to Encrypt SSH Keys

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Blue "=== Encrypt SSH Keys ==="
Write-Output ""

# Проверка наличия data/data.yml
if (-not (Test-Path "data\data.yml")) {
    Write-ColorOutput Red "Error: data\data.yml not found"
    Write-Output "Please create and fill data\data.yml first"
    Write-Output "See data\README.md for instructions"
    exit 1
}

# Проверка SOPS
if (-not (Get-Command sops -ErrorAction SilentlyContinue)) {
    Write-ColorOutput Red "Error: sops is not installed"
    exit 1
}

# Проверка Age ключа
if (-not $env:SOPS_AGE_KEY) {
    if (Test-Path ".keys\age.key") {
        $env:SOPS_AGE_KEY = (Get-Content ".keys\age.key" | Select-String "AGE-SECRET-KEY").ToString().Trim()
        Write-ColorOutput Green "✓ Using Age key from .keys\age.key"
    } elseif (Test-Path "secrets.env") {
        $ageKey = Get-Content "secrets.env" | Select-String "SOPS_AGE_KEY=" | ForEach-Object { $_ -replace "SOPS_AGE_KEY=", "" }
        if ($ageKey) {
            $env:SOPS_AGE_KEY = $ageKey.Trim()
            Write-ColorOutput Green "✓ Using Age key from secrets.env"
        }
    }
    
    if (-not $env:SOPS_AGE_KEY) {
        Write-ColorOutput Red "Error: SOPS_AGE_KEY not set"
        Write-Output "Set it with: `$env:SOPS_AGE_KEY='your-key'"
        Write-Output "Or place it in .keys\age.key or secrets.env"
        exit 1
    }
}

Write-ColorOutput Blue "Reading data from data\data.yml..."

# Проверка содержимого data.yml
$dataContent = Get-Content "data\data.yml" -Raw
if ($dataContent -match '\[Вставьте содержимое') {
    Write-ColorOutput Red "Error: data\data.yml contains placeholder text"
    Write-Output "Please fill in actual SSH data before encrypting"
    Write-Output "See data\README.md for instructions"
    exit 1
}

Write-Output ""
Write-ColorOutput Blue "Encrypting data\data.yml to .ssh.encrypted.yml..."

# Шифруем data.yml напрямую
try {
    sops -e "data\data.yml" | Out-File ".ssh.encrypted.yml" -Encoding UTF8
    Write-ColorOutput Green "✓ SSH configuration encrypted successfully"
} catch {
    Write-ColorOutput Red "Error: Failed to encrypt data.yml"
    Write-Output $_.Exception.Message
    exit 1
}

Write-Output ""
Write-ColorOutput Green "═══════════════════════════════════════"
Write-ColorOutput Green "  SSH Keys Encrypted Successfully"
Write-ColorOutput Green "═══════════════════════════════════════"
Write-Output ""
Write-ColorOutput Cyan "Next steps:"
Write-Output "  1. Review encrypted file: sops .ssh.encrypted.yml"
Write-Output "  2. Commit .ssh.encrypted.yml to git"
Write-Output "  3. Clean up data directory: rm -rf data\*"
Write-Output ""
Write-ColorOutput Yellow "⚠ IMPORTANT: Delete data\ contents after verification!"
Write-Output "  PowerShell: Remove-Item data\* -Recurse -Force"
Write-Output "  Bash: rm -rf data/*"
