#!/bin/bash
# Запуск всех тестов локально

set +e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ALL_PASSED=true

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          Running All Tests Locally                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Проверка зависимостей
echo -e "${BLUE}[1/4] Checking dependencies...${NC}"
DEPS=("age-keygen" "sops" "gh" "ssh-keygen")
MISSING=()

for dep in "${DEPS[@]}"; do
    if command -v "$dep" &> /dev/null; then
        echo -e "  ${GREEN}✓ $dep${NC}"
    else
        echo -e "  ${YELLOW}✗ $dep - not found${NC}"
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠ Missing dependencies: ${MISSING[*]}${NC}"
    echo -e "${YELLOW}Some tests may be skipped.${NC}"
    echo ""
    echo -e "${CYAN}Install via:${NC}"
    echo -e "  ${NC}macOS: brew install age sops gh${NC}"
    echo -e "  ${NC}Linux: See tests/README.md for instructions${NC}"
    echo ""
fi

# 2. Syntax check
echo ""
echo -e "${BLUE}[2/4] Checking Bash syntax...${NC}"

BASH_SCRIPTS=("init.sh")
if [ -d "scripts" ]; then
    while IFS= read -r -d '' script; do
        BASH_SCRIPTS+=("$script")
    done < <(find scripts -name "*.sh" -type f -print0)
fi

for script in "${BASH_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        continue
    fi
    
    if bash -n "$script" 2>/dev/null; then
        echo -e "  ${GREEN}✓ $(basename "$script")${NC}"
    else
        echo -e "  ${RED}✗ $(basename "$script") - syntax errors${NC}"
        bash -n "$script" 2>&1 | sed 's/^/    /'
        ALL_PASSED=false
    fi
done

# 3. ShellCheck (если доступен)
echo ""
echo -e "${BLUE}[3/4] Running ShellCheck (if available)...${NC}"

if command -v shellcheck &> /dev/null; then
    for script in "${BASH_SCRIPTS[@]}"; do
        if [ ! -f "$script" ]; then
            continue
        fi
        
        if shellcheck -x -S warning "$script" 2>&1 | grep -v "^$" > /dev/null; then
            echo -e "  ${YELLOW}⚠ $(basename "$script") - has warnings${NC}"
            if [ "$VERBOSE" = "true" ]; then
                shellcheck -x -S warning "$script" | sed 's/^/    /'
            fi
        else
            echo -e "  ${GREEN}✓ $(basename "$script")${NC}"
        fi
    done
else
    echo -e "  ${YELLOW}⚠ ShellCheck not available (skipped)${NC}"
    echo -e "    ${NC}Install: brew install shellcheck (macOS) or apt-get install shellcheck (Linux)${NC}"
fi

# 4. Run Bash tests
echo ""
echo -e "${BLUE}[4/4] Running Bash test suite...${NC}"

if [ -f "tests/test-init.sh" ]; then
    chmod +x tests/test-init.sh 2>/dev/null
    
    if ./tests/test-init.sh; then
        echo ""
        echo -e "${GREEN}✓ Bash tests passed${NC}"
    else
        echo ""
        echo -e "${RED}✗ Bash tests failed${NC}"
        ALL_PASSED=false
    fi
else
    echo -e "  ${YELLOW}⚠ test-init.sh not found${NC}"
fi

# Summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    Summary                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}✓ All tests passed! Ready to commit!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  ${NC}git add .${NC}"
    echo -e "  ${NC}git commit -m 'Add comprehensive tests'${NC}"
    echo -e "  ${NC}git push${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please fix the issues above.${NC}"
    echo ""
    echo -e "${YELLOW}Tips:${NC}"
    echo -e "  ${NC}- Check syntax errors first${NC}"
    echo -e "  ${NC}- Review test output for specific failures${NC}"
    echo -e "  ${NC}- Run: VERBOSE=true ./run-tests.sh for details${NC}"
    echo ""
    exit 1
fi
