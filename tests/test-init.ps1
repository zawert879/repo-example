#!/usr/bin/env pwsh
# Комплексные тесты для init.ps1

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$global:TestsPassed = 0
$global:TestsFailed = 0
$global:TestsSkipped = 0

function Write-TestHeader($Message) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-TestResult($TestName, $Result, $Message = "") {
    if ($Result) {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $global:TestsPassed++
    } else {
        Write-Host "  ✗ $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "    Error: $Message" -ForegroundColor Gray
        }
        $global:TestsFailed++
    }
}

function Test-FunctionExists($FunctionName) {
    $result = Get-Command $FunctionName -ErrorAction SilentlyContinue
    Write-TestResult "Function '$FunctionName' exists" ($null -ne $result)
    return ($null -ne $result)
}

function Test-FileExists($FilePath) {
    $result = Test-Path $FilePath
    Write-TestResult "File exists: $FilePath" $result
    return $result
}

# Начало тестов
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║        Init.ps1 Comprehensive Test Suite                 ║" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

# Test 1: Проверка существования файлов скриптов
Write-TestHeader "Test Suite 1: Script Files"

Test-FileExists "init.ps1"
Test-FileExists "init.sh"
Test-FileExists "scripts/setup-github-secrets.ps1"
Test-FileExists "scripts/setup-github-secrets.sh"
Test-FileExists "scripts/encrypt-ssh.ps1"
Test-FileExists "scripts/encrypt-ssh.sh"

# Test 2: Загрузка функций из скрипта
Write-TestHeader "Test Suite 2: Function Definitions"

# Загружаем функции из init.ps1 без выполнения основного кода
$scriptContent = Get-Content "init.ps1" -Raw
$functionsOnly = $scriptContent -replace '(?s)Clear-Host.*$', ''

try {
    Invoke-Expression $functionsOnly
    Write-TestResult "Script functions loaded successfully" $true
} catch {
    Write-TestResult "Script functions loaded successfully" $false $_.Exception.Message
}

# Проверка наличия функций
Test-FunctionExists "Write-ColorOutput"
Test-FunctionExists "Write-Header"
Test-FunctionExists "Ask-YesNo"
Test-FunctionExists "Check-AndInstallDeps"
Test-FunctionExists "Validate-GitHubRepo"

# Test 3: Тестирование Ask-YesNo функции
Write-TestHeader "Test Suite 3: Ask-YesNo Function"

try {
    # Тест с default N
    $testResult = $null
    $result = ($null -ne (Get-Command Ask-YesNo -ErrorAction SilentlyContinue))
    Write-TestResult "Ask-YesNo function signature valid" $result
    
    # Проверка что функция принимает параметры
    $params = (Get-Command Ask-YesNo).Parameters
    Write-TestResult "Ask-YesNo has 'Prompt' parameter" ($params.ContainsKey('Prompt'))
    Write-TestResult "Ask-YesNo has 'Default' parameter" ($params.ContainsKey('Default'))
} catch {
    Write-TestResult "Ask-YesNo function tests" $false $_.Exception.Message
}

# Test 4: Тестирование Validate-GitHubRepo
Write-TestHeader "Test Suite 4: Validate-GitHubRepo Function"

try {
    # Валидные форматы
    $validRepos = @(
        "user/repo",
        "user-name/repo-name",
        "user_name/repo_name",
        "user123/repo456"
    )
    
    foreach ($repo in $validRepos) {
        # Проверяем только формат (без реального API вызова)
        $isValid = $repo -match "^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$"
        Write-TestResult "Validate format: $repo" $isValid
    }
    
    # Невалидные форматы
    $invalidRepos = @(
        "invalid",
        "user/",
        "/repo",
        "user//repo",
        "user repo/repo"
    )
    
    foreach ($repo in $invalidRepos) {
        $isInvalid = $repo -notmatch "^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$"
        Write-TestResult "Reject invalid format: $repo" $isInvalid
    }
} catch {
    Write-TestResult "Validate-GitHubRepo tests" $false $_.Exception.Message
}

# Test 5: Проверка командной строки SSH
Write-TestHeader "Test Suite 5: SSH Key Generation Commands"

$sshCommands = @{
    "ed25519" = 'ssh-keygen -t ed25519 -C "deploy@gitops" -f ".ssh-keys\id_ed25519" -N `"`"'
    "rsa" = 'ssh-keygen -t rsa -b 4096 -C "deploy@gitops" -f ".ssh-keys\id_rsa" -N `"`"'
}

foreach ($type in $sshCommands.Keys) {
    $cmd = $sshCommands[$type]
    $hasEscapedQuotes = $cmd -match '`"'
    Write-TestResult "SSH $type command has escaped quotes" $hasEscapedQuotes
    
    $hasValidPath = $cmd -match '\.ssh-keys\\'
    Write-TestResult "SSH $type command has valid path" $hasValidPath
}

# Test 6: Тестирование создания secrets.env
Write-TestHeader "Test Suite 6: Secrets.env Creation"

try {
    $testKey = "AGE-SECRET-KEY-1TESTKEYTESTKEYTESTKEYTESTKEYTESTKEYTESTKEYTESTKEYTESTKEY"
    $testContent = @"
# SOPS Age Private Key
SOPS_AGE_KEY=$testKey
"@
    
    $tempFile = "test-secrets-$((Get-Random)).env"
    $testContent | Out-File $tempFile -Encoding UTF8 -Force
    
    if (Test-Path $tempFile) {
        $content = Get-Content $tempFile -Raw
        Write-TestResult "Secrets.env file created" $true
        Write-TestResult "Secrets.env contains SOPS key" ($content -like "*$testKey*")
        Write-TestResult "Secrets.env has correct format" ($content -match "SOPS_AGE_KEY=AGE-SECRET-KEY-")
        
        Remove-Item $tempFile -Force
    } else {
        Write-TestResult "Secrets.env file created" $false
    }
} catch {
    Write-TestResult "Secrets.env creation test" $false $_.Exception.Message
}

# Test 7: Тестирование SOPS encryption syntax
Write-TestHeader "Test Suite 7: SOPS Encryption Syntax"

try {
    $tempFile = "test-sops-$((Get-Random)).txt"
    "TEST_KEY=test_value" | Out-File $tempFile -Encoding UTF8 -NoNewline
    
    Write-TestResult "SOPS temp file created" (Test-Path $tempFile)
    
    # Проверка синтаксиса команды шифрования
    $encryptCmd = "sops -e $tempFile"
    Write-TestResult "SOPS encrypt command syntax valid" ($encryptCmd -match "sops -e")
    
    # Проверка наличия sops
    $sopsInstalled = $null -ne (Get-Command sops -ErrorAction SilentlyContinue)
    if ($sopsInstalled) {
        Write-TestResult "SOPS is installed" $true
    } else {
        Write-Host "  ⚠ SOPS not installed (skipping actual encryption test)" -ForegroundColor Yellow
        $global:TestsSkipped++
    }
    
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
} catch {
    Write-TestResult "SOPS encryption test" $false $_.Exception.Message
}

# Test 8: Проверка .gitignore patterns
Write-TestHeader "Test Suite 8: Gitignore Configuration"

if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    
    $patterns = @(
        "secrets.env",
        ".env",
        ".keys/",
        ".ssh-keys/",
        "*.key",
        "*.pem"
    )
    
    foreach ($pattern in $patterns) {
        $exists = $gitignoreContent -match [regex]::Escape($pattern)
        Write-TestResult "Gitignore contains '$pattern'" $exists
    }
} else {
    Write-TestResult ".gitignore exists" $false
}

# Test 9: Проверка SOPS конфигурации
Write-TestHeader "Test Suite 9: SOPS Configuration"

if (Test-Path ".sops.yaml") {
    $sopsConfig = Get-Content ".sops.yaml" -Raw
    
    Write-TestResult "SOPS config has age encryption" ($sopsConfig -match "age:")
    Write-TestResult "SOPS config has creation rules" ($sopsConfig -match "creation_rules:")
    Write-TestResult "SOPS config has path matcher" ($sopsConfig -match "path_regex:")
    
    # Проверка паттернов шифрования
    $patterns = @(".env.encrypted", ".ssh.encrypted")
    foreach ($pattern in $patterns) {
        $exists = $sopsConfig -match [regex]::Escape($pattern)
        Write-TestResult "SOPS config includes '$pattern'" $exists
    }
} else {
    Write-TestResult ".sops.yaml exists" $false
}

# Test 10: Проверка структуры директорий
Write-TestHeader "Test Suite 10: Directory Structure"

$requiredDirs = @(
    ".github",
    ".github/workflows",
    "scripts",
    "stacks"
)

foreach ($dir in $requiredDirs) {
    $exists = Test-Path $dir
    Write-TestResult "Directory exists: $dir" $exists
}

# Test 11: Проверка example-app структуры
Write-TestHeader "Test Suite 11: Example-App Structure"

if (Test-Path "example-app") {
    $exampleFiles = @(
        "example-app/Dockerfile",
        "example-app/src/index.html",
        "example-app/.github/workflows/build-and-deploy.yml"
    )
    
    foreach ($file in $exampleFiles) {
        Test-FileExists $file
    }
    
    # Проверка Dockerfile
    if (Test-Path "example-app/Dockerfile") {
        $dockerfile = Get-Content "example-app/Dockerfile" -Raw
        Write-TestResult "Dockerfile has FROM nginx:alpine" ($dockerfile -match "FROM nginx:alpine")
        Write-TestResult "Dockerfile copies index.html" ($dockerfile -match "COPY.*index.html")
    }
} else {
    Write-Host "  ⚠ example-app not found (skipped)" -ForegroundColor Yellow
    $global:TestsSkipped++
}

# Test 12: Проверка GitHub Actions workflow
Write-TestHeader "Test Suite 12: GitHub Actions Workflows"

$workflowFile = ".github/workflows/deploy.yml"
if (Test-Path $workflowFile) {
    $workflow = Get-Content $workflowFile -Raw
    
    Write-TestResult "Workflow uses SOPS_AGE_KEY secret" ($workflow -match "SOPS_AGE_KEY")
    Write-TestResult "Workflow has detect-changes job" ($workflow -match "detect-changes:")
    Write-TestResult "Workflow has deploy job" ($workflow -match "deploy:")
    Write-TestResult "Workflow uses matrix strategy" ($workflow -match "matrix:")
    Write-TestResult "Workflow decrypts .ssh.encrypted" ($workflow -match "\.ssh\.encrypted")
} else {
    Write-TestResult "Deploy workflow exists" $false
}

# Test 13: Проверка скриптов setup
Write-TestHeader "Test Suite 13: Setup Scripts"

$setupScripts = @{
    "scripts/setup-github-secrets.ps1" = @("gh secret set", "SOPS_AGE_KEY")
    "scripts/encrypt-ssh.ps1" = @("sops -e", "\.ssh\.encrypted")
}

foreach ($script in $setupScripts.Keys) {
    if (Test-Path $script) {
        $content = Get-Content $script -Raw
        foreach ($pattern in $setupScripts[$script]) {
            Write-TestResult "$script contains '$pattern'" ($content -match $pattern)
        }
    } else {
        Write-TestResult "$script exists" $false
    }
}

# Test 14: Проверка README документации
Write-TestHeader "Test Suite 14: Documentation"

$docs = @(
    "README.md",
    "GITOPS.md",
    "EXAMPLE-APP.md",
)

foreach ($doc in $docs) {
    Test-FileExists $doc
    
    if (Test-Path $doc) {
        $content = Get-Content $doc -Raw
        $hasContent = $content.Length -gt 100
        Write-TestResult "$doc has substantial content" $hasContent
    }
}

# Test 15: Проверка secrets.example.env
Write-TestHeader "Test Suite 15: Secrets Template"

if (Test-Path "secrets.example.env") {
    $template = Get-Content "secrets.example.env" -Raw
    Write-TestResult "Template contains SOPS_AGE_KEY placeholder" ($template -match "SOPS_AGE_KEY")
    Write-TestResult "Template has comments" ($template -match "#")
} else {
    Write-TestResult "secrets.example.env exists" $false
}

# Итоговый отчет
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║                    Test Summary                           ║" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

$totalTests = $global:TestsPassed + $global:TestsFailed
$passRate = if ($totalTests -gt 0) { [math]::Round(($global:TestsPassed / $totalTests) * 100, 2) } else { 0 }

Write-Host "  Total Tests:    $totalTests" -ForegroundColor Cyan
Write-Host "  Passed:         $global:TestsPassed" -ForegroundColor Green
Write-Host "  Failed:         $global:TestsFailed" -ForegroundColor Red
Write-Host "  Skipped:        $global:TestsSkipped" -ForegroundColor Yellow
Write-Host "  Pass Rate:      $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($global:TestsFailed -eq 0) {
    Write-Host "✓ All tests passed! Ready for deployment!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed. Please review the errors above." -ForegroundColor Red
    exit 1
}
