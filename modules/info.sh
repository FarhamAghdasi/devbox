# modules/info.sh
# System and stack information for DevBox.

set -euo pipefail

info_system() {
    if [[ -f /etc/fedora-release ]]; then
        local ver
        ver=$(cat /etc/fedora-release | grep -oP '\d+' | head -1 || echo "?")
        ui_table_row "OS" "Fedora ${ver}"
    else
        local pretty
        pretty=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo "Unknown")
        ui_table_row "OS" "$pretty"
    fi
    ui_table_row "Kernel" "$(uname -r)"
    ui_table_row "Arch" "$(uname -m)"
}

info_php() {
    if command -v php &>/dev/null; then
        local ver
        ver=$(php -v | head -1 | awk '{print $2}')
        ui_table_row "PHP" "$ver"
        ui_table_row "Binary" "$(command -v php)"
        local loaded
        loaded=$(php --ini 2>/dev/null | grep -E "^Loaded Configuration File" | awk -F'=> ' '{print $2}' || echo "")
        if [[ -n "$loaded" ]]; then
            ui_table_row "Configuration" "$loaded"
        fi
        local exts
        exts=$(php -m 2>/dev/null | grep -E '^(mysqli|mysql|mbstring|curl|openssl|json|tokenizer|pdo_mysql)$' | tr '\n' ' ' || echo "")
        if [[ -n "$exts" ]]; then
            ui_table_row "Extensions" "$exts"
        fi
    else
        ui_warn "PHP: Not installed"
    fi
}

info_composer() {
    if command -v composer &>/dev/null; then
        ui_table_row "Composer" "$(composer --version 2>/dev/null | awk '{print $3}')"
    else
        ui_warn "Composer: Not installed"
    fi
}

info_node() {
    if command -v node &>/dev/null; then
        ui_table_row "Node.js" "$(node --version)"
    else
        ui_warn "Node.js: Not installed"
    fi
}

info_mariadb() {
    if command -v mysql &>/dev/null; then
        local ver
        ver=$(mysql --version 2>/dev/null | awk '{print $3}' | cut -d, -f1 || echo "unknown")
        ui_table_row "MariaDB" "$ver"
    elif command -v mariadb &>/dev/null; then
        ui_table_row "MariaDB" "$(mariadb --version | awk '{print $3}')"
    else
        ui_warn "MariaDB: Not installed"
    fi
}

info_apache() {
    if command -v httpd &>/dev/null; then
        local ver
        ver=$(httpd -v | grep 'Server version' | awk -F: '{print $2}' | xargs || echo "unknown")
        ui_table_row "Apache" "$ver"
    else
        ui_warn "Apache: Not installed"
    fi
}

info_ram() {
    if command -v free &>/dev/null; then
        local line total used
        line=$(free -h | grep '^Mem:')
        total=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        ui_table_row "RAM" "${used} / ${total}"
    else
        ui_warn "RAM: Unable to determine"
    fi
}

info_disk() {
    if command -v df &>/dev/null; then
        local line total used pct
        line=$(df -h / | tail -1)
        total=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        pct=$(echo "$line" | awk '{print $5}')
        ui_table_row "Disk (/)" "${used} / ${total} (${pct})"
    else
        ui_warn "Disk: Unable to determine"
    fi
}

info_services() {
    ui_bold "Active services:"
    if command -v systemctl &>/dev/null; then
        local count
        count=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || echo "0")
        ui_table_row "Running services" "$count"
    else
        ui_warn "systemctl not available"
    fi
}

project_info() {
    ui_header "Project Information"
    echo ""

    local dir="${1:-.}"
    ui_table_row "Project path" "$(cd "$dir" && pwd)"

    if [[ -f "${dir}/composer.json" ]]; then
        ui_bold "Project type:"
        if grep -q '"laravel/framework' "${dir}/composer.json" 2>/dev/null; then
            ui_table_row "Framework" "Laravel"
        else
            ui_table_row "Framework" "PHP (composer)"
        fi

        if command -v composer &>/dev/null; then
            ui_table_row "Composer" "$(composer --version 2>/dev/null | awk '{print $3}')"
        else
            ui_warn "Composer: Not installed"
        fi
    elif [[ -f "${dir}/artisan" ]] && [[ -f "${dir}/.env" ]]; then
        ui_bold "Project type:"
        ui_table_row "Framework" "Laravel (detected via artisan + .env)"
    fi

    if command -v php &>/dev/null; then
        ui_table_row "PHP" "$(php -v | head -1 | awk '{print $2}')"
    else
        ui_warn "PHP: Not installed"
    fi

    if command -v node &>/dev/null; then
        ui_table_row "Node.js" "$(node --version)"
    else
        ui_warn "Node.js: Not installed"
    fi

    if command -v npm &>/dev/null; then
        ui_table_row "npm" "$(npm --version)"
    else
        ui_warn "npm: Not installed"
    fi

    if command -v git &>/dev/null && [[ -d "${dir}/.git" ]]; then
        echo ""
        ui_bold "Git status:"
        local branch
        branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "unknown")
        ui_table_row "Branch" "$branch"
        local changes
        changes=$(git -C "$dir" status --short 2>/dev/null | wc -l || echo "0")
        ui_table_row "Changed files" "$changes"
    fi

    echo ""
}

info_all() {
    ui_header "DevBox System Information"
    echo ""
    info_system
    echo ""
    ui_bold "Stack versions:"
    info_apache
    info_mariadb
    info_php
    info_composer
    info_node
    echo ""
    ui_bold "Resources:"
    info_ram
    info_disk
    echo ""
    info_services
    echo ""
}
