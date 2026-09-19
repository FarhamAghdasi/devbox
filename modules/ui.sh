# modules/ui.sh
# UI helpers: colors, separators, icons.
# Disables colors automatically when stdout is not a terminal.

set -euo pipefail

# Detect terminal
if [[ -t 1 ]]; then
    _UI_HAS_TTY=1
else
    _UI_HAS_TTY=0
fi

ui_color() {
    local color="$1"
    shift
    if (( QUIET )); then
        return
    fi
    if (( _UI_HAS_TTY )); then
        printf '%b' "$color"
        printf '%s' "$*"
        printf '%b' "${C_RESET:-}"
    else
        printf '%s' "$*"
    fi
}

ui_bold()      { ui_color "${C_BOLD:-}" "$*"; echo ""; }
ui_red()       { ui_color "${C_RED:-}" "$*"; echo ""; }
ui_green()     { ui_color "${C_GREEN:-}" "$*"; echo ""; }
ui_yellow()    { ui_color "${C_YELLOW:-}" "$*"; echo ""; }
ui_cyan()      { ui_color "${C_CYAN:-}" "$*"; echo ""; }
ui_dim()       { ui_color "${C_DIM:-}" "$*"; echo ""; }
ui_success()   { (( QUIET )) && return; ui_green "✓ $*"; }
ui_fail()      { (( QUIET )) && return; ui_red "✗ $*"; }
ui_warn()      { (( QUIET )) && return; ui_yellow "! $*"; }

ui_header() {
    (( QUIET )) && return
    echo ""
    ui_cyan "========================================"
    ui_bold " $*"
    ui_cyan "========================================"
    echo ""
}

ui_subheader() {
    (( QUIET )) && return
    echo ""
    ui_cyan "----------------------------------------"
    ui_bold " $*"
    ui_cyan "----------------------------------------"
    echo ""
}

ui_separator() {
    (( QUIET )) && return
    ui_cyan "----------------------------------------"
    echo ""
}

ui_status_badge() {
    local name="$1" status="$2"
    case "$status" in
        Running)    ui_success "${name}: ${status}" ;;
        Stopped)    ui_fail "${name}: ${status}" ;;
        *)         ui_warn "${name}: ${status}" ;;
    esac
}

ui_table_row() {
    local key="$1" val="$2"
    printf "  %-18s %s\n" "$key" "$val"
}

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
