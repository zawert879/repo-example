#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Repository Initialization Script                ║"
echo "║         GitOps Infrastructure Setup Tool                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка что мы в правильной директории
if [ ! -f ".gitignore" ] || [ ! -d ".github" ]; then
    echo -e "${RED}Error: This script must be run from the root of the repository${NC}"
    exit 1
fi

# Функция для вопросов yes/no
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        prompt="${prompt} [Y/n]: "
    else
        prompt="${prompt} [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" answer
        answer=${answer:-$default}
        case $answer in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Функция проверки и установки зависимостей
check_and_install_deps() {
    local missing_deps=()
    
    # Проверка age
    if ! command -v age-keygen &> /dev/null; then
        missing_deps+=("age")
    fi
    
    # Проверка sops
    if ! command -v sops &> /dev/null; then
        missing_deps+=("sops")
    fi
    
    # Проверка gh (GitHub CLI)
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All dependencies are installed${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Missing dependencies: ${missing_deps[*]}${NC}"
    echo ""
    
    if ask_yes_no "Do you want to install missing dependencies automatically?" "y"; then
        # Определение пакетного менеджера
        if command -v brew &> /dev/null; then
            echo -e "${BLUE}Installing via Homebrew...${NC}"
            for dep in "${missing_deps[@]}"; do
                brew install "$dep" || echo -e "${YELLOW}⚠ Failed to install $dep${NC}"
            done
        elif command -v apt-get &> /dev/null; then
            echo -e "${BLUE}Installing via apt-get...${NC}"
            sudo apt-get update
            for dep in "${missing_deps[@]}"; do
                if [ "$dep" = "gh" ]; then
                    # GitHub CLI установка для Ubuntu
                    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                    sudo apt-get update
                    sudo apt-get install -y gh
                elif [ "$dep" = "sops" ]; then
                    wget -q https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
                    sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
                    sudo chmod +x /usr/local/bin/sops
                else
                    sudo apt-get install -y "$dep" || echo -e "${YELLOW}⚠ Failed to install $dep${NC}"
                fi
            done
        else
            echo -e "${YELLOW}⚠ Automatic installation not supported for your system${NC}"
            echo -e "${YELLOW}Please install manually:${NC}"
            for dep in "${missing_deps[@]}"; do
                echo "  - $dep"
            done
            return 1
        fi
        
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo -e "${YELLOW}⚠ Please install dependencies manually${NC}"
        return 1
    fi
}

# Функция валидации GitHub репозитория
validate_github_repo() {
    local repo="$1"
    
    if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        echo -e "${RED}Invalid repository format. Expected: username/repo-name${NC}"
        return 1
    fi
    
    # Проверка через GitHub CLI если доступен
    if command -v gh &> /dev/null; then
        if gh repo view "$repo" &> /dev/null; then
            echo -e "${GREEN}✓ Repository validated: $repo${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Repository not found or not accessible: $repo${NC}"
            if ask_yes_no "Continue anyway?"; then
                return 0
            else
                return 1
            fi
        fi
    fi
    
    return 0
}

# Выбор типа репозитория
echo -e "${BLUE}Select repository type:${NC}"
echo "  1) Server (Infrastructure/Deployment repository)"
echo "  2) App (Application repository with CI/CD)"
echo ""
read -p "Enter your choice [1-2]: " REPO_TYPE

case $REPO_TYPE in
    1)
        REPO_TYPE="server"
        echo -e "${GREEN}✓ Selected: Server repository${NC}"
        ;;
    2)
        REPO_TYPE="app"
        echo -e "${GREEN}✓ Selected: App repository${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

echo ""

# Проверка и установка зависимостей
echo -e "${BLUE}Checking dependencies...${NC}"
check_and_install_deps
echo ""

if [ "$REPO_TYPE" = "server" ]; then
    echo -e "${YELLOW}=== Server Repository Initialization ===${NC}"
    echo ""
    
    # 1. Удаление example-app
    echo -e "${BLUE}[1/7] Removing example-app directory...${NC}"
    if [ -d "example-app" ]; then
        rm -rf example-app
        echo -e "${GREEN}✓ example-app removed${NC}"
    else
        echo -e "${YELLOW}⚠ example-app not found, skipping${NC}"
    fi
    
    # 2. Переименование stacks в example-stacks
    echo -e "${BLUE}[2/7] Renaming stacks to example-stacks...${NC}"
    if [ -d "stacks" ]; then
        mv stacks example-stacks
        echo -e "${GREEN}✓ stacks renamed to example-stacks${NC}"
        echo -e "${YELLOW}  Create your own stacks in the 'stacks/' directory${NC}"
        mkdir -p stacks
    else
        echo -e "${YELLOW}⚠ stacks directory not found${NC}"
    fi
    
    # 3. SOPS Age Key
    echo ""
    echo -e "${BLUE}[3/7] SOPS Age Key Setup${NC}"
    GENERATE_SOPS=false
    if ask_yes_no "Do you want to generate a new SOPS Age key?"; then
        GENERATE_SOPS=true
        
        # Проверка установки age
        if ! command -v age-keygen &> /dev/null; then
            echo -e "${RED}Error: age is not installed${NC}"
            echo -e "${YELLOW}Install age:${NC}"
            echo "  - macOS: brew install age"
            echo "  - Ubuntu: apt-get install age"
            echo "  - Windows: choco install age"
            exit 1
        fi
        
        # Генерация ключа
        mkdir -p .keys
        age-keygen -o .keys/age.key 2>/dev/null
        
        PUBLIC_KEY=$(cat .keys/age.key | grep "# public key:" | cut -d: -f2 | xargs)
        PRIVATE_KEY=$(cat .keys/age.key | grep "AGE-SECRET-KEY" | xargs)
        
        echo -e "${GREEN}✓ SOPS Age key generated${NC}"
        echo -e "${CYAN}Public key: ${PUBLIC_KEY}${NC}"
        echo ""
        echo -e "${YELLOW}⚠ IMPORTANT: Save your private key securely!${NC}"
        echo -e "${YELLOW}Private key location: .keys/age.key${NC}"
        echo ""
        
        # Обновление .sops.yaml
        if [ -f ".sops.yaml" ]; then
            sed -i.bak "s/age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/$PUBLIC_KEY/g" .sops.yaml
            rm -f .sops.yaml.bak
            echo -e "${GREEN}✓ .sops.yaml updated with new public key${NC}"
        fi
        
        # Добавление в .gitignore
        if ! grep -q ".keys/" .gitignore; then
            echo -e "\n# SOPS Age keys\n.keys/" >> .gitignore
            echo -e "${GREEN}✓ .keys/ added to .gitignore${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping SOPS key generation${NC}"
        echo -e "${YELLOW}  You'll need to provide your own Age key later${NC}"
    fi
    
    # 4. SSH Keys
    echo ""
    echo -e "${BLUE}[4/7] SSH Key Setup${NC}"
    GENERATE_SSH=false
    if ask_yes_no "Do you want to generate new SSH keys for deployment?"; then
        GENERATE_SSH=true
        
        # Выбор типа ключа
        echo ""
        echo "Select SSH key type:"
        echo "  1) ed25519 (recommended, modern, fast)"
        echo "  2) rsa 4096 (compatible with older systems)"
        read -p "Enter your choice [1-2] (default: 1): " key_type_choice
        key_type_choice=${key_type_choice:-1}
        
        mkdir -p .ssh-keys
        
        case $key_type_choice in
            1)
                ssh-keygen -t ed25519 -C "deploy@gitops" -f .ssh-keys/id_ed25519 -N "" -q
                SSH_KEY_FILE="id_ed25519"
                echo -e "${GREEN}✓ Generated ed25519 key${NC}"
                ;;
            2)
                ssh-keygen -t rsa -b 4096 -C "deploy@gitops" -f .ssh-keys/id_rsa -N "" -q
                SSH_KEY_FILE="id_rsa"
                echo -e "${GREEN}✓ Generated RSA 4096 key${NC}"
                ;;
            *)
                ssh-keygen -t ed25519 -C "deploy@gitops" -f .ssh-keys/id_ed25519 -N "" -q
                SSH_KEY_FILE="id_ed25519"
                echo -e "${GREEN}✓ Generated ed25519 key (default)${NC}"
                ;;
        esac
        
        echo -e "${GREEN}✓ SSH key pair generated${NC}"
        echo -e "${CYAN}Public key:${NC}"
        cat ".ssh-keys/$SSH_KEY_FILE.pub"
        echo ""
        echo -e "${YELLOW}⚠ IMPORTANT: Add this public key to your deployment server${NC}"
        echo ""
        
        # Сохранение приватного ключа в data/data.yml
        echo -e "${BLUE}Saving private key to data/data.yml...${NC}"
        
        mkdir -p data
        
        cat > data/data.yml << EOF
# ИНСТРУКЦИЯ: Заполните данные сервера, затем зашифруйте:
# PowerShell: .\\scripts\\encrypt-ssh.ps1
# Bash: ./scripts/encrypt-ssh.sh

SSH_PRIVATE_KEY: |
$(cat .ssh-keys/$SSH_KEY_FILE | sed 's/^/  /')
SSH_PUBLIC_KEY: "$(cat .ssh-keys/$SSH_KEY_FILE.pub)"
SSH_HOST: "192.168.1.100"
SSH_USERNAME: "deploy"
SSH_PORT: "22"
EOF
        
        echo -e "${GREEN}✓ Private key saved to data/data.yml${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "  1. Edit data/data.yml and update SSH_HOST, SSH_USERNAME, SSH_PORT"
        echo "  2. Add public key to your server (see above)"
        echo "  3. Run: ./scripts/encrypt-ssh.sh"
        echo "  4. Delete data/ folder contents"
        echo ""
        
        # Удаляем .ssh-keys после сохранения в data/
        rm -rf .ssh-keys
        echo -e "${GREEN}✓ Temporary .ssh-keys/ removed${NC}"

    else
        echo -e "${YELLOW}⚠ Skipping SSH key generation${NC}"
    fi
    
    # 5. Удаление .git
    echo ""
    echo -e "${BLUE}[5/7] Git Repository${NC}"
    if ask_yes_no "Do you want to remove .git directory (start fresh)?"; then
        rm -rf .git
        echo -e "${GREEN}✓ .git directory removed${NC}"
        echo -e "${YELLOW}  Run 'git init' to initialize a new repository${NC}"
    else
        echo -e "${YELLOW}⚠ Keeping existing .git directory${NC}"
    fi
    
    # 6. Обновление документации
    echo ""
    echo -e "${BLUE}[6/7] Updating documentation...${NC}"
    if [ -f "README.md" ]; then
        sed -i.bak 's/example-app/stacks/g' README.md
        rm -f README.md.bak
        echo -e "${GREEN}✓ README.md updated${NC}"
    fi
    
    # 7. Настройка GitHub Secrets
    echo ""
    echo -e "${BLUE}[7/7] GitHub Secrets Setup${NC}"
    
    if [ "$GENERATE_SOPS" = true ]; then
        cat > secrets.env << EOF
# SOPS Age Private Key
SOPS_AGE_KEY=$PRIVATE_KEY
EOF
        echo -e "${GREEN}✓ secrets.env created with your SOPS key${NC}"
        echo -e "${CYAN}  Location: $(pwd)/secrets.env${NC}"
        
        # Автоматическая настройка через GitHub CLI
        if command -v gh &> /dev/null; then
            echo ""
            if ask_yes_no "Do you want to set up GitHub secrets now (requires gh auth)?"; then
                # Проверка авторизации
                if gh auth status &> /dev/null; then
                    echo -e "${BLUE}Setting up GitHub secrets...${NC}"
                    echo "$PRIVATE_KEY" | gh secret set SOPS_AGE_KEY
                    echo -e "${GREEN}✓ SOPS_AGE_KEY secret set in GitHub${NC}"
                else
                    echo -e "${YELLOW}⚠ Not authenticated with GitHub CLI${NC}"
                    echo -e "${YELLOW}Run 'gh auth login' first, then './scripts/setup-github-secrets.sh'${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ Run './scripts/setup-github-secrets.sh' to configure GitHub later${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Run './scripts/setup-github-secrets.sh' to configure GitHub${NC}"
        fi
    else
        cp secrets.example.env secrets.env
        echo -e "${GREEN}✓ secrets.env created from template${NC}"
        echo -e "${CYAN}  Location: $(pwd)/secrets.env${NC}"
        echo -e "${YELLOW}⚠ Edit secrets.env and add your SOPS Age key${NC}"
    fi
    
    # 8. Создание первого стека (бонус)
    echo ""
    echo -e "${BLUE}[Bonus] Create First Stack${NC}"
    if ask_yes_no "Do you want to create a sample stack from template?"; then
        read -p "Enter stack name (e.g., myapp): " STACK_NAME
        
        if [ -n "$STACK_NAME" ]; then
            mkdir -p "stacks/$STACK_NAME"
            
            # Создание docker-compose.yml
            cat > "stacks/$STACK_NAME/docker-compose.yml" << 'EOFSTACK'
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
EOFSTACK
            
            # Создание .env для шифрования
            cat > "stacks/$STACK_NAME/.env" << EOFENV
APP_DOMAIN=myapp.example.com
EOFENV
            
            # Шифрование если есть SOPS
            if [ "$GENERATE_SOPS" = true ] && command -v sops &> /dev/null; then
                export SOPS_AGE_KEY="$PRIVATE_KEY"
                sops -e "stacks/$STACK_NAME/.env" > "stacks/$STACK_NAME/.env.encrypted"
                rm "stacks/$STACK_NAME/.env"
                echo -e "${GREEN}✓ Stack '$STACK_NAME' created and encrypted${NC}"
            else
                mv "stacks/$STACK_NAME/.env" "stacks/$STACK_NAME/.env.example"
                echo -e "${GREEN}✓ Stack '$STACK_NAME' created${NC}"
                echo -e "${YELLOW}⚠ Encrypt .env.example with: sops -e stacks/$STACK_NAME/.env.example > stacks/$STACK_NAME/.env.encrypted${NC}"
            fi
            
            echo -e "${CYAN}Edit your stack: stacks/$STACK_NAME/docker-compose.yml${NC}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Server Repository Initialized Successfully       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Review and edit secrets.env"
    echo "  2. Run: ./scripts/setup-github-secrets.sh"
    if [ "$GENERATE_SSH" = true ]; then
        echo "  3. Add SSH public key to your deployment server"
        echo "  4. Update .ssh.encrypted with your server details (sops .ssh.encrypted)"
    fi
    echo "  5. Create your stacks in the stacks/ directory"
    echo "  6. Commit and push to GitHub"
    echo ""
    if [ "$GENERATE_SOPS" = true ]; then
        echo -e "${YELLOW}⚠ BACKUP YOUR KEYS:${NC}"
        echo "  Private key: .keys/age.key"
        echo "  Store it securely outside this repository!"
    fi

elif [ "$REPO_TYPE" = "app" ]; then
    echo -e "${YELLOW}=== App Repository Initialization ===${NC}"
    echo ""
    
    # Проверка наличия example-app
    if [ ! -d "example-app" ]; then
        echo -e "${RED}Error: example-app directory not found${NC}"
        exit 1
    fi
    
    # 1. Запрос deployment repository
    echo -e "${BLUE}[1/6] Deployment Repository Setup${NC}"
    
    while true; do
        read -p "Enter your deployment repository (format: username/repo-name): " DEPLOY_REPO
        
        if [ -z "$DEPLOY_REPO" ]; then
            echo -e "${RED}Error: Deployment repository is required${NC}"
            continue
        fi
        
        if validate_github_repo "$DEPLOY_REPO"; then
            break
        fi
    done
    
    echo -e "${GREEN}✓ Deployment repository: $DEPLOY_REPO${NC}"
    
    # 2. Перемещение содержимого example-app в корень
    echo ""
    echo -e "${BLUE}[2/6] Moving example-app contents to root...${NC}"
    
    # Создаем временную директорию
    mkdir -p .temp-app
    mv example-app/* .temp-app/
    mv example-app/.* .temp-app/ 2>/dev/null || true
    
    # Удаляем все кроме example-app
    find . -maxdepth 1 ! -name 'example-app' ! -name '.temp-app' ! -name '.' ! -name '..' -exec rm -rf {} +
    
    # Перемещаем обратно
    mv .temp-app/* .
    mv .temp-app/.* . 2>/dev/null || true
    rm -rf .temp-app example-app
    
    echo -e "${GREEN}✓ App structure ready${NC}"
    
    # 3. Обновление workflow
    echo ""
    echo -e "${BLUE}[3/6] Updating GitHub Actions workflow...${NC}"
    
    if [ -f ".github/workflows/build-and-deploy.yml" ]; then
        # Удаляем секцию checkout deployment repo
        sed -i.bak '/Checkout deployment repository/,/ref: main/d' .github/workflows/build-and-deploy.yml
        
        # Обновляем на использование secrets
        sed -i.bak "s/repository: \${{ secrets.DEPLOY_REPO }}/repository: $DEPLOY_REPO/g" .github/workflows/build-and-deploy.yml
        
        # Добавляем переменную DEPLOY_REPO если её нет
        if ! grep -q "DEPLOY_REPO:" .github/workflows/build-and-deploy.yml; then
            sed -i.bak "s/env:/env:\n  DEPLOY_REPO: $DEPLOY_REPO/g" .github/workflows/build-and-deploy.yml
        fi
        
        rm -f .github/workflows/build-and-deploy.yml.bak
        echo -e "${GREEN}✓ Workflow updated with deployment repository${NC}"
    fi
    
    # 4. Создание README для app
    echo ""
    echo -e "${BLUE}[4/6] Creating application README...${NC}"
    
    cat > README.md << EOF
# Application Repository

Auto-deployed application with GitOps workflow.

## 🚀 Deployment Repository

This application deploys to: **$DEPLOY_REPO**

## 📦 How it works

1. Make changes to \`src/index.html\` or other files
2. Commit and push to \`main\`
3. GitHub Actions automatically:
   - Builds Docker image
   - Pushes to GitHub Container Registry
   - Creates PR in deployment repository
4. Merge PR → automatic deployment

## 🔧 Required GitHub Secrets

\`\`\`
GHCR_TOKEN          - GitHub Personal Access Token (write:packages)
DEPLOY_REPO_TOKEN   - GitHub Personal Access Token (repo)
\`\`\`

## 🛠 Setup

\`\`\`bash
# Set secrets
gh secret set GHCR_TOKEN
gh secret set DEPLOY_REPO_TOKEN

# Verify
gh secret list
\`\`\`

## 🐳 Local Development

\`\`\`bash
# Build
docker build -t myapp .

# Run
docker run -p 8080:80 myapp

# Open http://localhost:8080
\`\`\`

## 📝 Version Format

Images are tagged with: \`timestamp-githash\`

Example: \`20251126-143022-a3f5c7b\`
EOF
    
    echo -e "${GREEN}✓ README.md created${NC}"
    
    # 5. Настройка GitHub Secrets
    echo ""
    echo -e "${BLUE}[5/6] GitHub Secrets Setup${NC}"
    
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        if ask_yes_no "Do you want to set up GitHub secrets now?"; then
            echo -e "${BLUE}Setting up secrets...${NC}"
            
            echo -e "${YELLOW}You need a GitHub Personal Access Token with 'repo' and 'write:packages' scopes${NC}"
            read -s -p "Enter GHCR_TOKEN (Personal Access Token): " GHCR_TOKEN
            echo ""
            read -s -p "Enter DEPLOY_REPO_TOKEN (can be the same): " DEPLOY_TOKEN
            echo ""
            
            echo "$GHCR_TOKEN" | gh secret set GHCR_TOKEN
            echo "$DEPLOY_TOKEN" | gh secret set DEPLOY_REPO_TOKEN
            
            echo -e "${GREEN}✓ GitHub secrets configured${NC}"
        else
            echo -e "${YELLOW}⚠ Remember to set secrets manually:${NC}"
            echo "  gh secret set GHCR_TOKEN"
            echo "  gh secret set DEPLOY_REPO_TOKEN"
        fi
    else
        echo -e "${YELLOW}⚠ GitHub CLI not available or not authenticated${NC}"
        echo -e "${YELLOW}Set secrets manually after pushing to GitHub${NC}"
    fi
    
    # 6. Удаление .git
    echo ""
    echo -e "${BLUE}[6/6] Git Repository${NC}"
    if ask_yes_no "Do you want to remove .git directory (start fresh)?"; then
        rm -rf .git
        echo -e "${GREEN}✓ .git directory removed${NC}"
        echo -e "${YELLOW}  Run 'git init' to initialize a new repository${NC}"
    else
        echo -e "${YELLOW}⚠ Keeping existing .git directory${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          App Repository Initialized Successfully          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Set GitHub secrets:"
    echo "     gh secret set GHCR_TOKEN"
    echo "     gh secret set DEPLOY_REPO_TOKEN"
    echo "  2. Initialize git repository:"
    echo "     git init"
    echo "     git add ."
    echo "     git commit -m 'Initial commit'"
    echo "  3. Push to GitHub and start developing!"
    echo ""
    echo -e "${CYAN}Deployment target: ${YELLOW}$DEPLOY_REPO${NC}"
    
    # Очистка после инициализации
    echo ""
    echo -e "${BLUE}Cleaning up initialization files...${NC}"
    
    # Удаление тестов
    if [ -d "tests" ]; then
        rm -rf tests
        echo -e "${GREEN}✓ Removed tests/ directory${NC}"
    fi
    
    # Удаление скриптов запуска тестов
    if [ -f "run-tests.ps1" ]; then
        rm -f run-tests.ps1
        echo -e "${GREEN}✓ Removed run-tests.ps1${NC}"
    fi
    
    if [ -f "run-tests.sh" ]; then
        rm -f run-tests.sh
        echo -e "${GREEN}✓ Removed run-tests.sh${NC}"
    fi
    
    # Удаление workflow тестирования
    if [ -f ".github/workflows/test-init.yml" ]; then
        rm -f .github/workflows/test-init.yml
        echo -e "${GREEN}✓ Removed .github/workflows/test-init.yml${NC}"
    fi
    
    # Удаление init.ps1
    if [ -f "init.ps1" ]; then
        rm -f init.ps1
        echo -e "${GREEN}✓ Removed init.ps1${NC}"
    fi
    
    echo -e "${YELLOW}⚠ This script (init.sh) will be deleted in 2 seconds...${NC}"
fi

echo ""
echo -e "${BLUE}Initialization complete! 🎉${NC}"

# Самоудаление init.sh в конце
SELF_SCRIPT="$0"
if [ -f "$SELF_SCRIPT" ]; then
    echo -e "${YELLOW}Cleaning up init.sh...${NC}"
    sleep 2
    rm -f "$SELF_SCRIPT"
    echo -e "${GREEN}✓ init.sh removed${NC}"
fi
