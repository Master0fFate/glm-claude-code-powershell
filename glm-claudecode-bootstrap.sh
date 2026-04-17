#!/usr/bin/env bash

set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

has_command() {
  command -v "$1" >/dev/null 2>&1
}

download_url() {
  local url="$1"
  local output_file="$2"
  if has_command curl; then
    curl -fsSL "$url" -o "$output_file"
    return
  fi

  if has_command wget; then
    wget -qO "$output_file" "$url"
    return
  fi

  echo "❌ curl or wget is required to run bootstrap installer." >&2
  exit 1
}

run_local_or_remote_sh() {
  if [[ -f "$SCRIPT_DIR/glm-claudecode.sh" ]]; then
    bash "$SCRIPT_DIR/glm-claudecode.sh" "$@"
    return $?
  fi

  local tmp_sh
  tmp_sh="$(mktemp -t glm-claudecode.XXXXXX.sh)"
  download_url "$REPO_RAW_BASE/glm-claudecode.sh" "$tmp_sh"
  bash "$tmp_sh" "$@"
  rm -f "$tmp_sh"
}

run_local_or_remote_ps1() {
  local ps_cmd=""
  if has_command pwsh; then
    ps_cmd="pwsh"
  elif has_command powershell; then
    ps_cmd="powershell"
  else
    echo "❌ PowerShell is required for Windows bootstrap path." >&2
    exit 1
  fi

  if [[ -f "$SCRIPT_DIR/glm-claudecode.ps1" ]]; then
    "$ps_cmd" -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/glm-claudecode.ps1" "$@"
    return $?
  fi

  local tmp_ps1
  tmp_ps1="$(mktemp -t glm-claudecode.XXXXXX.ps1)"

  download_url "$REPO_RAW_BASE/glm-claudecode.ps1" "$tmp_ps1"

  "$ps_cmd" -NoProfile -ExecutionPolicy Bypass -File "$tmp_ps1" "$@"
  rm -f "$tmp_ps1"
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    run_local_or_remote_ps1 "$@"
    ;;
  *)
    run_local_or_remote_sh "$@"
    ;;
esac
