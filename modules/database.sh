# modules/database.sh
# Database CRUD, backup, restore, and MySQL config helpers for DevBox.
# On Fedora, MariaDB root uses unix_socket auth by default: no password needed.

set -euo pipefail

DB_ROOT_USER="${DB_ROOT_USER:-root}"
DEFAULT_DB_HOST="${DEFAULT_DB_HOST:-127.0.0.1}"
DEFAULT_DB_PORT="${DEFAULT_DB_PORT:-3306}"

_db_mysql() {
    ${SUDO:-} mysql -u"${DB_ROOT_USER}" "$@"
}

_db_mysql_silent() {
    ${SUDO:-} mysql -u"${DB_ROOT_USER}" "$@" 2>/dev/null
}

_db_validate_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        ui_red "Error: Database name cannot be empty."
        return 1
    fi
    if ! [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        ui_red "Error: Invalid database name '${name}'."
        echo "  Use letters, digits, and underscores only; must start with a letter or underscore."
        return 1
    fi
}

db_list() {
    check_deps mysql || return 1
    ui_bold "Databases:"
    local output
    if ! output=$(_db_mysql_silent -e "SHOW DATABASES;" 2>&1); then
        ui_red "Error: Failed to list databases."
        echo "  $output"
        return 1
    fi
    echo "$output" \
        | tail -n +2 \
        | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' \
        | sed 's/^/  - /' \
        || ui_yellow "  (no user databases found)"
}

db_create() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        ui_red "Error: Database name required."
        echo "Usage: devbox db create <name>"
        return 1
    fi
    _db_validate_name "$name" || return 1

    check_deps mysql || return 1

    if _db_mysql_silent -N -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${name}';" \
       | grep -q .; then
        ui_red "Error: Database '${name}' already exists."
        return 1
    fi

    if _db_mysql -e "CREATE DATABASE \`${name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" &>/dev/null; then
        ui_success "Database '${name}' created."
    else
        ui_red "Error: Failed to create database '${name}'."
        return 1
    fi
}

db_drop() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        ui_red "Error: Database name required."
        echo "Usage: devbox db drop <name>"
        return 1
    fi
    _db_validate_name "$name" || return 1

    check_deps mysql || return 1

    read -p "Drop database '${name}'? This cannot be undone. (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        return 0
    fi

    if _db_mysql -e "DROP DATABASE \`${name}\`;" &>/dev/null; then
        ui_success "Database '${name}' dropped."
    else
        ui_red "Error: Failed to drop database '${name}'."
        return 1
    fi
}

db_backup() {
    local name="${1:-}"
    local file="${2:-}"

    if [[ -z "$name" ]]; then
        ui_red "Error: Database name required."
        echo "Usage: devbox db backup <name> [output_file]"
        return 1
    fi
    _db_validate_name "$name" || return 1

    check_deps mysqldump || return 1

    if [[ -z "$file" ]]; then
        file="./${name}_$(date +%Y%m%d_%H%M%S).sql"
    fi

    ui_yellow "Backing up" "'${name}' to '${file}'..."
    local stderr
    stderr=$(mktemp)
    if mysqldump -u"${DB_ROOT_USER}" --single-transaction --routines --triggers --events "$name" \
       > "$file" 2>"$stderr"; then
        local size
        size=$(du -h "$file" | cut -f1)
        ui_success "Backup complete: ${file} (${size})"
    else
        ui_red "Error: Backup failed."
        echo "  $(tail -5 "$stderr" | sed 's/^/    /')"
        rm -f "$file" "$stderr"
        return 1
    fi
    rm -f "$stderr"
}

db_restore() {
    local file="${1:-}"
    local name="${2:-}"

    if [[ -z "$file" ]]; then
        ui_red "Error: SQL file path required."
        echo "Usage: devbox db restore <sql_file> [database_name]"
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        ui_red "Error: File not found: ${file}"
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        ui_red "Error: File not readable: ${file}"
        return 1
    fi

    check_deps mysql || return 1

    if [[ -n "$name" ]]; then
        _db_validate_name "$name" || return 1
        echo "Creating database '${name}' if it does not exist..."
        _db_mysql -e "CREATE DATABASE IF NOT EXISTS \`${name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" &>/dev/null || {
            ui_red "Error: Could not create database '${name}'."
            return 1
        }
    else
        name=$(grep -oP 'CREATE DATABASE[[:space:]]+`?\K[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null | head -1 || true)
        if [[ -z "$name" ]]; then
            name=$(grep -oP 'USE[[:space:]]+`?\K[a-zA-Z_][a-zA-Z0-9_]*' "$file" 2>/dev/null | head -1 || true)
        fi
        if [[ -z "$name" ]]; then
            ui_red "Error: Could not determine database name from SQL file."
            echo "  Specify it explicitly: devbox db restore <file> <name>"
            return 1
        fi
        ui_yellow "Inferred database:" "${name}"
    fi

    read -p "Restore '${file}' into database '${name}'? Existing data will be overwritten. (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        return 0
    fi

    ui_yellow "Restoring into" "'${name}'..."
    local stderr
    stderr=$(mktemp)
    if _db_mysql "$name" < "$file" 2>"$stderr"; then
        ui_success "Restore complete."
    else
        ui_red "Error: Restore failed."
        echo "  $(tail -5 "$stderr" | sed 's/^/    /')"
        rm -f "$stderr"
        return 1
    fi
    rm -f "$stderr"
}

db_size() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        ui_red "Error: Database name required."
        echo "Usage: devbox db size <name>"
        return 1
    fi
    _db_validate_name "$name" || return 1
    check_deps mysql || return 1

    _db_mysql -e "SELECT table_name AS 'Table', \
        ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' \
        FROM information_schema.tables \
        WHERE table_schema='${name}' \
        ORDER BY (data_length + index_length) DESC;" 2>/dev/null \
        | sed 's/^/  /' \
        || ui_yellow "  (unable to determine sizes)"
}

mysql_config_show() {
    ui_header "MySQL Configuration"
    echo ""
    ui_bold "Current settings:"
    ui_table_row "Root user" "${DB_ROOT_USER}"
    ui_table_row "Host" "localhost"
    ui_table_row "Port" "3306"
    ui_table_row "Auth" "unix_socket (default on Fedora)"
    echo ""
    ui_yellow "No password required. DevBox uses the system's unix_socket auth."
    echo ""
}

db_info() {
    ui_header "Database Information"
    echo ""
    ui_bold "Database Server"
    ui_subheader ""

    check_deps mysql || return 1

    local ver
    ver=$(mysql --version 2>/dev/null | awk '{print $3}' | cut -d, -f1 || echo "unknown")
    ui_table_row "Engine" "MariaDB"
    ui_table_row "Version" "$ver"
    ui_table_row "Host" "${DEFAULT_DB_HOST}"
    ui_table_row "Port" "${DEFAULT_DB_PORT}"

    if svc_is_active mysql 2>/dev/null; then
        ui_table_row "Status" "Running"
    else
        ui_table_row "Status" "Stopped"
    fi

    echo ""
    ui_bold "Databases:"
    local output
    if ! output=$(_db_mysql_silent -e "SHOW DATABASES;" 2>&1); then
        ui_yellow "  (unable to list — is MariaDB running?)"
        echo ""
        return
    fi
    echo "$output" \
        | tail -n +2 \
        | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' \
        | sed 's/^/  - /' \
        || ui_yellow "  (no user databases found)"
    echo ""
}
