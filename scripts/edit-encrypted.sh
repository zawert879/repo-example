#!/bin/bash

# Bash script to edit encrypted files

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} Edit Encrypted Files with SOPS${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Проверка наличия SOPS
if ! command -v sops &> /dev/null; then
    echo -e "${RED}Error: SOPS is not installed${NC}"
    echo "Install it from: https://github.com/mozilla/sops/releases"
    exit 1
fi

# Установка переменной окружения для Age ключа
AGE_KEY_FILE="./.keys/age.key"
if [ ! -f "$AGE_KEY_FILE" ]; then
    echo -e "${RED}Error: Age key file not found: $AGE_KEY_FILE${NC}"
    echo "Run init.sh first to generate the key"
    exit 1
fi

export SOPS_AGE_KEY_FILE="$(realpath "$AGE_KEY_FILE")"
echo -e "${GREEN}✓ Using Age key: $SOPS_AGE_KEY_FILE${NC}"
echo ""

# Поиск зашифрованных файлов
echo -e "${BLUE}Searching for encrypted files...${NC}"
encrypted_files=()

# Поиск в stacks/
if [ -d "stacks" ]; then
    while IFS= read -r file; do
        encrypted_files+=("$file")
    done < <(find stacks -type f -name "*.encrypted.*")
fi

# Поиск .ssh.encrypted
if [ -f ".ssh.encrypted" ]; then
    encrypted_files+=(".ssh.encrypted")
fi

# Поиск .env.encrypted
if [ -f ".env.encrypted" ]; then
    encrypted_files+=(".env.encrypted")
fi

# Поиск secrets.encrypted.*
while IFS= read -r file; do
    encrypted_files+=("$file")
done < <(find . -maxdepth 1 -type f -name "secrets.encrypted.*")

if [ ${#encrypted_files[@]} -eq 0 ]; then
    echo -e "${YELLOW}No encrypted files found${NC}"
    echo "Searched in:"
    echo "  - stacks/"
    echo "  - .ssh.encrypted"
    echo "  - .env.encrypted"
    echo "  - secrets.encrypted.*"
    exit 0
fi

echo -e "${GREEN}✓ Found ${#encrypted_files[@]} encrypted file(s)${NC}"
echo ""

# Показываем список файлов
echo "Select a file to edit:"
for i in "${!encrypted_files[@]}"; do
    echo "  [$((i + 1))] ${encrypted_files[$i]}"
done
echo ""

# Выбор файла
read -p "Enter file number [1-${#encrypted_files[@]}]: " selection
selected_index=$((selection - 1))

if [ $selected_index -lt 0 ] || [ $selected_index -ge ${#encrypted_files[@]} ]; then
    echo -e "${RED}Invalid selection${NC}"
    exit 1
fi

selected_file="${encrypted_files[$selected_index]}"
echo ""
echo -e "${BLUE}Opening: $selected_file${NC}"
echo -e "${YELLOW}⚠ File will be decrypted, opened in editor, and re-encrypted on save${NC}"
echo ""

# Редактирование с помощью SOPS
if sops "$selected_file"; then
    echo -e "${GREEN}✓ File edited and re-encrypted successfully${NC}"
else
    echo -e "${RED}Error editing file${NC}"
    exit 1
fi
