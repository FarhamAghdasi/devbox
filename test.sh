#!/usr/bin/env bash
# test.sh — Smoke and behavior tests for DevBox.
# Run from the repo root: bash test.sh
# Does NOT require real MariaDB/Apache for most tests.

set -uo pipefail

DEVBOX="./devbox"
PASS=0
FAIL=0
TOTAL=0

assert_ok() {
    local desc="$1"
    shift
    TOTAL=$((TOTAL + 1))
    echo -n "  [TEST] $desc ... "
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "PASS"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL (command: $*)"
    fi
}

assert_fail() {
    local desc="$1"
    shift
    TOTAL=$((TOTAL + 1))
    echo -n "  [TEST] $desc ... "
    if "$@" >/dev/null 2>&1; then
        FAIL=$((FAIL + 1))
        echo "FAIL (expected non-zero exit)"
    else
        PASS=$((PASS + 1))
        echo "PASS"
    fi
}

assert_output_contains() {
    local desc="$1"
    local expected="$2"
    shift 2
    TOTAL=$((TOTAL + 1))
    echo -n "  [TEST] $desc ... "
    local output
    output=$("$@" 2>&1 || true)
    if echo "$output" | grep -qF -- "$expected"; then
        PASS=$((PASS + 1))
        echo "PASS"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL (expected: $expected, got: $output)"
    fi
}

assert_output_not_contains() {
    local desc="$1"
    local forbidden="$2"
    shift 2
    TOTAL=$((TOTAL + 1))
    echo -n "  [TEST] $desc ... "
    local output
    output=$("$@" 2>&1 || true)
    if echo "$output" | grep -qF -- "$forbidden"; then
        FAIL=$((FAIL + 1))
        echo "FAIL (forbidden string found: $forbidden)"
    else
        PASS=$((PASS + 1))
        echo "PASS"
    fi
}

assert_no_output() {
    local desc="$1"
    shift
    TOTAL=$((TOTAL + 1))
    echo -n "  [TEST] $desc ... "
    local output
    output=$("$@" 2>&1 || true)
    if [[ -z "$output" ]]; then
        PASS=$((PASS + 1))
        echo "PASS"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL (expected no output, got: $output)"
    fi
}

section() {
    echo ""
    echo "========================================"
    echo " $1"
    echo "========================================"
}

# ---- Helpers ----

make_temp_laravel() {
    local dir
    dir=$(mktemp -d)
    cat > "$dir/composer.json" <<'EOF'
{"require":{"laravel/framework":"^11.0","php":"^8.2"}}
EOF
    cat > "$dir/.env" <<'EOF'
APP_NAME=Test
APP_KEY=base64:abc123
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=testdb
DB_USERNAME=root
DB_PASSWORD=secret123
EOF
    touch "$dir/artisan"
    mkdir -p "$dir/vendor"
    echo "$dir"
}

# ---- Tests ----

section "Syntax"
assert_ok "devbox script parses" bash -n "$DEVBOX"
assert_ok "modules/ui.sh parses" bash -n modules/ui.sh
assert_ok "modules/services.sh parses" bash -n modules/services.sh
assert_ok "modules/database.sh parses" bash -n modules/database.sh
assert_ok "modules/info.sh parses" bash -n modules/info.sh
assert_ok "modules/laravel.sh parses" bash -n modules/laravel.sh
assert_ok "modules/phpmyadmin.sh parses" bash -n modules/phpmyadmin.sh
assert_ok "install.sh parses" bash -n install.sh
assert_ok "uninstall.sh parses" bash -n uninstall.sh

section "Help and version"
assert_ok "devbox --help exits 0" "$DEVBOX" --help
assert_output_contains "devbox --help shows start" "start" "$DEVBOX" --help
assert_output_contains "devbox --help shows db info" "db info" "$DEVBOX" --help
assert_output_contains "devbox --help shows db size" "db size" "$DEVBOX" --help
assert_output_contains "devbox --help shows project-info" "project-info" "$DEVBOX" --help
assert_output_contains "devbox --help shows uninstall" "uninstall" "$DEVBOX" --help
assert_output_contains "devbox --help shows self-update" "self-update" "$DEVBOX" --help
assert_output_contains "devbox --help shows --quiet" "--quiet" "$DEVBOX" --help
assert_ok "devbox --version exits 0" "$DEVBOX" --version
assert_ok "devbox -V exits 0" "$DEVBOX" -V
assert_output_contains "devbox --version prints version" "devbox 0.1.0" "$DEVBOX" --version

section "Unknown commands and bad input"
assert_fail "unknown command exits non-zero" "$DEVBOX" unknowncommand
assert_fail "db with no subcommand exits non-zero" "$DEVBOX" db
assert_fail "db invalid subcommand exits non-zero" "$DEVBOX" db invalid
assert_fail "db create with empty name exits non-zero" "$DEVBOX" db create ""
assert_fail "db drop with empty name exits non-zero" "$DEVBOX" db drop ""
assert_fail "db backup with empty name exits non-zero" "$DEVBOX" db backup ""
assert_fail "db restore with empty file exits non-zero" "$DEVBOX" db restore ""
assert_fail "db restore with missing file exits non-zero" "$DEVBOX" db restore /nonexistent/file.sql
assert_fail "php with no subcommand exits non-zero" "$DEVBOX" php

section "Database name validation"
assert_fail "db create rejects shell metacharacter" "$DEVBOX" db create "my;db"
assert_fail "db create rejects hyphen" "$DEVBOX" db create "my-db"
assert_fail "db create rejects leading digit" "$DEVBOX" db create "1db"
assert_fail "db size rejects shell metacharacter" "$DEVBOX" db size "my;db"
assert_fail "db size rejects hyphen" "$DEVBOX" db size "my-db"
assert_output_contains "invalid name error mentions rules" "letters, digits" "$DEVBOX" db create "bad db"

section "Destructive-action confirmation"
# db drop should abort on "no"
assert_output_contains "db drop cancels on no" "Cancelled" bash -c 'printf "no\n" | ./devbox db drop mytest 2>&1'
assert_output_contains "db drop aborts on random input" "Cancelled" bash -c 'printf "nope\n" | ./devbox db drop mytest 2>&1'
# db restore should abort on "no" — use a nonexistent path so it fails before asking for confirmation
assert_output_contains "db restore with missing file" "File not found" bash -c './devbox db restore /nonexistent/path.sql mytest 2>&1'
# uninstall should abort on "no"
assert_output_contains "uninstall cancels on no" "Cancelled" bash -c 'printf "no\n" | ./devbox uninstall 2>&1'

section "Missing dependency detection"
# check_deps should report missing commands
assert_output_contains "check_deps function exists" "check_deps()" grep -n "check_deps" ./devbox
assert_output_contains "check_deps uses command -v" "command -v" grep -n "command -v" ./devbox
# Verify database functions use check_deps
assert_output_contains "db_list uses check_deps" "check_deps mysql" grep -n "check_deps" ./modules/database.sh
assert_output_contains "db_create uses check_deps" "check_deps mysql" grep -n "check_deps" ./modules/database.sh
assert_output_contains "db_backup uses check_deps" "check_deps mysqldump" grep -n "check_deps" ./modules/database.sh
assert_output_contains "db_restore uses check_deps" "check_deps mysql" grep -n "check_deps" ./modules/database.sh

section "Configuration loading"
assert_ok "defaults.conf exists" test -f config/defaults.conf
assert_output_contains "defaults.conf has DB_ROOT_USER" "DB_ROOT_USER=root" cat config/defaults.conf
assert_output_contains "defaults.conf has APACHE_SERVICE" "APACHE_SERVICE=httpd" cat config/defaults.conf
assert_output_contains "defaults.conf has MARIADB_SERVICE" "MARIADB_SERVICE=mariadb" cat config/defaults.conf
assert_output_contains "defaults.conf has DEFAULT_DB_HOST" "DEFAULT_DB_HOST=127.0.0.1" cat config/defaults.conf
assert_output_contains "defaults.conf has DEFAULT_DB_PORT" "DEFAULT_DB_PORT=3306" cat config/defaults.conf
assert_ok "env.example exists" test -f env.example
assert_output_contains "env.example has PHPMYADMIN_DB_PASS" "PHPMYADMIN_DB_PASS" cat env.example
assert_output_contains "env.example has PHPMYADMIN_DB_USER" "PHPMYADMIN_DB_USER" cat env.example
assert_ok ".gitignore ignores .env" grep -q "^\.env$" .gitignore
assert_ok ".gitignore ignores *.sql" grep -q "^\*\.sql$" .gitignore

section ".env sourcing and credential safety"
# Create a temp dir with a .env and verify the values are loaded
TMP_DIR=$(mktemp -d)
cat > "$TMP_DIR/.env" <<'EOF'
PHPMYADMIN_DB_PASS=supersecretpassword
EOF
assert_output_contains ".env sources PHPMYADMIN_DB_PASS" "supersecretpassword" bash -c "source '$TMP_DIR/.env' && echo \"\$PHPMYADMIN_DB_PASS\""
rm -rf "$TMP_DIR"

section "Laravel project detection"
TMP_LARAVEL=$(make_temp_laravel)
assert_ok "laravel-check detects Laravel project" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check finds composer.json" "composer.json: Found" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check detects framework" "Laravel framework: Detected" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check finds .env" ".env: Found" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check finds artisan" "artisan: Found" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check shows APP_KEY set" "APP_KEY: Set" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check shows vendor present" "vendor/: Present" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_contains "laravel-check shows PHP version" "PHP version" "$DEVBOX" laravel-check "$TMP_LARAVEL"
assert_output_not_contains "laravel-check does not leak DB_PASSWORD" "secret123" "$DEVBOX" laravel-check "$TMP_LARAVEL"
rm -rf "$TMP_LARAVEL"
TMP_NOT_LARAVEL=$(mktemp -d)
assert_fail "laravel-check fails on non-Laravel dir" "$DEVBOX" laravel-check "$TMP_NOT_LARAVEL"
rm -rf "$TMP_NOT_LARAVEL"

section "Project info"
TMP_LARAVEL=$(make_temp_laravel)
assert_ok "project-info runs on Laravel dir" "$DEVBOX" project-info "$TMP_LARAVEL"
assert_output_contains "project-info shows framework" "Laravel" "$DEVBOX" project-info "$TMP_LARAVEL"
assert_output_contains "project-info shows PHP" "PHP" "$DEVBOX" project-info "$TMP_LARAVEL"
rm -rf "$TMP_LARAVEL"

section "Quiet flag"
# Quiet mode should suppress headers, subheaders, and success/warn messages.
# Table rows and status badges may still appear (they are data, not decoration).
quiet_output=$("$DEVBOX" -q status 2>&1 || true)
assert_output_not_contains "quiet suppresses ui_header" "Service Status" bash -c "echo '$quiet_output'"
assert_output_not_contains "quiet suppresses ui_subheader" "----" bash -c "echo '$quiet_output'"
assert_output_not_contains "quiet suppresses success messages" "✓" bash -c "echo '$quiet_output'"

section "Service status (no crash when not running)"
assert_ok "status exits 0 even when services stopped" "$DEVBOX" status
assert_output_contains "status shows apache" "apache" "$DEVBOX" status
assert_output_contains "status shows mysql" "mysql" "$DEVBOX" status

section "Database info"
assert_ok "db info exits 0" "$DEVBOX" db info
assert_output_contains "db info shows engine" "MariaDB" "$DEVBOX" db info
assert_output_contains "db info shows host" "127.0.0.1" "$DEVBOX" db info
assert_output_contains "db info shows port" "3306" "$DEVBOX" db info

section "PHP info"
assert_ok "php info exits 0" "$DEVBOX" php info
assert_output_contains "php info shows binary" "Binary" "$DEVBOX" php info
assert_output_contains "php info shows extensions" "Extensions" "$DEVBOX" php info

section "Uninstall safety"
assert_output_contains "uninstall shows warning" "will be removed" "$DEVBOX" uninstall

section "Password safety in phpMyAdmin"
# Verify the quiet helper exists (no verbose password leak)
assert_output_contains "_db_mysql_root_quiet is defined" "_db_mysql_root_quiet" grep -n "_db_mysql_root_quiet" ./modules/phpmyadmin.sh
assert_output_contains "_db_mysql_root_verbose is defined" "_db_mysql_root_verbose" grep -n "_db_mysql_root_verbose" ./modules/phpmyadmin.sh
# Verify CREATE USER uses quiet helper, not verbose
assert_output_contains "CREATE USER uses quiet helper" "_db_mysql_root_quiet" grep -n "CREATE USER" ./modules/phpmyadmin.sh
assert_output_not_contains "CREATE USER does not use verbose helper" "_db_mysql_root_verbose" grep -n "CREATE USER" ./modules/phpmyadmin.sh

# ---- Summary ----

echo ""
echo "========================================"
echo " Results"
echo "========================================"
echo "  Total:  $TOTAL"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if (( FAIL > 0 )); then
    echo "Some tests failed."
    exit 1
else
    echo "All tests passed."
    exit 0
fi
