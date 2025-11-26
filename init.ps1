# PowerShell Initialization Script

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Header($Message) {
    Write-ColorOutput Cyan "═══════════════════════════════════════════════════════════"
    Write-ColorOutput Cyan " $Message"
    Write-ColorOutput Cyan "═══════════════════════════════════════════════════════════"
}

function Ask-YesNo($Prompt, $Default = "N") {
    $choice = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = $Default
    }
    return $choice -match '^[Yy]'
}

function Check-AndInstallDeps {
    $missingDeps = @()
    
    if (-not (Get-Command age-keygen -ErrorAction SilentlyContinue)) {
        $missingDeps += "age"
    }
    
    if (-not (Get-Command sops -ErrorAction SilentlyContinue)) {
        $missingDeps += "sops"
    }
    
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        $missingDeps += "gh"
    }
    
    if ($missingDeps.Count -eq 0) {
        Write-ColorOutput Green "✓ All dependencies are installed"
        return $true
    }
    
    Write-ColorOutput Yellow "Missing dependencies: $($missingDeps -join ', ')"
    Write-Output ""
    
    if (Ask-YesNo "Do you want to install missing dependencies automatically?" "Y") {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-ColorOutput Blue "Installing via winget..."
            foreach ($dep in $missingDeps) {
                switch ($dep) {
                    "age" {
                        Write-Output "Installing age..."
                        winget install FiloSottile.age
                    }
                    "sops" {
                        Write-Output "Installing sops..."
                        if (Get-Command scoop -ErrorAction SilentlyContinue) {
                            scoop install sops
                        } else {
                            Write-ColorOutput Yellow "Downloading sops manually..."
                            $sopsUrl = "https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.exe"
                            $sopsPath = "$env:USERPROFILE\bin\sops.exe"
                            New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\bin" | Out-Null
                            Invoke-WebRequest -Uri $sopsUrl -OutFile $sopsPath
                            Write-ColorOutput Yellow "Add to PATH: $env:USERPROFILE\bin"
                        }
                    }
                    "gh" {
                        Write-Output "Installing GitHub CLI..."
                        winget install GitHub.cli
                    }
                }
            }
            Write-ColorOutput Green "✓ Dependencies installed. Restart PowerShell to refresh PATH"
        } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-ColorOutput Blue "Installing via Chocolatey..."
            foreach ($dep in $missingDeps) {
                choco install $dep -y
            }
            Write-ColorOutput Green "✓ Dependencies installed"
        } else {
            Write-ColorOutput Yellow "⚠ Automatic installation not supported"
            Write-ColorOutput Yellow "Please install manually:"
            Write-Output "  - age: https://github.com/FiloSottile/age/releases"
            Write-Output "  - sops: https://github.com/mozilla/sops/releases"
            Write-Output "  - gh: https://cli.github.com/"
            return $false
        }
    } else {
        Write-ColorOutput Yellow "⚠ Please install dependencies manually"
        return $false
    }
    
    return $true
}

function Validate-GitHubRepo($Repo) {
    if ($Repo -notmatch "^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$") {
        Write-ColorOutput Red "Invalid repository format. Expected: username/repo-name"
        return $false
    }
    
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            gh repo view $Repo 2>$null | Out-Null
            Write-ColorOutput Green "✓ Repository validated: $Repo"
            return $true
        } catch {
            Write-ColorOutput Yellow "⚠ Repository not found or not accessible: $Repo"
            return (Ask-YesNo "Continue anyway?")
        }
    }
    
    return $true
}

Clear-Host
Write-Header "Repository Initialization Script"
Write-Header "GitOps Infrastructure Setup Tool"

# Проверка что мы в правильной директории
if (-not (Test-Path ".gitignore") -or -not (Test-Path ".github")) {
    Write-ColorOutput Red "Error: This script must be run from the root of the repository"
    exit 1
}

Write-Output ""
Write-ColorOutput Blue "Select repository type:"
Write-Output "  1) Server (Infrastructure/Deployment repository)"
Write-Output "  2) App (Application repository with CI/CD)"
Write-Output ""
$repoChoice = Read-Host "Enter your choice [1-2]"

switch ($repoChoice) {
    "1" {
        $repoType = "server"
        Write-ColorOutput Green "✓ Selected: Server repository"
    }
    "2" {
        $repoType = "app"
        Write-ColorOutput Green "✓ Selected: App repository"
    }
    default {
        Write-ColorOutput Red "Invalid choice. Exiting."
        exit 1
    }
}

Write-Output ""

# Проверка и установка зависимостей
Write-ColorOutput Blue "Checking dependencies..."
Check-AndInstallDeps
Write-Output ""

if ($repoType -eq "server") {
    Write-ColorOutput Yellow "=== Server Repository Initialization ==="
    Write-Output ""
    
    # 1. Удаление example-app
    Write-ColorOutput Blue "[1/7] Removing example-app directory..."
    if (Test-Path "example-app") {
        Remove-Item -Path "example-app" -Recurse -Force
        Write-ColorOutput Green "✓ example-app removed"
    } else {
        Write-ColorOutput Yellow "⚠ example-app not found, skipping"
    }
    
    # 2. Переименование stacks
    Write-ColorOutput Blue "[2/7] Renaming stacks to example-stacks..."
    if (Test-Path "stacks") {
        Move-Item -Path "stacks" -Destination "example-stacks" -Force
        Write-ColorOutput Green "✓ stacks renamed to example-stacks"
        Write-ColorOutput Yellow "  Create your own stacks in the 'stacks/' directory"
        New-Item -ItemType Directory -Path "stacks" -Force | Out-Null
    } else {
        Write-ColorOutput Yellow "⚠ stacks directory not found"
    }
    
    # 3. SOPS Age Key
    Write-Output ""
    Write-ColorOutput Blue "[3/7] SOPS Age Key Setup"
    $generateSops = Ask-YesNo "Do you want to generate a new SOPS Age key?" "N"
    
    $privateKey = ""
    $publicKey = ""
    
    if ($generateSops) {
        if (-not (Get-Command age-keygen -ErrorAction SilentlyContinue)) {
            Write-ColorOutput Red "Error: age is not installed"
            Write-ColorOutput Yellow "Install age: choco install age"
            exit 1
        }
        
        New-Item -ItemType Directory -Path ".keys" -Force | Out-Null
        $keyOutput = age-keygen -o ".keys\age.key" 2>&1
        
        $publicKey = (Get-Content ".keys\age.key" | Select-String "# public key:").ToString().Split(":")[1].Trim()
        $privateKey = (Get-Content ".keys\age.key" | Select-String "AGE-SECRET-KEY").ToString().Trim()
        
        Write-ColorOutput Green "✓ SOPS Age key generated"
        Write-ColorOutput Cyan "Public key: $publicKey"
        Write-Output ""
        Write-ColorOutput Yellow "⚠ IMPORTANT: Save your private key securely!"
        Write-ColorOutput Yellow "Private key location: .keys\age.key"
        Write-Output ""
        
        # Обновление .sops.yaml
        if (Test-Path ".sops.yaml") {
            (Get-Content ".sops.yaml") -replace 'age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', $publicKey | Set-Content ".sops.yaml"
            Write-ColorOutput Green "✓ .sops.yaml updated with new public key"
        }
        
        # Добавление в .gitignore
        $gitignoreContent = Get-Content ".gitignore" -Raw
        if ($gitignoreContent -notmatch "\.keys/") {
            Add-Content ".gitignore" "`n# SOPS Age keys`n.keys/"
            Write-ColorOutput Green "✓ .keys/ added to .gitignore"
        }
    } else {
        Write-ColorOutput Yellow "⚠ Skipping SOPS key generation"
        Write-ColorOutput Yellow "  You'll need to provide your own Age key later"
    }
    
    # 4. SSH Keys
    Write-Output ""
    Write-ColorOutput Blue "[4/7] SSH Key Setup"
    $generateSsh = Ask-YesNo "Do you want to generate new SSH keys for deployment?" "N"
    
    if ($generateSsh) {
        # Выбор типа ключа
        Write-Output ""
        Write-Output "Select SSH key type:"
        Write-Output "  1) ed25519 (recommended, modern, fast)"
        Write-Output "  2) rsa 4096 (compatible with older systems)"
        $keyTypeChoice = Read-Host "Enter your choice [1-2] (default: 1)"
        if ([string]::IsNullOrEmpty($keyTypeChoice)) { $keyTypeChoice = "1" }
        
        New-Item -ItemType Directory -Path ".ssh-keys" -Force | Out-Null
        
        switch ($keyTypeChoice) {
            "1" {
                ssh-keygen -t ed25519 -C "deploy@gitops" -f ".ssh-keys\id_ed25519" -N `"`" 2>$null
                $sshKeyFile = "id_ed25519"
                Write-ColorOutput Green "✓ Generated ed25519 key"
            }
            "2" {
                ssh-keygen -t rsa -b 4096 -C "deploy@gitops" -f ".ssh-keys\id_rsa" -N `"`" 2>$null
                $sshKeyFile = "id_rsa"
                Write-ColorOutput Green "✓ Generated RSA 4096 key"
            }
            default {
                ssh-keygen -t ed25519 -C "deploy@gitops" -f ".ssh-keys\id_ed25519" -N `"`" 2>$null
                $sshKeyFile = "id_ed25519"
                Write-ColorOutput Green "✓ Generated ed25519 key (default)"
            }
        }
        
        Write-ColorOutput Green "✓ SSH key pair generated"
        Write-ColorOutput Cyan "Public key:"
        Get-Content ".ssh-keys\$sshKeyFile.pub"
        Write-Output ""
        Write-ColorOutput Yellow "⚠ IMPORTANT: Add this public key to your deployment server"
        Write-Output ""
        
        # Сохранение приватного ключа в data/data.yml
        Write-ColorOutput Blue "Saving private key to data/data.yml..."
        
        New-Item -ItemType Directory -Path "data" -Force | Out-Null
        
        $sshPrivateKey = Get-Content ".ssh-keys\$sshKeyFile" -Raw
        $sshPublicKey = Get-Content ".ssh-keys\$sshKeyFile.pub" -Raw
        $dataYmlContent = @"
# ИНСТРУКЦИЯ: Заполните данные сервера, затем зашифруйте:
# PowerShell: .\scripts\encrypt-ssh.ps1
# Bash: ./scripts/encrypt-ssh.sh

SSH_PRIVATE_KEY: |
$sshPrivateKey
SSH_PUBLIC_KEY: "$sshPublicKey"
SSH_HOST: "192.168.1.100"
SSH_USERNAME: "deploy"
SSH_PORT: "22"
"@
        
        $dataYmlContent | Out-File "data\data.yml" -Encoding UTF8 -NoNewline
        Write-ColorOutput Green "✓ Private key saved to data/data.yml"
        Write-Output ""
        Write-ColorOutput Cyan "Next steps:"
        Write-Output "  1. Edit data/data.yml and update SSH_HOST, SSH_USERNAME, SSH_PORT"
        Write-Output "  2. Add public key to your server (see above)"
        Write-Output "  3. Run: .\scripts\encrypt-ssh.ps1"
        Write-Output "  4. Delete data/ folder contents"
        Write-Output ""
        
        # Удаляем .ssh-keys после сохранения в data/
        Remove-Item ".ssh-keys" -Recurse -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✓ Temporary .ssh-keys/ removed"

    } else {
        Write-ColorOutput Yellow "⚠ Skipping SSH key generation"
        Write-ColorOutput Yellow "  You can generate SSH keys later with scripts\encrypt-ssh.ps1"
    }
    
    # 5. Удаление .git
    Write-Output ""
    Write-ColorOutput Blue "[5/7] Git Repository"
    if (Ask-YesNo "Do you want to remove .git directory (start fresh)?" "N") {
        Remove-Item -Path ".git" -Recurse -Force
        Write-ColorOutput Green "✓ .git directory removed"
        Write-ColorOutput Yellow "  Run 'git init' to initialize a new repository"
    } else {
        Write-ColorOutput Yellow "⚠ Keeping existing .git directory"
    }
    
    # 6. Обновление документации
    Write-Output ""
    Write-ColorOutput Blue "[6/7] Updating documentation..."
    if (Test-Path "README.md") {
        (Get-Content "README.md") -replace 'example-app', 'stacks' | Set-Content "README.md"
        Write-ColorOutput Green "✓ README.md updated"
    }
    
    # 7. Настройка GitHub Secrets
    Write-Output ""
    Write-ColorOutput Blue "[7/8] GitHub Secrets Setup"
    
    if ($generateSops) {
        # Создаем secrets.env с SOPS ключом
        $secretsContent = @"
# SOPS Age Private Key
SOPS_AGE_KEY=$privateKey
"@
        $secretsContent | Out-File "secrets.env" -Encoding UTF8 -Force
        Write-ColorOutput Green "✓ secrets.env created with your SOPS key"
        Write-ColorOutput Cyan "  Location: $(Get-Location)\secrets.env"
        
        # Автоматическая настройка через GitHub CLI
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            Write-Output ""
            if (Ask-YesNo "Do you want to set up GitHub secrets now (requires gh auth)?" "N") {
                # Проверка авторизации
                try {
                    gh auth status 2>$null | Out-Null
                    Write-ColorOutput Blue "Setting up GitHub secrets..."
                    $privateKey | gh secret set SOPS_AGE_KEY
                    Write-ColorOutput Green "✓ SOPS_AGE_KEY secret set in GitHub"
                } catch {
                    Write-ColorOutput Yellow "⚠ Not authenticated with GitHub CLI"
                    Write-ColorOutput Yellow "Run 'gh auth login' first, then '.\scripts\setup-github-secrets.ps1'"
                }
            } else {
                Write-ColorOutput Yellow "⚠ Run '.\scripts\setup-github-secrets.ps1' to configure GitHub later"
            }
        } else {
            Write-ColorOutput Yellow "⚠ Run '.\scripts\setup-github-secrets.ps1' to configure GitHub"
        }
    } else {
        Copy-Item "secrets.example.env" "secrets.env" -Force
        Write-ColorOutput Green "✓ secrets.env created from template"
        Write-ColorOutput Cyan "  Location: $(Get-Location)\secrets.env"
        Write-ColorOutput Yellow "⚠ Edit secrets.env and add your SOPS Age key"
    }
    
    # 8. Создание первого стека (бонус)
    Write-Output ""
    Write-ColorOutput Blue "[8/8] Create First Stack (Bonus)"
    if (Ask-YesNo "Do you want to create a sample stack from template?" "N") {
        $stackName = Read-Host "Enter stack name (e.g., myapp)"
        
        if (-not [string]::IsNullOrEmpty($stackName)) {
            New-Item -ItemType Directory -Force -Path "stacks\$stackName" | Out-Null
            
            # Создание docker-compose.yml
            @'
version: '3.8'

services:
  app:
    image: nginx:alpine
    networks:
      - traefik-public
    deploy:
      replicas: 2
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.app.rule=Host(`${APP_DOMAIN}`)"
        - "traefik.http.routers.app.entrypoints=websecure"
        - "traefik.http.routers.app.tls.certresolver=letsencrypt"
        - "traefik.http.services.app.loadbalancer.server.port=80"
      restart_policy:
        condition: on-failure

networks:
  traefik-public:
    external: true
'@ | Out-File "stacks\$stackName\docker-compose.yml" -Encoding UTF8
            
            # Создание .env для шифрования
            @"
APP_DOMAIN=myapp.example.com
"@ | Out-File "stacks\$stackName\.env" -Encoding UTF8
            
            # Шифрование если есть SOPS
            if ($generateSops -and (Get-Command sops -ErrorAction SilentlyContinue)) {
                $env:SOPS_AGE_KEY = $privateKey
                sops -e "stacks\$stackName\.env" | Out-File "stacks\$stackName\.env.encrypted" -Encoding UTF8
                Remove-Item "stacks\$stackName\.env"
                Write-ColorOutput Green "✓ Stack '$stackName' created and encrypted"
            } else {
                Rename-Item "stacks\$stackName\.env" ".env.example"
                Write-ColorOutput Green "✓ Stack '$stackName' created"
                Write-ColorOutput Yellow "⚠ Encrypt .env.example with: sops -e stacks\$stackName\.env.example > stacks\$stackName\.env.encrypted"
            }
            
            Write-ColorOutput Cyan "Edit your stack: stacks\$stackName\docker-compose.yml"
        }
    }
    
    Write-Output ""
    Write-ColorOutput Green "═══════════════════════════════════════════════════════════"
    Write-ColorOutput Green "      Server Repository Initialized Successfully"
    Write-ColorOutput Green "═══════════════════════════════════════════════════════════"
    Write-Output ""
    Write-ColorOutput Cyan "Next steps:"
    Write-Output "  1. Review and edit secrets.env"
    Write-Output "  2. Run: .\scripts\setup-github-secrets.ps1"
    if ($generateSsh) {
        Write-Output "  3. Add SSH public key to your deployment server"
        Write-Output "  4. Update .ssh.encrypted with your server details (sops .ssh.encrypted)"
    }
    Write-Output "  5. Create your stacks in the stacks/ directory"
    Write-Output "  6. Commit and push to GitHub"
    Write-Output ""
    if ($generateSops) {
        Write-ColorOutput Yellow "⚠ BACKUP YOUR KEYS:"
        Write-Output "  Private key: .keys\age.key"
        Write-Output "  Store it securely outside this repository!"
    }

} elseif ($repoType -eq "app") {
    Write-ColorOutput Yellow "=== App Repository Initialization ==="
    Write-Output ""
    
    if (-not (Test-Path "example-app")) {
        Write-ColorOutput Red "Error: example-app directory not found"
        exit 1
    }
    
    # 1. Запрос deployment repository
    Write-ColorOutput Blue "[1/6] Deployment Repository Setup"
    
    do {
        $deployRepo = Read-Host "Enter your deployment repository (format: username/repo-name)"
        
        if ([string]::IsNullOrWhiteSpace($deployRepo)) {
            Write-ColorOutput Red "Error: Deployment repository is required"
            continue
        }
        
        $valid = Validate-GitHubRepo $deployRepo
    } while (-not $valid)
    
    Write-ColorOutput Green "✓ Deployment repository: $deployRepo"
    
    # 2. Перемещение содержимого
    Write-Output ""
    Write-ColorOutput Blue "[2/6] Moving example-app contents to root..."
    
    $tempDir = ".temp-app"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Get-ChildItem "example-app" -Force | Move-Item -Destination $tempDir -Force
    
    Get-ChildItem -Force | Where-Object { $_.Name -notin @('example-app', $tempDir, '.', '..') } | Remove-Item -Recurse -Force
    
    Get-ChildItem $tempDir -Force | Move-Item -Destination . -Force
    Remove-Item $tempDir -Recurse -Force
    Remove-Item "example-app" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-ColorOutput Green "✓ App structure ready"
    
    # 3. Обновление workflow
    Write-Output ""
    Write-ColorOutput Blue "[3/6] Updating GitHub Actions workflow..."
    
    if (Test-Path ".github\workflows\build-and-deploy.yml") {
        $workflowContent = Get-Content ".github\workflows\build-and-deploy.yml" -Raw
        $workflowContent = $workflowContent -replace 'repository: \$\{\{ secrets\.DEPLOY_REPO \}\}', "repository: $deployRepo"
        $workflowContent | Set-Content ".github\workflows\build-and-deploy.yml"
        
        Write-ColorOutput Green "✓ Workflow updated with deployment repository"
    }
    
    # 4. Создание README
    Write-Output ""
    Write-ColorOutput Blue "[4/6] Creating application README..."
    
    @"
# Application Repository

Auto-deployed application with GitOps workflow.

## 🚀 Deployment Repository

This application deploys to: **$deployRepo**

## 📦 How it works

1. Make changes to ``src/index.html`` or other files
2. Commit and push to ``main``
3. GitHub Actions automatically:
   - Builds Docker image
   - Pushes to GitHub Container Registry
   - Creates PR in deployment repository
4. Merge PR → automatic deployment

## 🔧 Required GitHub Secrets

``````
GHCR_TOKEN          - GitHub Personal Access Token (write:packages)
DEPLOY_REPO_TOKEN   - GitHub Personal Access Token (repo)
``````

## 🛠 Setup

``````bash
# Set secrets
gh secret set GHCR_TOKEN
gh secret set DEPLOY_REPO_TOKEN

# Verify
gh secret list
``````

## 🐳 Local Development

``````bash
# Build
docker build -t myapp .

# Run
docker run -p 8080:80 myapp

# Open http://localhost:8080
``````

## 📝 Version Format

Images are tagged with: ``timestamp-githash``

Example: ``20251126-143022-a3f5c7b``
"@ | Out-File "README.md" -Encoding UTF8
    
    Write-ColorOutput Green "✓ README.md created"
    
    # 5. Настройка GitHub Secrets
    Write-Output ""
    Write-ColorOutput Blue "[5/6] GitHub Secrets Setup"
    
    if ((Get-Command gh -ErrorAction SilentlyContinue) -and (gh auth status 2>$null)) {
        if (Ask-YesNo "Do you want to set up GitHub secrets now?" "N") {
            Write-ColorOutput Blue "Setting up secrets..."
            
            Write-ColorOutput Yellow "You need a GitHub Personal Access Token with 'repo' and 'write:packages' scopes"
            $ghcrToken = Read-Host "Enter GHCR_TOKEN (Personal Access Token)" -AsSecureString
            $deployToken = Read-Host "Enter DEPLOY_REPO_TOKEN (can be the same)" -AsSecureString
            
            $ghcrTokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghcrToken))
            $deployTokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($deployToken))
            
            $ghcrTokenPlain | gh secret set GHCR_TOKEN
            $deployTokenPlain | gh secret set DEPLOY_REPO_TOKEN
            
            Write-ColorOutput Green "✓ GitHub secrets configured"
        } else {
            Write-ColorOutput Yellow "⚠ Remember to set secrets manually:"
            Write-Output "  gh secret set GHCR_TOKEN"
            Write-Output "  gh secret set DEPLOY_REPO_TOKEN"
        }
    } else {
        Write-ColorOutput Yellow "⚠ GitHub CLI not available or not authenticated"
        Write-ColorOutput Yellow "Set secrets manually after pushing to GitHub"
    }
    
    # 6. Удаление .git
    Write-Output ""
    Write-ColorOutput Blue "[6/6] Git Repository"
    if (Ask-YesNo "Do you want to remove .git directory (start fresh)?" "N") {
        Remove-Item -Path ".git" -Recurse -Force
        Write-ColorOutput Green "✓ .git directory removed"
        Write-ColorOutput Yellow "  Run 'git init' to initialize a new repository"
    } else {
        Write-ColorOutput Yellow "⚠ Keeping existing .git directory"
    }
    
    Write-Output ""
    Write-ColorOutput Green "═══════════════════════════════════════════════════════════"
    Write-ColorOutput Green "       App Repository Initialized Successfully"
    Write-ColorOutput Green "═══════════════════════════════════════════════════════════"
    Write-Output ""
    Write-ColorOutput Cyan "Next steps:"
    Write-Output "  1. Set GitHub secrets:"
    Write-Output "     gh secret set GHCR_TOKEN"
    Write-Output "     gh secret set DEPLOY_REPO_TOKEN"
    Write-Output "  2. Initialize git repository:"
    Write-Output "     git init"
    Write-Output "     git add ."
    Write-Output "     git commit -m 'Initial commit'"
    Write-Output "  3. Push to GitHub and start developing!"
    Write-Output ""
    Write-ColorOutput Cyan "Deployment target: " -NoNewline
    Write-ColorOutput Yellow $deployRepo
    
    # Очистка после инициализации
    Write-Output ""
    Write-ColorOutput Blue "Cleaning up initialization files..."
    
    # Удаление тестов
    if (Test-Path "tests") {
        Remove-Item "tests" -Recurse -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✓ Removed tests/ directory"
    }
    
    # Удаление скриптов запуска тестов
    if (Test-Path "run-tests.ps1") {
        Remove-Item "run-tests.ps1" -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✓ Removed run-tests.ps1"
    }
    
    if (Test-Path "run-tests.sh") {
        Remove-Item "run-tests.sh" -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✓ Removed run-tests.sh"
    }
    
    # Удаление workflow тестирования
    if (Test-Path ".github\workflows\test-init.yml") {
        Remove-Item ".github\workflows\test-init.yml" -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✓ Removed .github/workflows/test-init.yml"
    }
    
    # Удаление init скриптов
    if (Test-Path "init.sh") {
        Remove-Item "init.sh" -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✓ Removed init.sh"
    }
    
    Write-ColorOutput Yellow "⚠ This script (init.ps1) will be deleted after you close this window"
    Write-Output ""
}

Write-Output ""
Write-ColorOutput Blue "Initialization complete! 🎉"

# Самоудаление init.ps1 в конце
$selfScript = $MyInvocation.MyCommand.Path
if ($selfScript) {
    Write-ColorOutput Yellow "Cleaning up init.ps1..."
    Start-Sleep -Seconds 2
    Remove-Item $selfScript -Force -ErrorAction SilentlyContinue
    Write-ColorOutput Green "✓ init.ps1 removed"
}
