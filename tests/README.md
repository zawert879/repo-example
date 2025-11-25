# Тесты для инициализационных скриптов

Этот каталог содержит комплексные тесты для `init.ps1` и `init.sh` скриптов.

## 📋 Доступные тесты

### `test-init.ps1` (PowerShell)
Комплексный набор тестов для Windows PowerShell скрипта инициализации.

**Запуск:**
```powershell
.\tests\test-init.ps1
```

**Покрываемые области:**
- ✅ Существование файлов скриптов
- ✅ Определение функций (Ask-YesNo, Check-AndInstallDeps, Validate-GitHubRepo)
- ✅ Валидация GitHub репозиториев
- ✅ Команды генерации SSH ключей
- ✅ Создание secrets.env
- ✅ SOPS шифрование
- ✅ Конфигурация .gitignore
- ✅ SOPS конфигурация (.sops.yaml)
- ✅ Структура директорий
- ✅ Example-app структура
- ✅ GitHub Actions workflows
- ✅ Setup скрипты
- ✅ Документация
- ✅ Secrets шаблоны

### `test-init.sh` (Bash)
Комплексный набор тестов для Linux/macOS Bash скрипта инициализации.

**Запуск:**
```bash
chmod +x tests/test-init.sh
./tests/test-init.sh
```

**Покрываемые области:**
- ✅ Все те же области что и в PowerShell версии
- ✅ ShellCheck совместимость
- ✅ POSIX совместимость

## 🚀 GitHub Actions

Тесты автоматически запускаются на GitHub Actions при:
- Push в ветки `main` или `develop`
- Pull request в `main`
- Изменениях в файлах:
  - `init.ps1`
  - `init.sh`
  - `scripts/**`
  - `tests/**`

### Матрица тестирования:

| ОС | PowerShell | Bash | Интеграция |
|---|---|---|---|
| **Windows** | ✅ | - | - |
| **Linux** | - | ✅ | ✅ |
| **macOS** | - | ✅ | - |

## 📊 Структура тестов

### Suite 1: Script Files
Проверка существования всех необходимых файлов скриптов.

### Suite 2: Function Definitions
Проверка что все функции определены и доступны:
- `Ask-YesNo` / `ask_yes_no`
- `Check-AndInstallDeps` / `check_and_install_deps`
- `Validate-GitHubRepo` / `validate_github_repo`

### Suite 3: Validate-GitHubRepo Function
Тестирование валидации форматов GitHub репозиториев:
- ✅ Валидные: `user/repo`, `user-name/repo-name`
- ❌ Невалидные: `invalid`, `user/`, `/repo`

### Suite 4: SSH Key Generation
Проверка синтаксиса команд ssh-keygen:
- ed25519 ключи
- RSA 4096 ключи
- Пустой passphrase

### Suite 5: Secrets.env Creation
Тестирование создания файла с SOPS ключом.

### Suite 6: SOPS Encryption
Проверка синтаксиса команд SOPS шифрования.

### Suite 7: Gitignore Configuration
Проверка что .gitignore содержит все необходимые паттерны.

### Suite 8: SOPS Configuration
Проверка .sops.yaml конфигурации.

### Suite 9: Directory Structure
Проверка наличия всех необходимых директорий.

### Suite 10: Example-App Structure
Проверка структуры example-app.

### Suite 11: GitHub Actions Workflows
Проверка workflows на наличие необходимых компонентов.

### Suite 12: Setup Scripts
Проверка вспомогательных скриптов.

### Suite 13: Documentation
Проверка наличия и содержимого документации.

### Suite 14: Secrets Template
Проверка secrets.example.env.

### Suite 15: Integration Tests (только в CI)
Полный цикл генерации ключей и шифрования.

## 🎯 Локальный запуск всех тестов

### Windows:
```powershell
# PowerShell тесты
.\tests\test-init.ps1

# Проверка синтаксиса
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content .\init.ps1 -Raw), [ref]$errors)
if ($errors.Count -eq 0) {
    Write-Host "✓ No syntax errors" -ForegroundColor Green
}
```

### Linux/macOS:
```bash
# Bash тесты
./tests/test-init.sh

# Проверка синтаксиса
bash -n init.sh && echo "✓ No syntax errors"

# ShellCheck (опционально)
shellcheck init.sh scripts/*.sh
```

## 📈 Отчеты о тестах

После запуска тесты выводят подробный отчет:

```
═══════════════════════════════════════════════════════════
                    Test Summary
═══════════════════════════════════════════════════════════

  Total Tests:    85
  Passed:         82
  Failed:         3
  Skipped:        2
  Pass Rate:      96.47%

✓ All tests passed! Ready for deployment!
```

### Exit коды:
- `0` - все тесты прошли
- `1` - есть проваленные тесты

## 🔧 Добавление новых тестов

### PowerShell:
```powershell
# В test-init.ps1
test_header "Test Suite X: New Feature"

$result = Test-YourFeature
test_result "Your test name" $result
```

### Bash:
```bash
# В test-init.sh
test_header "Test Suite X: New Feature"

if test_your_feature; then
    test_result "Your test name" "true"
else
    test_result "Your test name" "false"
fi
```

## 🐛 Отладка упавших тестов

### 1. Запустите тест локально
```powershell
# Windows
.\tests\test-init.ps1 -Verbose

# Linux/Mac
./tests/test-init.sh
```

### 2. Проверьте конкретный файл
```powershell
# Проверка синтаксиса
Get-Content init.ps1 -Raw | Out-Null

# Проверка функции
. .\init.ps1
Test-Path function:\Ask-YesNo
```

### 3. Посмотрите логи GitHub Actions
```bash
# Скачайте артефакты с GitHub Actions
gh run download
```

## 📚 Зависимости для локального запуска

### Обязательные:
- PowerShell 5.1+ (Windows) или PowerShell Core 7+ (cross-platform)
- Bash 4.0+ (Linux/macOS)

### Опциональные (для полных тестов):
- `age` - Age encryption tool
- `sops` - Secrets encryption
- `gh` - GitHub CLI
- `shellcheck` - Shell script linter (только Linux/macOS)

### Установка зависимостей:

**Windows:**
```powershell
choco install age sops gh
```

**Linux:**
```bash
# Age
wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
tar xzf age-v1.1.1-linux-amd64.tar.gz
sudo mv age/age* /usr/local/bin/

# SOPS
wget https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install gh

# ShellCheck
sudo apt-get install shellcheck
```

**macOS:**
```bash
brew install age sops gh shellcheck
```

## 🎓 Лучшие практики

1. **Запускайте тесты перед коммитом:**
   ```bash
   ./tests/test-init.sh && git commit
   ```

2. **Проверяйте синтаксис после изменений:**
   ```powershell
   .\tests\test-init.ps1
   ```

3. **Смотрите покрытие тестов:**
   - Каждая функция должна иметь тест
   - Каждая критическая операция должна быть протестирована

4. **Документируйте новые тесты:**
   - Добавьте описание в этот README
   - Укажите что тестируется и почему

## 🤝 Вклад в тесты

При добавлении новых функций в `init.ps1` или `init.sh`:

1. Добавьте соответствующие тесты
2. Убедитесь что все существующие тесты проходят
3. Запустите тесты локально перед push
4. Проверьте результаты в GitHub Actions

## 📞 Помощь

Если тесты не проходят:

1. Проверьте [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)
2. Запустите диагностику: `.\check-status.ps1`
3. Посмотрите логи тестов
4. Проверьте что все зависимости установлены

## 📝 Changelog

### v1.0.0 (2025-11-26)
- ✨ Добавлены комплексные тесты для init.ps1
- ✨ Добавлены комплексные тесты для init.sh
- ✨ Создан GitHub Actions workflow для CI/CD
- ✨ Добавлена поддержка Windows, Linux и macOS
- ✨ Интеграционные тесты
- ✨ ShellCheck интеграция
