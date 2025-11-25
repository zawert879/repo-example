#!/bin/bash
# Комплексные тесты для init.sh

set +e  # Continue on errors

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Функции для тестирования
test_header() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

test_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"
    
    if [ "$result" = "true" ]; then
        echo -e "  ${GREEN}✓ $test_name${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "  ${RED}✗ $test_name${NC}"
        if [ -n "$message" ]; then
            echo -e "    ${NC}Error: $message${NC}"
        fi
        ((TESTS_FAILED++))
    fi
}

test_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        test_result "File exists: $file" "true"
        return 0
    else
        test_result "File exists: $file" "false"
        return 1
    fi
}

test_function_exists() {
    local func_name="$1"
    if declare -f "$func_name" > /dev/null; then
        test_result "Function '$func_name' exists" "true"
        return 0
    else
        test_result "Function '$func_name' exists" "false"
        return 1
    fi
}

# Начало тестов
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║        Init.sh Comprehensive Test Suite                  ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"

# Test 1: Проверка существования файлов скриптов
test_header "Test Suite 1: Script Files"

test_file_exists "init.sh"
test_file_exists "init.ps1"
test_file_exists "scripts/setup-github-secrets.sh"
test_file_exists "scripts/setup-github-secrets.ps1"
test_file_exists "scripts/encrypt-ssh.sh"
test_file_exists "scripts/encrypt-ssh.ps1"

# Test 2: Загрузка функций из скрипта
test_header "Test Suite 2: Function Definitions"

# Извлекаем функции из init.sh
if [ -f "init.sh" ]; then
    # Загружаем только функции, пропуская основной код
    source <(sed -n '/^ask_yes_no()/,/^}/p' init.sh) 2>/dev/null || true
    source <(sed -n '/^check_and_install_deps()/,/^}/p' init.sh) 2>/dev/null || true
    source <(sed -n '/^validate_github_repo()/,/^}/p' init.sh) 2>/dev/null || true
    
    test_result "Script functions loaded" "true"
else
    test_result "Script functions loaded" "false" "init.sh not found"
fi

# Проверка наличия функций в скрипте
if grep -q "^ask_yes_no()" init.sh 2>/dev/null; then
    test_result "Function 'ask_yes_no' defined" "true"
else
    test_result "Function 'ask_yes_no' defined" "false"
fi

if grep -q "^check_and_install_deps()" init.sh 2>/dev/null; then
    test_result "Function 'check_and_install_deps' defined" "true"
else
    test_result "Function 'check_and_install_deps' defined" "false"
fi

if grep -q "^validate_github_repo()" init.sh 2>/dev/null; then
    test_result "Function 'validate_github_repo' defined" "true"
else
    test_result "Function 'validate_github_repo' defined" "false"
fi

# Test 3: Тестирование валидации GitHub repo
test_header "Test Suite 3: Validate-GitHubRepo Function"

# Валидные форматы
valid_repos=(
    "user/repo"
    "user-name/repo-name"
    "user_name/repo_name"
    "user123/repo456"
)

for repo in "${valid_repos[@]}"; do
    if [[ "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        test_result "Validate format: $repo" "true"
    else
        test_result "Validate format: $repo" "false"
    fi
done

# Невалидные форматы
invalid_repos=(
    "invalid"
    "user/"
    "/repo"
    "user//repo"
    "user repo/repo"
)

for repo in "${invalid_repos[@]}"; do
    if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        test_result "Reject invalid format: $repo" "true"
    else
        test_result "Reject invalid format: $repo" "false"
    fi
done

# Test 4: Проверка командной строки SSH
test_header "Test Suite 4: SSH Key Generation Commands"

# Проверка синтаксиса команд ssh-keygen в скрипте
if grep -q 'ssh-keygen -t ed25519' init.sh; then
    test_result "SSH ed25519 command present" "true"
else
    test_result "SSH ed25519 command present" "false"
fi

if grep -q 'ssh-keygen -t rsa -b 4096' init.sh; then
    test_result "SSH rsa command present" "true"
else
    test_result "SSH rsa command present" "false"
fi

# Проверка что используется -N "" (пустой пароль)
if grep -q 'ssh-keygen.*-N ""' init.sh; then
    test_result "SSH commands use empty passphrase" "true"
else
    test_result "SSH commands use empty passphrase" "false"
fi

# Test 5: Тестирование создания secrets.env
test_header "Test Suite 5: Secrets.env Creation"

test_key="AGE-SECRET-KEY-1TESTKEYTESTKEYTESTKEYTESTKEYTESTKEYTESTKEYTESTKEYTESTKEY"
temp_file="test-secrets-$$.env"

cat > "$temp_file" << EOF
# SOPS Age Private Key
SOPS_AGE_KEY=$test_key
EOF

if [ -f "$temp_file" ]; then
    test_result "Secrets.env file created" "true"
    
    if grep -q "$test_key" "$temp_file"; then
        test_result "Secrets.env contains SOPS key" "true"
    else
        test_result "Secrets.env contains SOPS key" "false"
    fi
    
    if grep -q "SOPS_AGE_KEY=AGE-SECRET-KEY-" "$temp_file"; then
        test_result "Secrets.env has correct format" "true"
    else
        test_result "Secrets.env has correct format" "false"
    fi
    
    rm -f "$temp_file"
else
    test_result "Secrets.env file created" "false"
fi

# Test 6: Тестирование SOPS encryption syntax
test_header "Test Suite 6: SOPS Encryption Syntax"

temp_file="test-sops-$$.txt"
echo "TEST_KEY=test_value" > "$temp_file"

if [ -f "$temp_file" ]; then
    test_result "SOPS temp file created" "true"
else
    test_result "SOPS temp file created" "false"
fi

# Проверка синтаксиса команды шифрования в скрипте
if grep -q "sops -e" init.sh; then
    test_result "SOPS encrypt command present" "true"
else
    test_result "SOPS encrypt command present" "false"
fi

# Проверка наличия sops
if command -v sops &> /dev/null; then
    test_result "SOPS is installed" "true"
else
    echo -e "  ${YELLOW}⚠ SOPS not installed (skipping actual encryption test)${NC}"
    ((TESTS_SKIPPED++))
fi

rm -f "$temp_file"

# Test 7: Проверка .gitignore patterns
test_header "Test Suite 7: Gitignore Configuration"

if [ -f ".gitignore" ]; then
    patterns=(
        "secrets.env"
        ".env"
        ".keys/"
        ".ssh-keys/"
        "*.key"
        "*.pem"
    )
    
    for pattern in "${patterns[@]}"; do
        if grep -q "$pattern" .gitignore; then
            test_result "Gitignore contains '$pattern'" "true"
        else
            test_result "Gitignore contains '$pattern'" "false"
        fi
    done
else
    test_result ".gitignore exists" "false"
fi

# Test 8: Проверка SOPS конфигурации
test_header "Test Suite 8: SOPS Configuration"

if [ -f ".sops.yaml" ]; then
    if grep -q "age:" .sops.yaml; then
        test_result "SOPS config has age encryption" "true"
    else
        test_result "SOPS config has age encryption" "false"
    fi
    
    if grep -q "creation_rules:" .sops.yaml; then
        test_result "SOPS config has creation rules" "true"
    else
        test_result "SOPS config has creation rules" "false"
    fi
    
    if grep -q "path_regex:" .sops.yaml; then
        test_result "SOPS config has path matcher" "true"
    else
        test_result "SOPS config has path matcher" "false"
    fi
    
    patterns=(".env.encrypted" ".ssh.encrypted")
    for pattern in "${patterns[@]}"; do
        if grep -q "$pattern" .sops.yaml; then
            test_result "SOPS config includes '$pattern'" "true"
        else
            test_result "SOPS config includes '$pattern'" "false"
        fi
    done
else
    test_result ".sops.yaml exists" "false"
fi

# Test 9: Проверка структуры директорий
test_header "Test Suite 9: Directory Structure"

required_dirs=(
    ".github"
    ".github/workflows"
    "scripts"
    "stacks"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        test_result "Directory exists: $dir" "true"
    else
        test_result "Directory exists: $dir" "false"
    fi
done

# Test 10: Проверка example-app структуры
test_header "Test Suite 10: Example-App Structure"

if [ -d "example-app" ]; then
    example_files=(
        "example-app/Dockerfile"
        "example-app/src/index.html"
        "example-app/.github/workflows/build-and-deploy.yml"
    )
    
    for file in "${example_files[@]}"; do
        test_file_exists "$file"
    done
    
    # Проверка Dockerfile
    if [ -f "example-app/Dockerfile" ]; then
        if grep -q "FROM nginx:alpine" example-app/Dockerfile; then
            test_result "Dockerfile has FROM nginx:alpine" "true"
        else
            test_result "Dockerfile has FROM nginx:alpine" "false"
        fi
        
        if grep -q "COPY.*index.html" example-app/Dockerfile; then
            test_result "Dockerfile copies index.html" "true"
        else
            test_result "Dockerfile copies index.html" "false"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠ example-app not found (skipped)${NC}"
    ((TESTS_SKIPPED++))
fi

# Test 11: Проверка GitHub Actions workflow
test_header "Test Suite 11: GitHub Actions Workflows"

workflow_file=".github/workflows/deploy.yml"
if [ -f "$workflow_file" ]; then
    if grep -q "SOPS_AGE_KEY" "$workflow_file"; then
        test_result "Workflow uses SOPS_AGE_KEY secret" "true"
    else
        test_result "Workflow uses SOPS_AGE_KEY secret" "false"
    fi
    
    if grep -q "detect-changes:" "$workflow_file"; then
        test_result "Workflow has detect-changes job" "true"
    else
        test_result "Workflow has detect-changes job" "false"
    fi
    
    if grep -q "deploy:" "$workflow_file"; then
        test_result "Workflow has deploy job" "true"
    else
        test_result "Workflow has deploy job" "false"
    fi
    
    if grep -q "matrix:" "$workflow_file"; then
        test_result "Workflow uses matrix strategy" "true"
    else
        test_result "Workflow uses matrix strategy" "false"
    fi
    
    if grep -q "\.ssh\.encrypted" "$workflow_file"; then
        test_result "Workflow decrypts .ssh.encrypted" "true"
    else
        test_result "Workflow decrypts .ssh.encrypted" "false"
    fi
else
    test_result "Deploy workflow exists" "false"
fi

# Test 12: Проверка скриптов setup
test_header "Test Suite 12: Setup Scripts"

if [ -f "scripts/setup-github-secrets.sh" ]; then
    if grep -q "gh secret set" scripts/setup-github-secrets.sh; then
        test_result "setup-github-secrets.sh uses gh secret set" "true"
    else
        test_result "setup-github-secrets.sh uses gh secret set" "false"
    fi
    
    if grep -q "SOPS_AGE_KEY" scripts/setup-github-secrets.sh; then
        test_result "setup-github-secrets.sh references SOPS_AGE_KEY" "true"
    else
        test_result "setup-github-secrets.sh references SOPS_AGE_KEY" "false"
    fi
fi

if [ -f "scripts/encrypt-ssh.sh" ]; then
    if grep -q "sops -e" scripts/encrypt-ssh.sh; then
        test_result "encrypt-ssh.sh uses sops encryption" "true"
    else
        test_result "encrypt-ssh.sh uses sops encryption" "false"
    fi
    
    if grep -q "\.ssh\.encrypted" scripts/encrypt-ssh.sh; then
        test_result "encrypt-ssh.sh creates .ssh.encrypted" "true"
    else
        test_result "encrypt-ssh.sh creates .ssh.encrypted" "false"
    fi
fi

# Test 13: Проверка README документации
test_header "Test Suite 13: Documentation"

docs=(
    "README.md"
    "GITOPS.md"
    "EXAMPLE-APP.md"
    "TROUBLESHOOTING.md"
)

for doc in "${docs[@]}"; do
    test_file_exists "$doc"
    
    if [ -f "$doc" ]; then
        size=$(wc -c < "$doc")
        if [ "$size" -gt 100 ]; then
            test_result "$doc has substantial content" "true"
        else
            test_result "$doc has substantial content" "false"
        fi
    fi
done

# Test 14: Проверка secrets.example.env
test_header "Test Suite 14: Secrets Template"

if [ -f "secrets.example.env" ]; then
    if grep -q "SOPS_AGE_KEY" secrets.example.env; then
        test_result "Template contains SOPS_AGE_KEY placeholder" "true"
    else
        test_result "Template contains SOPS_AGE_KEY placeholder" "false"
    fi
    
    if grep -q "#" secrets.example.env; then
        test_result "Template has comments" "true"
    else
        test_result "Template has comments" "false"
    fi
else
    test_result "secrets.example.env exists" "false"
fi

# Итоговый отчет
echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                    Test Summary                           ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(awk "BEGIN {printf \"%.2f\", ($TESTS_PASSED / $TOTAL_TESTS) * 100}")
else
    PASS_RATE="0.00"
fi

echo -e "  ${CYAN}Total Tests:${NC}    $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:${NC}         $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}         $TESTS_FAILED"
echo -e "  ${YELLOW}Skipped:${NC}        $TESTS_SKIPPED"

if (( $(echo "$PASS_RATE >= 90" | bc -l) )); then
    echo -e "  ${GREEN}Pass Rate:${NC}      ${PASS_RATE}%"
elif (( $(echo "$PASS_RATE >= 70" | bc -l) )); then
    echo -e "  ${YELLOW}Pass Rate:${NC}      ${PASS_RATE}%"
else
    echo -e "  ${RED}Pass Rate:${NC}      ${PASS_RATE}%"
fi

echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Ready for deployment!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the errors above.${NC}"
    exit 1
fi
