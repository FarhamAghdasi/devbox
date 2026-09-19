# DevBox

Lightweight Laragon-like CLI manager for Fedora Linux. Manages Apache, MariaDB, PHP, phpMyAdmin, and Laravel projects natively via systemd.

No Docker. No containers. Just Bash and systemd.

## What DevBox Is

DevBox is a native Fedora development environment manager. It provides a single Bash script to start, stop, and inspect local web stack services, manage MariaDB databases, validate Laravel projects, and inspect system information.

## Why It Exists

Laragon is popular on Windows but unavailable on Linux. DevBox brings similar convenience to Fedora using only the tools Fedora already provides: Bash, systemd, and the standard LAMP stack packages.

## Features

- Start/stop/restart Apache and MariaDB via systemd
- Individual service management (`devbox apache start`, `devbox mysql status`)
- Create, drop, backup, restore, and inspect database sizes
- phpMyAdmin setup with a dedicated MariaDB user (password never leaked to output)
- Laravel project detection and environment validation
- System, PHP, and project information
- Interactive menu and full CLI mode
- Optional configuration via `config/defaults.conf` and `.env`
- `devbox --quiet` for scripting
- `devbox self-update` when installed from git
- `devbox uninstall` removes only DevBox, not your data
- No background daemon, no Docker, no containers

## Requirements

- Fedora Linux (primary supported platform)
- Bash 4.0 or later
- systemd
- The following packages (install as needed):
  - `httpd`
  - `mariadb-server`
  - `php-cli`
  - `php-mysqlnd`
  - `phpMyAdmin` (optional)
  - `composer` (optional)
  - `nodejs` and `npm` (optional)

## Installation

```bash
cd devbox
chmod +x install.sh
./install.sh
```

Ensure `~/.local/bin` is in your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
devbox --help
```

## Usage

### Interactive Menu

```bash
devbox
```

```
================================
 DevBox Laravel Manager
================================

 1) Start all services
 2) Stop all services
 3) Restart all services
 4) Service status
 5) phpMyAdmin setup
 6) Enable/Disable service
 7) Database information
 8) PHP information
 9) Laravel project check
10) System information
11) Project information
 0) Exit
```

### CLI Mode

```bash
devbox start
devbox stop
devbox restart
devbox status

devbox apache start
devbox apache stop
devbox apache restart
devbox apache status
devbox apache enable
devbox apache disable

devbox mysql start
devbox mysql stop
devbox mysql restart
devbox mysql status
devbox mysql enable
devbox mysql disable

devbox phpmyadmin status
devbox phpmyadmin setup

devbox info
devbox php info
devbox project-info [path]

devbox laravel-check

devbox db info
devbox db list
devbox db create myproject
devbox db drop myproject
devbox db backup myproject ./backup.sql
devbox db restore ./backup.sql myproject
devbox db size myproject

devbox --version
devbox --help
devbox -q status
devbox uninstall
devbox self-update
```

## Command Reference

| Command | Description |
|---|---|
| `devbox` | Interactive menu |
| `devbox start` | Start Apache + MariaDB |
| `devbox stop` | Stop Apache + MariaDB |
| `devbox restart` | Restart Apache + MariaDB |
| `devbox status` | Show all service status |
| `devbox apache <action>` | Manage httpd |
| `devbox mysql <action>` | Manage mariadb |
| `devbox phpmyadmin status` | Show phpMyAdmin status |
| `devbox phpmyadmin setup` | Configure phpMyAdmin database user |
| `devbox info` | System + stack info |
| `devbox php info` | PHP details |
| `devbox project-info [path]` | Project information |
| `devbox laravel-check` | Validate Laravel project |
| `devbox db info` | Database server information |
| `devbox db list` | List databases |
| `devbox db create <name>` | Create database |
| `devbox db drop <name>` | Drop database |
| `devbox db backup <name> [file]` | Backup database |
| `devbox db restore <file> [name]` | Restore database |
| `devbox db size <name>` | Show database and table sizes |
| `devbox --version` | Show DevBox version |
| `devbox --help` | Show help |
| `devbox -q` / `--quiet` | Suppress non-error output |
| `devbox uninstall` | Remove DevBox from this system |
| `devbox self-update` | Update DevBox from git (if installed from source) |

## Configuration

DevBox uses two optional configuration mechanisms. Both are optional; Fedora defaults work without any configuration file.

### 1. `config/defaults.conf`

Override defaults in `config/defaults.conf` (after installation: `~/.local/share/devbox/config/defaults.conf`):

```bash
DB_ROOT_USER=root
DEFAULT_DB_HOST=127.0.0.1
DEFAULT_DB_PORT=3306

APACHE_SERVICE=httpd
MARIADB_SERVICE=mariadb

APACHE_CONF_DIR=/etc/httpd/conf.d

PHPMYADMIN_CONF=phpMyAdmin.conf
PHPMYADMIN_URL_BASE=http://localhost/phpmyadmin
```

### 2. `.env` (optional)

Copy `env.example` to `.env` in the DevBox installation directory (e.g. `~/.local/share/devbox/.env`) for environment-variable-style configuration. Values in `.env` override `defaults.conf`.

```bash
# Example: set a fixed phpMyAdmin password instead of generating a random one
PHPMYADMIN_DB_PASS=mysecurepassword
```

`.env` is ignored by git by default. Do not store production secrets in it.

## Security Considerations

- **No passwords are written by DevBox.** DevBox does not write passwords to logs, terminal output, or any file unless you explicitly set them in `.env`.
- **`.env` is optional and git-ignored.** If you create `.env` (from `env.example`) to set a fixed phpMyAdmin password, that file stays local and is not committed.
- **phpMyAdmin passwords are not leaked.** The `CREATE USER` statement runs through a quiet helper that does not echo the command or password to the terminal.
- On Fedora, MariaDB root uses `unix_socket` authentication by default. No password is required when running as the system root user via `sudo`.
- phpMyAdmin setup generates a random password interactively and displays it once. If `PHPMYADMIN_DB_PASS` is set in `.env`, the password is used but not displayed.
- Database names are validated against MySQL identifier rules before use.
- Destructive actions (`db drop`, `db restore`) require explicit `yes` confirmation.
- `.env` values from Laravel projects are never printed. Only presence/absence is reported.

## Architecture

```
devbox/
├── devbox                  # Main entry point (CLI dispatch + interactive menu)
├── modules/
│   ├── ui.sh               # Colors, headers, status badges, table rows
│   ├── services.sh         # systemd service management
│   ├── database.sh         # MariaDB/database operations
│   ├── info.sh             # System and stack information
│   ├── laravel.sh          # Laravel detection and validation
│   └── phpmyadmin.sh       # phpMyAdmin setup
├── config/
│   ├── defaults.conf       # Overridable defaults
│   └── env.example         # Optional .env template
├── install.sh              # Install script
├── uninstall.sh            # Uninstall script
├── test.sh                 # Smoke and behavior tests
├── .gitignore              # Ignores .env and backups
└── README.md
```

## Supported Platform

Fedora Linux is the primary and only supported platform. DevBox relies on Fedora conventions:
- `httpd` as the Apache service name
- `mariadb` as the MariaDB service name
- `unix_socket` authentication for MariaDB root
- `systemctl` as the service manager

## Examples

### Start services and verify

```bash
devbox start
devbox status
```

### Create a new project database

```bash
devbox db create myproject
```

### Check database sizes

```bash
devbox db size myproject
```

### Back up before a risky migration

```bash
devbox db backup myproject ./backup_$(date +%Y%m%d).sql
```

### Check a Laravel project

```bash
cd ~/projects/myapp
devbox laravel-check
```

### Inspect the local environment

```bash
devbox info
devbox php info
devbox db info
```

### Quiet mode for scripts

```bash
devbox -q status
```

### Update DevBox from git

```bash
devbox self-update
```

### Remove DevBox

```bash
devbox uninstall
```

## Testing

Run the test suite from the repo root:

```bash
bash test.sh
```

Tests cover syntax, CLI parsing, database name validation, destructive-action confirmations, configuration loading, Laravel detection, password safety, and quiet mode.

## Limitations

- Fedora Linux only
- No Docker, containers, or remote server support
- No background daemon
- No GUI or web dashboard
- No cloud synchronization
- No telemetry or analytics
- phpMyAdmin setup creates a user with broad privileges on all databases; adjust as needed for production-like environments

## License

MIT
