# PowerShell скрипт для настройки GitHub Secrets
# Использование: .\setup-github-secrets.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Настройка GitHub Secrets ===" -ForegroundColor Green

# Проверка наличия файла secrets.env
if (-not (Test-Path "secrets.env")) {
    Write-Host "Ошибка: Файл secrets.env не найден!" -ForegroundColor Red
    Write-Host "Создайте его на основе secrets.example.env" -ForegroundColor Yellow
    exit 1
}

# Загрузка переменных из secrets.env
$secrets = @{}
Get-Content "secrets.env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        # Убираем кавычки если есть
        $value = $value -replace '^["'']|["'']$', ''
        $secrets[$key] = $value
    }
}

# Проверка установки GitHub CLI
$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue

if (-not $ghInstalled) {
    Write-Host "Ошибка: GitHub CLI (gh) не установлен!" -ForegroundColor Red
    Write-Host "Установите gh: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host "Или используйте: winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}

# Проверка авторизации в GitHub
try {
    gh auth status 2>&1 | Out-Null
    Write-Host "GitHub CLI найден и авторизован" -ForegroundColor Green
} catch {
    Write-Host "Вы не авторизованы в GitHub CLI" -ForegroundColor Yellow
    Write-Host "Выполните: gh auth login" -ForegroundColor Yellow
    exit 1
}

# Функция для установки секрета через GitHub CLI
function Set-Secret {
    param(
        [string]$Name,
        [string]$Value
    )
    
    Write-Host "Установка секрета: $Name" -ForegroundColor Yellow
    $Value | gh secret set $Name
    Write-Host "✓ Секрет $Name установлен" -ForegroundColor Green
}

# Установка только SOPS Age Key
if (-not $secrets.ContainsKey("SOPS_AGE_KEY") -or [string]::IsNullOrWhiteSpace($secrets["SOPS_AGE_KEY"])) {
    Write-Host "Ошибка: SOPS_AGE_KEY не установлен!" -ForegroundColor Red
    exit 1
}

Set-Secret -Name "SOPS_AGE_KEY" -Value $secrets["SOPS_AGE_KEY"]

Write-Host "`n=== Настройка завершена! ===" -ForegroundColor Green
Write-Host "SSH креденшиалы хранятся в зашифрованном файле .ssh.encrypted в репозитории" -ForegroundColor Yellow
Write-Host "Не забудьте удалить файл secrets.env после настройки!" -ForegroundColor Yellow
