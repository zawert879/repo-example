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

# Проверка наличия незашифрованных ключей
if (-not (Test-Path ".ssh-keys")) {
    Write-ColorOutput Red "Error: .ssh-keys directory not found"
    Write-Output "Nothing to encrypt"
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
    } else {
        Write-ColorOutput Red "Error: SOPS_AGE_KEY not set"
        Write-Output "Set it with: `$env:SOPS_AGE_KEY='your-key'"
        Write-Output "Or place it in .keys\age.key"
        exit 1
    }
}

# Проверка наличия ключей
if (-not (Test-Path ".ssh-keys\id_ed25519")) {
    Write-ColorOutput Red "Error: SSH private key not found in .ssh-keys\"
    exit 1
}

Write-ColorOutput Blue "Reading SSH keys..."

# Запрос дополнительной информации
$sshHost = Read-Host "SSH Host (IP or domain)"
$sshUsername = Read-Host "SSH Username"
$sshPort = Read-Host "SSH Port [22]"
if ([string]::IsNullOrWhiteSpace($sshPort)) { $sshPort = "22" }

Write-Output ""
Write-ColorOutput Blue "Creating encrypted SSH configuration..."

# Создаем временный файл
$sshPrivate = Get-Content ".ssh-keys\id_ed25519" -Raw
$sshContent = @"
SSH_PRIVATE_KEY="$sshPrivate"
SSH_HOST="$sshHost"
SSH_USERNAME="$sshUsername"
SSH_PORT="$sshPort"
"@

$sshContent | Out-File ".ssh-temp" -Encoding UTF8 -NoNewline

# Шифруем
sops -e .ssh-temp | Out-File ".ssh.encrypted" -Encoding UTF8

# Удаляем временный файл
Remove-Item ".ssh-temp" -Force

Write-ColorOutput Green "✓ SSH configuration encrypted"
Write-Output ""

# Удаляем незашифрованные ключи
Write-ColorOutput Yellow "Removing unencrypted SSH keys..."
$confirm = Read-Host "Are you sure you want to delete .ssh-keys\ directory? [y/N]"

if ($confirm -match '^[Yy]$') {
    Remove-Item ".ssh-keys" -Recurse -Force
    Write-ColorOutput Green "✓ Unencrypted keys removed"
    
    # Удаляем из .gitignore
    if (Test-Path ".gitignore") {
        $gitignoreContent = Get-Content ".gitignore" | Where-Object { $_ -notmatch "\.ssh-keys/" }
        $gitignoreContent | Set-Content ".gitignore"
    }
} else {
    Write-ColorOutput Yellow "⚠ Unencrypted keys kept in .ssh-keys\"
    Write-ColorOutput Yellow "  Remember to delete them manually and remove from .gitignore"
}

Write-Output ""
Write-ColorOutput Green "═══════════════════════════════════════"
Write-ColorOutput Green "  SSH Keys Encrypted Successfully"
Write-ColorOutput Green "═══════════════════════════════════════"
Write-Output ""
Write-ColorOutput Cyan "Next steps:"
Write-Output "  1. Review encrypted file: sops .ssh.encrypted"
Write-Output "  2. Commit .ssh.encrypted to git"
Write-Output "  3. Add SSH public key to your server"
Write-Output ""
Write-ColorOutput Yellow "Public key (add this to your server):"
if (Test-Path ".ssh-keys\id_ed25519.pub") {
    Get-Content ".ssh-keys\id_ed25519.pub"
} else {
    Write-Output "(Public key was already removed)"
}
