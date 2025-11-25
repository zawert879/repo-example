#!/bin/bash

# Скрипт для настройки GitHub Secrets
# Использование: ./setup-github-secrets.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Настройка GitHub Secrets ===${NC}"

# Проверка наличия файла secrets.env
if [ ! -f "secrets.env" ]; then
    echo -e "${RED}Ошибка: Файл secrets.env не найден!${NC}"
    echo -e "${YELLOW}Создайте его на основе secrets.example.env${NC}"
    exit 1
fi

# Загрузка переменных из secrets.env
source secrets.env

# Проверка установки GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Ошибка: GitHub CLI (gh) не установлен!${NC}"
    echo -e "${YELLOW}Установите gh: https://cli.github.com/${NC}"
    exit 1
fi

# Проверка авторизации в GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Вы не авторизованы в GitHub CLI${NC}"
    echo -e "${YELLOW}Выполните: gh auth login${NC}"
    exit 1
fi

echo -e "${GREEN}GitHub CLI найден и авторизован${NC}"

# Функция для установки секрета
set_secret() {
    local name=$1
    local value=$2
    echo -e "${YELLOW}Установка секрета: ${name}${NC}"
    echo "$value" | gh secret set "$name"
    echo -e "${GREEN}✓ Секрет $name установлен${NC}"
}

# Установка только SOPS Age Key
if [ -n "$SOPS_AGE_KEY" ]; then
    set_secret "SOPS_AGE_KEY" "$SOPS_AGE_KEY"
else
    echo -e "${RED}Ошибка: SOPS_AGE_KEY не установлен!${NC}"
    exit 1
fi

echo -e "${GREEN}=== Настройка завершена! ===${NC}"
echo -e "${YELLOW}SSH креденшиалы хранятся в зашифрованном файле .ssh.encrypted в репозитории${NC}"
echo -e "${YELLOW}Не забудьте удалить файл secrets.env после настройки!${NC}"
