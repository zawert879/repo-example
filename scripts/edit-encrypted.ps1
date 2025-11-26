# PowerShell script to edit encrypted files

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Cyan "═══════════════════════════════════════════════════════════"
Write-ColorOutput Cyan " Edit Encrypted Files with SOPS"
Write-ColorOutput Cyan "═══════════════════════════════════════════════════════════"
Write-Output ""

# Проверка наличия SOPS
if (-not (Get-Command sops -ErrorAction SilentlyContinue)) {
    Write-ColorOutput Red "Error: SOPS is not installed"
    Write-Output "Install it from: https://github.com/mozilla/sops/releases"
    exit 1
}

# Установка переменной окружения для Age ключа
$ageKeyFile = ".\.keys\age.key"
if (-not (Test-Path $ageKeyFile)) {
    Write-ColorOutput Red "Error: Age key file not found: $ageKeyFile"
    Write-Output "Run init.ps1 first to generate the key"
    exit 1
}

$env:SOPS_AGE_KEY_FILE = (Resolve-Path $ageKeyFile).Path
Write-ColorOutput Green "✓ Using Age key: $env:SOPS_AGE_KEY_FILE"
Write-Output ""

# Поиск зашифрованных файлов
Write-ColorOutput Blue "Searching for encrypted files..."
$encryptedFiles = @()

# Поиск в stacks/
if (Test-Path "stacks") {
    $stackFiles = Get-ChildItem -Path "stacks" -Recurse -File | Where-Object { 
        $_.Name -match "\.encrypted\." 
    }
    $encryptedFiles += $stackFiles
}

# Поиск .ssh.encrypted* (.ssh.encrypted, .ssh.encrypted.yml, .ssh.encrypted.env)
$sshFiles = Get-ChildItem -Path "." -File | Where-Object { 
    $_.Name -match "^\.ssh\.encrypted(\.(yml|yaml|env))?$" 
}
$encryptedFiles += $sshFiles

# Поиск .env.encrypted* (.env.encrypted, .env.encrypted.yml, .env.encrypted.env)
$envFiles = Get-ChildItem -Path "." -File | Where-Object { 
    $_.Name -match "^\.env\.encrypted(\.(yml|yaml|env))?$" 
}
$encryptedFiles += $envFiles

# Поиск secrets.encrypted.* (secrets.encrypted.yml, secrets.encrypted.env и т.д.)
$secretFiles = Get-ChildItem -Path "." -File | Where-Object { 
    $_.Name -match "^secrets\.encrypted\.(yml|yaml|env)" 
}
$encryptedFiles += $secretFiles

if ($encryptedFiles.Count -eq 0) {
    Write-ColorOutput Yellow "No encrypted files found"
    Write-Output "Searched in:"
    Write-Output "  - stacks/ (*.encrypted.*)"
    Write-Output "  - .ssh.encrypted[.yml|.env]"
    Write-Output "  - .env.encrypted[.yml|.env]"
    Write-Output "  - secrets.encrypted.[yml|env]"
    exit 0
}

Write-ColorOutput Green "✓ Found $($encryptedFiles.Count) encrypted file(s)"
Write-Output ""

# Показываем список файлов
Write-Output "Select a file to edit:"
for ($i = 0; $i -lt $encryptedFiles.Count; $i++) {
    $relativePath = $encryptedFiles[$i].FullName.Replace((Get-Location).Path + "\", "")
    Write-Output "  [$($i + 1)] $relativePath"
}
Write-Output ""

# Выбор файла
$selection = Read-Host "Enter file number [1-$($encryptedFiles.Count)]"
$selectedIndex = [int]$selection - 1

if ($selectedIndex -lt 0 -or $selectedIndex -ge $encryptedFiles.Count) {
    Write-ColorOutput Red "Invalid selection"
    exit 1
}

$selectedFile = $encryptedFiles[$selectedIndex]
Write-Output ""
Write-ColorOutput Blue "Opening: $($selectedFile.Name)"
Write-ColorOutput Yellow "⚠ File will be decrypted, opened in editor, and re-encrypted on save"
Write-Output ""

# Редактирование с помощью SOPS
try {
    sops $selectedFile.FullName
    Write-ColorOutput Green "✓ File edited and re-encrypted successfully"
} catch {
    Write-ColorOutput Red "Error editing file: $_"
    exit 1
}
