#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Encrypt SSH Keys ===${NC}"
echo ""

# Проверка наличия незашифрованных ключей
if [ ! -d ".ssh-keys" ]; then
    echo -e "${RED}Error: .ssh-keys directory not found${NC}"
    echo "Nothing to encrypt"
    exit 1
fi

# Проверка SOPS
if ! command -v sops &> /dev/null; then
    echo -e "${RED}Error: sops is not installed${NC}"
    exit 1
fi

# Проверка Age ключа
if [ -z "$SOPS_AGE_KEY" ]; then
    if [ -f ".keys/age.key" ]; then
        export SOPS_AGE_KEY=$(cat .keys/age.key | grep "AGE-SECRET-KEY" | xargs)
        echo -e "${GREEN}✓ Using Age key from .keys/age.key${NC}"
    else
        echo -e "${RED}Error: SOPS_AGE_KEY not set${NC}"
        echo "Set it with: export SOPS_AGE_KEY='your-key'"
        echo "Or place it in .keys/age.key"
        exit 1
    fi
fi

# Проверка наличия ключей
if [ ! -f ".ssh-keys/id_ed25519" ]; then
    echo -e "${RED}Error: SSH private key not found in .ssh-keys/${NC}"
    exit 1
fi

echo -e "${BLUE}Reading SSH keys...${NC}"

# Запрос дополнительной информации
read -p "SSH Host (IP or domain): " SSH_HOST
read -p "SSH Username: " SSH_USERNAME
read -p "SSH Port [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

echo ""
echo -e "${BLUE}Creating encrypted SSH configuration...${NC}"

# Создаем временный файл
cat > .ssh-temp << EOF
SSH_PRIVATE_KEY="$(cat .ssh-keys/id_ed25519)"
SSH_HOST="$SSH_HOST"
SSH_USERNAME="$SSH_USERNAME"
SSH_PORT="$SSH_PORT"
EOF

# Шифруем
sops -e .ssh-temp > .ssh.encrypted

# Удаляем временный файл
rm -f .ssh-temp

echo -e "${GREEN}✓ SSH configuration encrypted${NC}"
echo ""

# Удаляем незашифрованные ключи
echo -e "${YELLOW}Removing unencrypted SSH keys...${NC}"
read -p "Are you sure you want to delete .ssh-keys/ directory? [y/N]: " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    rm -rf .ssh-keys
    echo -e "${GREEN}✓ Unencrypted keys removed${NC}"
    
    # Удаляем из .gitignore если там есть
    if [ -f ".gitignore" ]; then
        sed -i.bak '/\.ssh-keys\//d' .gitignore
        rm -f .gitignore.bak
    fi
else
    echo -e "${YELLOW}⚠ Unencrypted keys kept in .ssh-keys/${NC}"
    echo -e "${YELLOW}  Remember to delete them manually and remove from .gitignore${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   SSH Keys Encrypted Successfully    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Review encrypted file: sops .ssh.encrypted"
echo "  2. Commit .ssh.encrypted to git"
echo "  3. Add SSH public key to your server"
echo ""
echo -e "${YELLOW}Public key (add this to your server):${NC}"
if [ -f ".ssh-keys/id_ed25519.pub" ]; then
    cat .ssh-keys/id_ed25519.pub
else
    echo "(Public key was already removed)"
fi
