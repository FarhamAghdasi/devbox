#!/usr/bin/env bash
# uninstall.sh — Remove DevBox from this system.
# This does NOT remove your databases, Laravel projects, or system packages.

set -euo pipefail

INSTALL_BIN_DIR="${HOME}/.local/bin"
INSTALL_DATA_DIR="${HOME}/.local/share/devbox"
INSTALL_PATH="${INSTALL_BIN_DIR}/devbox"

echo "This will remove DevBox from your system."
echo ""
echo "The following will be removed:"
echo "  - ${INSTALL_PATH}"
echo "  - ${INSTALL_DATA_DIR}"
echo ""
echo "The following will NOT be touched:"
echo "  - Databases"
echo "  - Laravel projects"
echo "  - Apache configuration"
echo "  - MariaDB / PHP installations"
echo ""

read -p "Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

removed=0

if [[ -L "$INSTALL_PATH" ]] || [[ -f "$INSTALL_PATH" ]]; then
    rm -f "$INSTALL_PATH"
    echo "Removed: ${INSTALL_PATH}"
    removed=$((removed + 1))
else
    echo "Symlink not found at ${INSTALL_PATH}"
fi

if [[ -d "$INSTALL_DATA_DIR" ]]; then
    if [[ -f "${INSTALL_DATA_DIR}/.env" ]]; then
        echo "Warning: ${INSTALL_DATA_DIR}/.env exists and will be removed."
        echo "  This may contain your phpMyAdmin password or other custom settings."
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi
    rm -rf "$INSTALL_DATA_DIR"
    echo "Removed: ${INSTALL_DATA_DIR}"
    removed=$((removed + 1))
else
    echo "Data directory not found at ${INSTALL_DATA_DIR}"
fi

echo ""
if (( removed > 0 )); then
    echo "DevBox uninstalled."
else
    echo "Nothing to remove."
fi
