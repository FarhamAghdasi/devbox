# modules/services.sh
# Service management layer for DevBox.
# All service state is derived from systemctl. No PID parsing, no state files.

set -euo pipefail

# ---- defaults (overridable via config/defaults.conf) ----
APACHE_CONF_DIR="${APACHE_CONF_DIR:-/etc/httpd/conf.d}"
PHPMYADMIN_CONF="${PHPMYADMIN_CONF:-phpMyAdmin.conf}"
PHPMYADMIN_URL_BASE="${PHPMYADMIN_URL_BASE:-http://localhost/phpmyadmin}"

# ---- internal helpers ----

_svc_unit() {
    case "$1" in
        apache|httpd) echo "${APACHE_SERVICE:-httpd}" ;;
        mysql|mariadb) echo "${MARIADB_SERVICE:-mariadb}" ;;
        *)            echo "$1" ;;
    esac
}

_svc_require_systemctl() {
    if ! command -v systemctl &>/dev/null; then
        ui_red "Error: systemctl not found. This tool requires systemd."
        return 1
    fi
}

# ---- public API ----

svc_is_installed() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    systemctl list-unit-files "${unit}.service" &>/dev/null
}

svc_is_active() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    systemctl is-active --quiet "${unit}.service"
}

svc_start() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    if ! svc_is_installed "$1"; then
        ui_red "Error: ${1} (${unit}) is not installed."
        echo "  Install with: sudo dnf install $(case "$1" in
            apache|httpd) echo "httpd" ;;
            mysql|mariadb) echo "mariadb-server" ;;
            *) echo "$1" ;;
        esac)"
        return 1
    fi
    if svc_is_active "$1"; then
        ui_yellow "${1} is already running."
        return 0
    fi
    ui_yellow "Starting" "${1}..."
    ${SUDO:-} systemctl start "${unit}.service"
    ui_success "${1} started."
}

svc_stop() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    if ! svc_is_installed "$1"; then
        ui_red "Error: ${1} (${unit}) is not installed."
        return 1
    fi
    if ! svc_is_active "$1"; then
        ui_yellow "${1} is already stopped."
        return 0
    fi
    ui_yellow "Stopping" "${1}..."
    ${SUDO:-} systemctl stop "${unit}.service"
    ui_success "${1} stopped."
}

svc_restart() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    if ! svc_is_installed "$1"; then
        ui_red "Error: ${1} (${unit}) is not installed."
        return 1
    fi
    ui_yellow "Restarting" "${1}..."
    ${SUDO:-} systemctl restart "${unit}.service"
    ui_success "${1} restarted."
}

svc_enable() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    if ! svc_is_installed "$1"; then
        ui_red "Error: ${1} (${unit}) is not installed."
        return 1
    fi
    ui_yellow "Enabling" "${1} at boot..."
    ${SUDO:-} systemctl enable "${unit}.service"
    ui_success "${1} enabled at boot."
}

svc_disable() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")
    if ! svc_is_installed "$1"; then
        ui_red "Error: ${1} (${unit}) is not installed."
        return 1
    fi
    ui_yellow "Disabling" "${1} at boot..."
    ${SUDO:-} systemctl disable "${unit}.service"
    ui_success "${1} disabled at boot."
}

svc_status() {
    _svc_require_systemctl || return 1
    local unit
    unit=$(_svc_unit "$1")

    if ! svc_is_installed "$1"; then
        ui_warn "${1}: Not installed"
        echo "  Install with: sudo dnf install $(case "$1" in
            apache|httpd) echo "httpd" ;;
            mysql|mariadb) echo "mariadb-server" ;;
            *) echo "$1" ;;
        esac)"
        return 1
    fi

    if svc_is_active "$1"; then
        ui_status_badge "$1" "Running"
    else
        ui_status_badge "$1" "Stopped"
    fi

    # Port detection (best-effort)
    case "$1" in
        apache|httpd)
            local port
            port=$(grep -E '^[[:space:]]*Listen[[:space:]]+[0-9]+' "${APACHE_CONF_DIR}/httpd.conf" 2>/dev/null \
                   | head -1 \
                   | awk '{print $2}' \
                   || echo "80")
            ui_table_row "Port" "$port"
            ;;
        mysql|mariadb)
            ui_table_row "Port" "3306"
            ;;
    esac
    echo ""
}

svc_phpmyadmin_status() {
    local conf="${APACHE_CONF_DIR}/${PHPMYADMIN_CONF}"
    if [[ ! -f "$conf" ]]; then
        ui_warn "phpMyAdmin: Not configured"
        echo "  Install with: sudo dnf install phpMyAdmin"
        echo ""
        return
    fi

    if svc_is_active apache; then
        ui_success "phpMyAdmin: Available"
        ui_table_row "URL" "${PHPMYADMIN_URL_BASE}"
    else
        ui_warn "phpMyAdmin: Config present, but Apache is stopped"
        ui_table_row "URL" "${PHPMYADMIN_URL_BASE} (unavailable)"
    fi
    echo ""
}

svc_all() {
    echo ""
    ui_subheader "Service Status"
    # Intentionally continue showing all services even if one is not installed
    svc_status apache || true
    svc_status mysql || true
    ui_bold "PHP:"
    if command -v php &>/dev/null; then
        local ver
        ver=$(php -v | head -1 | awk '{print $2}')
        ui_table_row "Version" "$ver"
    else
        ui_warn "Not installed"
        echo "  Install with: sudo dnf install php-cli"
    fi
    echo ""
    ui_bold "phpMyAdmin:"
    svc_phpmyadmin_status
}
