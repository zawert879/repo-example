#!/usr/bin/env pwsh
# Запуск всех тестов локально

param(
    [switch]$SkipDependencyCheck,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          Running All Tests Locally                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# 1. Проверка зависимостей
if (-not $SkipDependencyCheck) {
    Write-Host "[1/4] Checking dependencies..." -ForegroundColor Blue
    $deps = @("age-keygen", "sops", "gh", "ssh-keygen")
    $missing = @()
    
    foreach ($dep in $deps) {
        if (Get-Command $dep -ErrorAction SilentlyContinue) {
            Write-Host "  ✓ $dep" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $dep - not found" -ForegroundColor Yellow
            $missing += $dep
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠ Missing dependencies: $($missing -join ', ')" -ForegroundColor Yellow
        Write-Host "Some tests may be skipped." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Install via:" -ForegroundColor Cyan
        Write-Host "  Windows: choco install age sops gh" -ForegroundColor Gray
        Write-Host "  Linux: See tests/README.md for instructions" -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "[1/4] Skipping dependency check..." -ForegroundColor Yellow
}

# 2. Syntax check
Write-Host ""
Write-Host "[2/4] Checking PowerShell syntax..." -ForegroundColor Blue

$scripts = @("init.ps1") + (Get-ChildItem -Path scripts -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

foreach ($script in $scripts) {
    if (-not (Test-Path $script)) { continue }
    
    try {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Write-Host "  ✓ $(Split-Path $script -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $(Split-Path $script -Leaf) - $($errors.Count) errors" -ForegroundColor Red
            if ($Verbose) {
                $errors | ForEach-Object { Write-Host "    $($_.Message)" -ForegroundColor Gray }
            }
            $allPassed = $false
        }
    } catch {
        Write-Host "  ✗ $(Split-Path $script -Leaf) - $($_.Exception.Message)" -ForegroundColor Red
        $allPassed = $false
    }
}

# 3. Run PowerShell tests
Write-Host ""
Write-Host "[3/4] Running PowerShell test suite..." -ForegroundColor Blue

if (Test-Path "tests\test-init.ps1") {
    try {
        & ".\tests\test-init.ps1" -Verbose:$Verbose
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "✗ PowerShell tests failed" -ForegroundColor Red
            $allPassed = $false
        } else {
            Write-Host ""
            Write-Host "✓ PowerShell tests passed" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ Error running tests: $($_.Exception.Message)" -ForegroundColor Red
        $allPassed = $false
    }
} else {
    Write-Host "  ⚠ test-init.ps1 not found" -ForegroundColor Yellow
}

# 4. Check bash scripts (if on Linux/Mac or WSL available)
Write-Host ""
Write-Host "[4/4] Checking Bash scripts..." -ForegroundColor Blue

if (Get-Command bash -ErrorAction SilentlyContinue) {
    $bashScripts = @("init.sh") + (Get-ChildItem -Path scripts -Filter *.sh -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    
    foreach ($script in $bashScripts) {
        if (-not (Test-Path $script)) { continue }
        
        $result = bash -n $script 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $(Split-Path $script -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $(Split-Path $script -Leaf)" -ForegroundColor Red
            if ($Verbose) {
                Write-Host "    $result" -ForegroundColor Gray
            }
            $allPassed = $false
        }
    }
    
    # Run bash tests if available
    if (Test-Path "tests/test-init.sh") {
        Write-Host ""
        Write-Host "  Running Bash test suite..." -ForegroundColor Cyan
        bash tests/test-init.sh
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "✗ Bash tests failed" -ForegroundColor Red
            $allPassed = $false
        } else {
            Write-Host ""
            Write-Host "✓ Bash tests passed" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ⚠ Bash not available (skipped)" -ForegroundColor Yellow
    Write-Host "    Install Git Bash or WSL to test bash scripts" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Summary                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($allPassed) {
    Write-Host "✓ All tests passed! Ready to commit!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  git add ." -ForegroundColor White
    Write-Host "  git commit -m 'Add comprehensive tests'" -ForegroundColor White
    Write-Host "  git push" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "✗ Some tests failed. Please fix the issues above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Tips:" -ForegroundColor Yellow
    Write-Host "  - Run with -Verbose for detailed error messages" -ForegroundColor Gray
    Write-Host "  - Check syntax errors first" -ForegroundColor Gray
    Write-Host "  - Review test output for specific failures" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
