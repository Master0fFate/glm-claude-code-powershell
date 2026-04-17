#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
NODE_MIN_VERSION=18
CLAUDE_PACKAGE="@anthropic-ai/claude-code"
API_BASE_URL="https://api.z.ai/api/anthropic"
API_KEY_URL="https://z.ai/manage-apikey/apikey-list"
API_TIMEOUT_MS="3000000"
CONFIG_DIR="$HOME/.claude"

log_info() {
  printf '🔹 %s\n' "$1"
}

log_success() {
  printf '✅ %s\n' "$1"
}

log_error() {
  printf '❌ %s\n' "$1" >&2
}

ensure_dir_exists() {
  mkdir -p "$1"
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

install_nodejs_macos() {
  if ! has_command brew; then
    log_error "Homebrew is required on macOS to install Node.js automatically."
    log_error "Install Homebrew first: https://brew.sh/"
    exit 1
  fi

  log_info "Installing Node.js via Homebrew..."
  brew install node
}

install_nodejs_linux() {
  log_info "Installing Node.js on Linux..."

  if has_command apt-get; then
    sudo apt-get update
    sudo apt-get install -y nodejs npm
    return
  fi

  if has_command dnf; then
    sudo dnf install -y nodejs npm
    return
  fi

  if has_command yum; then
    sudo yum install -y nodejs npm
    return
  fi

  if has_command pacman; then
    sudo pacman -Sy --noconfirm nodejs npm
    return
  fi

  if has_command zypper; then
    sudo zypper --non-interactive install nodejs npm
    return
  fi

  log_error "Unsupported Linux package manager for automatic Node.js installation."
  log_error "Please install Node.js >= ${NODE_MIN_VERSION} manually and rerun."
  exit 1
}

install_nodejs() {
  case "$(uname -s)" in
    Darwin)
      install_nodejs_macos
      ;;
    Linux)
      install_nodejs_linux
      ;;
    *)
      log_error "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac
}

check_nodejs() {
  if has_command node; then
    local node_version
    node_version="$(node -v || true)"
    if [[ "$node_version" =~ ^v([0-9]+)\. ]]; then
      local major="${BASH_REMATCH[1]}"
      if (( major >= NODE_MIN_VERSION )); then
        log_success "Node.js is already installed: ${node_version}"
        return
      fi
      log_info "Node.js ${node_version} is installed but version < ${NODE_MIN_VERSION}. Upgrading..."
      install_nodejs
      return
    fi
  fi

  log_info "Node.js not found. Installing..."
  install_nodejs
}

install_claude_code() {
  if has_command claude; then
    log_success "Claude Code is already installed: $(claude --version)"
    return
  fi

  log_info "Installing Claude Code..."
  npm install -g "$CLAUDE_PACKAGE"
  log_success "Claude Code installed successfully"
}

configure_claude_json() {
  node <<'NODE'
const os = require("os");
const fs = require("fs");
const path = require("path");

const homeDir = os.homedir();
const filePath = path.join(homeDir, ".claude.json");

let content = {};
if (fs.existsSync(filePath)) {
  try {
    content = JSON.parse(fs.readFileSync(filePath, "utf-8"));
  } catch (_) {
    content = {};
  }
}

content.hasCompletedOnboarding = true;
fs.writeFileSync(filePath, JSON.stringify(content, null, 2), "utf-8");
NODE
}

configure_claude() {
  log_info "Configuring Claude Code..."
  printf '   You can get your API key from: %s\n' "$API_KEY_URL"
  read -r -s -p "🔑 Please enter your Z.AI API key: " api_key
  printf '\n'

  if [[ -z "${api_key// }" ]]; then
    log_error "API key cannot be empty. Please run the script again."
    exit 1
  fi

  ensure_dir_exists "$CONFIG_DIR"

  ANTHROPIC_AUTH_TOKEN="$api_key" \
  ANTHROPIC_BASE_URL="$API_BASE_URL" \
  API_TIMEOUT_MS="$API_TIMEOUT_MS" \
  node <<'NODE'
const fs = require("fs");
const path = require("path");
const os = require("os");

const homeDir = os.homedir();
const configDir = path.join(homeDir, ".claude");
const filePath = path.join(configDir, "settings.json");

if (!fs.existsSync(configDir)) {
  fs.mkdirSync(configDir, { recursive: true });
}

let content = {};
if (fs.existsSync(filePath)) {
  try {
    const raw = fs.readFileSync(filePath, "utf-8");
    if (raw.trim()) {
      content = JSON.parse(raw);
    }
  } catch (_) {
    content = {};
  }
}

const env = { ...(content.env || {}) };
env.ANTHROPIC_AUTH_TOKEN = process.env.ANTHROPIC_AUTH_TOKEN || "";
env.ANTHROPIC_BASE_URL = process.env.ANTHROPIC_BASE_URL || "";
env.API_TIMEOUT_MS = process.env.API_TIMEOUT_MS || "3000000";

const newContent = { ...content, env };
fs.writeFileSync(filePath, JSON.stringify(newContent, null, 2), "utf-8");
console.log("Configuration written successfully");
NODE

  log_success "Claude Code configured successfully"
}

main() {
  printf '🚀 Starting %s\n' "$SCRIPT_NAME"

  check_nodejs
  install_claude_code
  configure_claude_json
  configure_claude

  printf '\n'
  log_success "🎉 Installation completed successfully!"
  printf '\n🚀 You can now start using Claude Code with:\n   claude\n\n'
  printf 'Note: You may need to restart your terminal for changes to take effect.\n'
}

main "$@"
