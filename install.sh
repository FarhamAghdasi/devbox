#!/usr/bin/env bash
# install.sh — Install DevBox to ~/.local/share/devbox and symlink to ~/.local/bin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN_DIR="${HOME}/.local/bin"
INSTALL_DATA_DIR="${HOME}/.local/share/devbox"
INSTALL_PATH="${INSTALL_BIN_DIR}/devbox"

# 1. Verify Bash version
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "Error: Bash is required to run this installer." >&2
    exit 1
fi
bash_major="${BASH_VERSION%%.*}"
if (( bash_major < 4 )); then
    echo "Error: Bash 4.0 or later is required (found ${BASH_VERSION})." >&2
    exit 1
fi

# 2. Ensure directories exist
mkdir -p "$INSTALL_BIN_DIR"
mkdir -p "$INSTALL_DATA_DIR"

# 3. Copy full project tree (devbox, modules/, config/)
if [[ ! -f "${SCRIPT_DIR}/devbox" ]]; then
    echo "Error: devbox entry script not found at ${SCRIPT_DIR}/devbox" >&2
    exit 1
fi

cp -rf "${SCRIPT_DIR}/modules" "${INSTALL_DATA_DIR}/"
cp -rf "${SCRIPT_DIR}/config" "${INSTALL_DATA_DIR}/"
cp -f "${SCRIPT_DIR}/devbox" "${INSTALL_DATA_DIR}/devbox"
chmod +x "${INSTALL_DATA_DIR}/devbox"

# 3b. Copy env.example if present
if [[ -f "${SCRIPT_DIR}/env.example" ]]; then
    cp -f "${SCRIPT_DIR}/env.example" "${INSTALL_DATA_DIR}/env.example"
fi

# 4. Create symlink in ~/.local/bin
ln -sf "${INSTALL_DATA_DIR}/devbox" "$INSTALL_PATH"
echo "Installed devbox to ${INSTALL_PATH}"
echo "Data directory: ${INSTALL_DATA_DIR}"

# 5. Check systemctl availability
if ! command -v systemctl &>/dev/null; then
    echo "Warning: systemctl not found. DevBox requires systemd." >&2
fi

# 6. PATH check
case ":$PATH:" in
    *":${INSTALL_BIN_DIR}:"*) ;;
    *)
        echo ""
        echo "NOTE: ${INSTALL_BIN_DIR} is not in your PATH."
        echo "Add this to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

echo ""
echo "Installation complete."
echo ""
echo "Optional: copy env.example to .env for persistent configuration:"
echo "  cp config/env.example .env   # or edit ${INSTALL_DATA_DIR}/env.example"
echo ""
echo "Recommended next steps:"
echo "  1. Ensure PATH includes ~/.local/bin"
echo "  2. Install required packages:"
echo "       sudo dnf install httpd mariadb-server php-cli php-mysqlnd phpMyAdmin composer"
echo "  3. Start and enable services:"
echo "       sudo systemctl enable --now httpd mariadb"
echo "  4. Verify installation:"
echo "       devbox info"
echo ""
echo "Run 'devbox --help' for usage."
