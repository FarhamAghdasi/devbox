# modules/phpmyadmin.sh
# phpMyAdmin setup for DevBox.
# Creates a dedicated 'phpmyadmin' MariaDB user with a random password
# and grants the minimal privileges phpMyAdmin needs.

set -euo pipefail

PHPMYADMIN_DB_USER="${PHPMYADMIN_DB_USER:-phpmyadmin}"
PHPMYADMIN_DB_PASS="${PHPMYADMIN_DB_PASS:-}"

# Minimal privileges phpMyAdmin needs to function.
# Does NOT include GRANT OPTION, SUPER, or FILE.
_PHPMYADMIN_PRIV_LIST="SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,ALTER,CREATE TEMPORARY TABLES,SHOW VIEW,CREATE ROUTINE,ALTER ROUTINE,EXECUTE"

_db_mysql_root() {
    # On Fedora, MariaDB root uses unix_socket by default.
    # Regular users must use sudo to run mysql as root.
    if ${SUDO:-} mysql -u root -N -e "SELECT 1;" &>/dev/null; then
        ${SUDO:-} mysql -u root "$@"
    elif mysql -u root -N -e "SELECT 1;" &>/dev/null; then
        mysql -u root "$@"
    else
        return 1
    fi
}

_db_mysql_root_silent() {
    _db_mysql_root "$@" 2>/dev/null
}

_db_mysql_root_verbose() {
    ui_yellow "Running: mysql -u root $*"
    if ${SUDO:-} mysql -u root "$@" 2>&1; then
        return 0
    elif mysql -u root "$@" 2>&1; then
        return 0
    else
        return 1
    fi
}

_db_mysql_root_quiet() {
    if ${SUDO:-} mysql -u root "$@" &>/dev/null; then
        return 0
    elif mysql -u root "$@" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

phpmyadmin_setup() {
    check_deps mysql || return 1

    ui_header "phpMyAdmin Setup"
    echo ""
    ui_yellow "This will create a dedicated '${PHPMYADMIN_DB_USER}' MariaDB user"
    ui_yellow "with a random password and minimal privileges for phpMyAdmin."
    echo ""

    # Ensure MariaDB is running
    local mariadb_unit
    mariadb_unit=$(_svc_unit "mysql")
    if ! systemctl is-active --quiet "${mariadb_unit}.service"; then
        ui_yellow "MariaDB is not running. Starting it now..."
        if ${SUDO:-} systemctl start "${mariadb_unit}.service"; then
            ui_success "MariaDB started."
        else
            ui_red "Error: Failed to start MariaDB."
            echo "  Start it manually: sudo systemctl start ${mariadb_unit}"
            return 1
        fi
    fi

    read -p "Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        return 0
    fi

    # Determine password: use env if set, otherwise generate random
    local password="${PHPMYADMIN_DB_PASS:-}"
    local password_source="generated"
    if [[ -z "$password" ]]; then
        password=$(openssl rand -base64 12 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null | head -c 16)
        if [[ -z "$password" ]]; then
            password="DevBox_$(date +%s)_$$"
        fi
    else
        password_source="env"
    fi

    # Check if user already exists
    local user_exists
    user_exists=$(_db_mysql_root_silent -N -e "SELECT COUNT(*) FROM mysql.user WHERE user='${PHPMYADMIN_DB_USER}' AND host='localhost';" 2>/dev/null || echo "0")

    if [[ "$user_exists" == "1" ]]; then
        ui_yellow "User '${PHPMYADMIN_DB_USER}'@'localhost' already exists."
        read -p "Drop and recreate? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            _db_mysql_root -e "DROP USER '${PHPMYADMIN_DB_USER}'@'localhost';" 2>/dev/null || true
            echo "Dropped existing user."
        else
            echo "Using existing user. Password will NOT be changed."
            ui_header "phpMyAdmin Credentials"
            echo ""
            ui_success "phpMyAdmin is ready to use."
            ui_table_row "User" "${PHPMYADMIN_DB_USER}"
            ui_table_row "Password" "(existing - unchanged)"
            ui_table_row "URL" "http://localhost/phpmyadmin"
            echo ""
            ui_yellow "Open phpMyAdmin and log in with these credentials."
            echo ""
            return 0
        fi
    fi

    # Create user with password (quiet to avoid leaking password in output)
    echo ""
    ui_yellow "Creating user '${PHPMYADMIN_DB_USER}'@'localhost'..."
    if _db_mysql_root_quiet -e "CREATE USER '${PHPMYADMIN_DB_USER}'@'localhost' IDENTIFIED BY '${password}';" 2>/dev/null; then
        ui_success "User created."
    else
        ui_red "Error: Failed to create user."
        return 1
    fi

    # Grant privileges on all databases
    echo ""
    ui_yellow "Granting privileges..."
    if _db_mysql_root_verbose -e "GRANT ${_PHPMYADMIN_PRIV_LIST} ON *.* TO '${PHPMYADMIN_DB_USER}'@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null; then
        ui_success "Privileges granted."
    else
        ui_red "Error: Failed to grant privileges."
        return 1
    fi

    # Clean up AllowNoPassword from Apache config if present
    echo ""
    ui_yellow "Cleaning up Apache config..."
    local apache_conf="${APACHE_CONF_DIR:-/etc/httpd/conf.d}/${PHPMYADMIN_CONF:-phpMyAdmin.conf}"
    if [[ -f "$apache_conf" ]]; then
        if grep -q "AllowNoPassword" "$apache_conf" 2>/dev/null; then
            sed -i '/AllowNoPassword/d' "$apache_conf" 2>/dev/null || true
            ui_success "Removed AllowNoPassword from Apache config."
        else
            ui_yellow "No AllowNoPassword directive found. Apache config is clean."
        fi

        # Restart Apache to apply changes
        echo ""
        ui_yellow "Restarting Apache..."
        if ${SUDO:-} systemctl restart httpd; then
            ui_success "Apache restarted."
        else
            ui_yellow "Warning: Could not restart Apache. Restart it manually: sudo systemctl restart httpd"
        fi
    else
        ui_yellow "Warning: phpMyAdmin Apache config not found at ${apache_conf}"
    fi

    echo ""
    ui_header "Setup Complete"
    echo ""
    ui_success "phpMyAdmin is now configured."
    ui_table_row "User" "${PHPMYADMIN_DB_USER}"
    if [[ "$password_source" == "env" ]]; then
        ui_table_row "Password" "(set via .env)"
    else
        ui_table_row "Password" "${password}"
    fi
    ui_table_row "URL" "http://localhost/phpmyadmin"
    echo ""
    if [[ "$password_source" == "generated" ]]; then
        ui_yellow "Save this password — it will not be shown again."
    fi
    echo ""
}

phpmyadmin_info() {
    ui_header "phpMyAdmin Configuration"
    echo ""
    ui_bold "Current settings:"
    ui_table_row "phpMyAdmin DB user" "${PHPMYADMIN_DB_USER}"
    ui_table_row "URL" "http://localhost/phpmyadmin"
    echo ""

    # Check if user exists in MariaDB
    local user_exists
    user_exists=$(_db_mysql_root_silent -N -e "SELECT COUNT(*) FROM mysql.user WHERE user='${PHPMYADMIN_DB_USER}' AND host='localhost';" 2>/dev/null || echo "0")
    if [[ "$user_exists" == "1" ]]; then
        ui_success "MariaDB user '${PHPMYADMIN_DB_USER}'@'localhost' exists."
        ui_yellow "Run 'devbox phpmyadmin setup' to see or reset the password."
    else
        ui_warn "MariaDB user '${PHPMYADMIN_DB_USER}'@'localhost' not found."
        echo "  Run: devbox phpmyadmin setup"
    fi
    echo ""
}
