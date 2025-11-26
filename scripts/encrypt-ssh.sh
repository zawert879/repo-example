#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Encrypt SSH Keys ===${NC}"
echo ""

# Проверка наличия data/data.yml
if [ ! -f "data/data.yml" ]; then
    echo -e "${RED}Error: data/data.yml not found${NC}"
    echo "Please create and fill data/data.yml first"
    echo "See data/README.md for instructions"
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
    elif [ -f "secrets.env" ]; then
        export SOPS_AGE_KEY=$(grep "SOPS_AGE_KEY=" secrets.env | cut -d'=' -f2 | xargs)
        if [ -n "$SOPS_AGE_KEY" ]; then
            echo -e "${GREEN}✓ Using Age key from secrets.env${NC}"
        fi
    fi
    
    if [ -z "$SOPS_AGE_KEY" ]; then
        echo -e "${RED}Error: SOPS_AGE_KEY not set${NC}"
        echo "Set it with: export SOPS_AGE_KEY='your-key'"
        echo "Or place it in .keys/age.key or secrets.env"
        exit 1
    fi
fi

echo -e "${BLUE}Reading data from data/data.yml...${NC}"

# Проверка содержимого data.yml
if grep -q "\[Вставьте содержимое" data/data.yml; then
    echo -e "${RED}Error: data/data.yml contains placeholder text${NC}"
    echo "Please fill in actual SSH data before encrypting"
    echo "See data/README.md for instructions"
    exit 1
fi

echo ""
echo -e "${BLUE}Encrypting data/data.yml to .ssh.encrypted.yml...${NC}"

# Шифруем data.yml напрямую
if sops -e data/data.yml > .ssh.encrypted.yml; then
    echo -e "${GREEN}✓ SSH configuration encrypted successfully${NC}"
else
    echo -e "${RED}Error: Failed to encrypt data.yml${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   SSH Keys Encrypted Successfully    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Review encrypted file: sops .ssh.encrypted.yml"
echo "  2. Commit .ssh.encrypted.yml to git"
echo "  3. Clean up data directory: rm -rf data/*"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT: Delete data/ contents after verification!${NC}"
echo "  rm -rf data/*"
echo ""
echo -e "${CYAN}To decrypt and view:${NC}"
echo "  sops .ssh.encrypted.yml"
