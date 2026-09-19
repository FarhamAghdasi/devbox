# modules/laravel.sh
# Laravel project detection and validation for DevBox.

set -euo pipefail

laravel_check() {
    local dir="${1:-.}"

    ui_header "Laravel Project Check"
    echo ""

    if [[ ! -f "${dir}/composer.json" ]]; then
        ui_warn "composer.json: Not found"
        echo ""
        ui_red "This does not appear to be a Laravel project."
        return 1
    fi
    ui_success "composer.json: Found"

    if grep -q '"laravel/framework' "${dir}/composer.json" 2>/dev/null; then
        ui_success "Laravel framework: Detected"
    else
        ui_warn "Laravel framework: Not detected in composer.json"
        echo ""
        ui_red "This may not be a Laravel project."
        return 1
    fi

    if [[ -f "${dir}/.env" ]]; then
        ui_success ".env: Found"
    else
        ui_warn ".env: Missing (copy from .env.example)"
    fi

    if [[ -f "${dir}/artisan" ]]; then
        ui_success "artisan: Found"
    else
        ui_warn "artisan: Not found"
    fi

    if [[ -f "${dir}/.env" ]]; then
        echo ""
        ui_subheader "Database configuration"
        local db_conn db_host db_port db_db db_user

        db_conn=$(grep -E '^DB_CONNECTION=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_host=$(grep -E '^DB_HOST=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_port=$(grep -E '^DB_PORT=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_db=$(grep -E '^DB_DATABASE=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_user=$(grep -E '^DB_USERNAME=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")

        ui_table_row "Connection" "${db_conn:-<not set>}"
        ui_table_row "Host" "${db_host:-<not set>}"
        ui_table_row "Port" "${db_port:-<not set>}"
        ui_table_row "Database" "${db_db:-<not set>}"
        ui_table_row "Username" "${db_user:-<not set>}"

        if command -v mysql &>/dev/null && [[ -n "$db_db" && -n "$db_host" ]]; then
            echo ""
            ui_subheader "Database connectivity check"
            if mysql -h "$db_host" -P "${db_port:-3306}" -u "${db_user:-root}" \
               -e "SELECT 1;" "$db_db" &>/dev/null; then
                ui_success "Connection to '${db_db}'@'${db_host}:${db_port:-3306}': OK"
            else
                ui_fail "Connection to '${db_db}'@'${db_host}:${db_port:-3306}': FAILED"
                echo "  (credentials or database may not exist)"
            fi
        fi
    fi

    echo ""
    ui_subheader "Laravel Environment"

    local env_ok=1

    if [[ -f "${dir}/.env" ]]; then
        ui_success ".env: Present"
    else
        ui_fail ".env: Missing"
        env_ok=0
    fi

    if [[ -f "${dir}/.env" ]] && grep -qE '^APP_KEY=' "${dir}/.env" 2>/dev/null && \
       ! grep -qE '^APP_KEY=\s*$' "${dir}/.env" 2>/dev/null && \
       ! grep -qE '^APP_KEY="\s*"$' "${dir}/.env" 2>/dev/null && \
       ! grep -qE "^APP_KEY='\s*'$" "${dir}/.env" 2>/dev/null; then
        ui_success "APP_KEY: Set"
    else
        ui_fail "APP_KEY: Not set"
        env_ok=0
    fi

    if [[ -d "${dir}/vendor" ]]; then
        ui_success "vendor/: Present"
    else
        ui_fail "vendor/: Missing (run: composer install)"
        env_ok=0
    fi

    if [[ -f "${dir}/artisan" ]]; then
        ui_success "artisan: Present"
    else
        ui_fail "artisan: Missing"
        env_ok=0
    fi

    if command -v php &>/dev/null; then
        local php_ver
        php_ver=$(php -v | head -1 | awk '{print $2}' || echo "unknown")
        ui_table_row "PHP version" "$php_ver"
    else
        ui_warn "PHP: Not installed"
        env_ok=0
    fi

    if [[ -f "${dir}/composer.json" ]] && command -v php &>/dev/null; then
        local required_php
        required_php=$(grep -oP '"php"\s*:\s*"\K[^"]+' "${dir}/composer.json" 2>/dev/null || echo "")
        if [[ -n "$required_php" ]]; then
            ui_table_row "Required PHP" "$required_php"
        fi
    fi

    if [[ -f "${dir}/.env" ]] && command -v mysql &>/dev/null; then
        local db_conn db_host db_port db_db
        db_conn=$(grep -E '^DB_CONNECTION=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_host=$(grep -E '^DB_HOST=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_port=$(grep -E '^DB_PORT=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        db_db=$(grep -E '^DB_DATABASE=' "${dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
        if [[ -n "$db_db" && -n "$db_host" ]]; then
            if mysql -h "$db_host" -P "${db_port:-3306}" -u "${db_user:-root}" \
               -e "SELECT 1;" "$db_db" &>/dev/null; then
                ui_success "Database: Connected"
            else
                ui_fail "Database: Connection failed"
                env_ok=0
            fi
        else
            ui_warn "Database: Not configured"
        fi
    fi

    echo ""
    if (( env_ok )); then
        ui_success "Laravel Environment: OK"
    else
        ui_fail "Laravel Environment: Issues found"
    fi

    if [[ -f "${dir}/artisan" ]] && command -v php &>/dev/null; then
        echo ""
        ui_subheader "Migration status"
        cd "$dir" && php artisan migrate:status 2>/dev/null || ui_yellow "  (unable to run migrate:status)"
    fi

    echo ""
}
