#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
NODE_TARGET_VERSION=22
NVM_INSTALL_VERSION="v0.40.3"
CLAUDE_PACKAGE="@anthropic-ai/claude-code"
API_BASE_URL="https://api.z.ai/api/anthropic"
API_KEY_URL="https://z.ai/manage-apikey/apikey-list"
API_TIMEOUT_MS="3000000"
CONFIG_DIR="$HOME/.claude"
API_KEY_INPUT=""

log_info() {
  printf '🔹 %s\n' "$1"
}

log_success() {
  printf '✅ %s\n' "$1"
}

log_error() {
  printf '❌ %s\n' "$1" >&2
}

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [--api-key <key>]

Options:
  --api-key <key>   Provide Z.AI API key non-interactively
  --api-key=<key>   Provide Z.AI API key non-interactively
  -h, --help        Show this help message

Environment variables:
  ZAI_API_KEY or ANTHROPIC_AUTH_TOKEN can also provide the API key.
USAGE
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

ensure_dir_exists() {
  mkdir -p "$1"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --api-key)
        shift
        if [[ $# -eq 0 ]]; then
          log_error "Missing value for --api-key"
          exit 1
        fi
        API_KEY_INPUT="$1"
        ;;
      --api-key=*)
        API_KEY_INPUT="${1#*=}"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

require_fetch_tool() {
  if has_command curl; then
    return
  fi
  if has_command wget; then
    return
  fi
  log_error "curl or wget is required to bootstrap nvm."
  exit 1
}

download_url() {
  local url="$1"
  local output_file="$2"
  if has_command curl; then
    curl -fsSL "$url" -o "$output_file"
    return
  fi
  wget -qO "$output_file" "$url"
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    require_fetch_tool
    log_info "Installing nvm (${NVM_INSTALL_VERSION})..."
    local nvm_installer
    nvm_installer="$(mktemp -t nvm-install.XXXXXX.sh)"
    download_url "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" "$nvm_installer"
    bash "$nvm_installer"
    rm -f "$nvm_installer"
  fi

  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"

  if ! command -v nvm >/dev/null 2>&1; then
    log_error "nvm failed to load."
    exit 1
  fi
}

install_nodejs() {
  log_info "Installing Node.js ${NODE_TARGET_VERSION} via nvm..."
  load_nvm
  nvm install "$NODE_TARGET_VERSION"
  nvm alias default "$NODE_TARGET_VERSION"
  nvm use "$NODE_TARGET_VERSION"

  local node_version
  node_version="$(node -v)"
  local npm_version
  npm_version="$(npm -v)"
  log_success "Node.js active version: ${node_version}"
  log_success "npm version: ${npm_version}"
}

check_nodejs() {
  if has_command node; then
    local node_version
    node_version="$(node -v || true)"
    if [[ "$node_version" =~ ^v([0-9]+)\. ]]; then
      local major="${BASH_REMATCH[1]}"
      if (( major >= NODE_TARGET_VERSION )); then
        log_success "Node.js version is compatible: ${node_version}"
        return
      fi
      log_info "Detected Node.js ${node_version}. Upgrading to minimum v${NODE_TARGET_VERSION}."
      install_nodejs
      return
    fi
  fi

  log_info "Node.js not found. Installing minimum required version v${NODE_TARGET_VERSION}."
  install_nodejs
}

ensure_npm_global_bin_on_path() {
  local npm_prefix
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ -n "$npm_prefix" && -d "$npm_prefix/bin" ]]; then
    export PATH="$npm_prefix/bin:$PATH"
  fi
}

install_claude_code() {
  ensure_npm_global_bin_on_path

  if has_command claude; then
    log_success "Claude Code is already installed: $(claude --version)"
    return
  fi

  log_info "Installing Claude Code..."
  npm install -g "$CLAUDE_PACKAGE"
  ensure_npm_global_bin_on_path

  if ! has_command claude; then
    log_error "Claude Code installed but command was not found on PATH."
    log_error "Try restarting the terminal, then run: claude --version"
    exit 1
  fi

  log_success "Claude Code installed successfully: $(claude --version)"
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

resolve_api_key() {
  local resolved_api_key=""

  if [[ -n "${API_KEY_INPUT:-}" ]]; then
    resolved_api_key="$API_KEY_INPUT"
  elif [[ -n "${ZAI_API_KEY:-}" ]]; then
    resolved_api_key="$ZAI_API_KEY"
  elif [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
    resolved_api_key="$ANTHROPIC_AUTH_TOKEN"
  else
    printf '   You can get your API key from: %s\n' "$API_KEY_URL"
    read -r -s -p "🔑 Please enter your Z.AI API key: " resolved_api_key
    printf '\n'
  fi

  printf '%s' "$resolved_api_key"
}

configure_claude() {
  log_info "Configuring Claude Code..."

  local api_key
  api_key="$(resolve_api_key)"

  if [[ -z "${api_key// }" ]]; then
    log_error "API key is required and cannot be empty."
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
  parse_args "$@"

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
