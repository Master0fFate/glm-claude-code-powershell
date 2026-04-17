# A PowerShell installation script for Claude Code by Master0fFate

param(
    [string]$ApiKey
)

# ========================
#       Constants
# ========================
$ErrorActionPreference = "Stop"
$SCRIPT_NAME = $MyInvocation.MyCommand.Name
$NODE_TARGET_VERSION = 22
$NVM_WINDOWS_VERSION = "1.1.12"
$CLAUDE_PACKAGE = "@anthropic-ai/claude-code"
$CONFIG_DIR = Join-Path $env:USERPROFILE ".claude"
$API_BASE_URL = "https://api.z.ai/api/anthropic"
$API_KEY_URL = "https://z.ai/manage-apikey/apikey-list"
$API_TIMEOUT_MS = 3000000

# ========================
#       Utility Functions
# ========================

function Log-Info {
    param([string]$Message)
    Write-Host "🔹 $Message" -ForegroundColor Cyan
}

function Log-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Log-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Ensure-DirExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        catch {
            Log-Error "Failed to create directory: $Path"
            exit 1
        }
    }
}

# ========================
#     Node.js Installation
# ========================

function Install-NodeJS {
    Log-Info "Installing standardized Node.js v$NODE_TARGET_VERSION on Windows..."

    Log-Info "Installing nvm-windows ($NVM_WINDOWS_VERSION)..."

    $nvmUrl = "https://github.com/coreybutler/nvm-windows/releases/download/$NVM_WINDOWS_VERSION/nvm-setup.exe"
    $nvmInstaller = Join-Path $env:TEMP "nvm-setup.exe"

    try {
        Invoke-WebRequest -Uri $nvmUrl -OutFile $nvmInstaller -UseBasicParsing
        Start-Process -FilePath $nvmInstaller -Args "/SILENT" -Wait
        Remove-Item $nvmInstaller -Force
    }
    catch {
        Log-Error "Failed to download or install nvm-windows"
        exit 1
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    Start-Sleep -Seconds 3

    Log-Info "Installing Node.js $NODE_TARGET_VERSION..."
    try {
        & nvm install $NODE_TARGET_VERSION
        & nvm use $NODE_TARGET_VERSION

        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    catch {
        Log-Error "Failed to install Node.js via nvm"
        exit 1
    }

    Start-Sleep -Seconds 2
    try {
        $nodeVersion = & node -v
        $npmVersion = & npm -v
        Log-Success "Node.js active version: $nodeVersion"
        Log-Success "npm version: $npmVersion"
    }
    catch {
        Log-Error "Node.js installation verification failed"
        exit 1
    }
}

# ========================
#     Node.js Check
# ========================

function Check-NodeJS {
    try {
        $nodeVersion = & node -v 2>$null
        if (-not $nodeVersion) {
            Log-Info "Node.js not found. Installing standardized version v$NODE_TARGET_VERSION..."
            Install-NodeJS
            return
        }

        $version = $nodeVersion -replace 'v', ''
        $majorVersion = [int]($version.Split('.')[0])

        if ($majorVersion -eq $NODE_TARGET_VERSION) {
            Log-Success "Node.js already standardized: $nodeVersion"
            return
        }

        Log-Info "Detected Node.js $nodeVersion. Standardizing to v$NODE_TARGET_VERSION..."
        Install-NodeJS
        return
    }
    catch {
        Log-Info "Node.js not found. Installing standardized version v$NODE_TARGET_VERSION..."
        Install-NodeJS
        return
    }
}

# ========================
#     Claude Code Installation
# ========================

function Ensure-ClaudePath {
    $appData = [System.Environment]::GetEnvironmentVariable("APPDATA")
    if (-not [string]::IsNullOrWhiteSpace($appData)) {
        $npmGlobal = Join-Path $appData "npm"
        if (Test-Path $npmGlobal) {
            if (-not (($env:Path -split ';') -contains $npmGlobal)) {
                $env:Path = "$npmGlobal;$env:Path"
            }
        }
    }
}

function Install-ClaudeCode {
    Ensure-ClaudePath

    try {
        $claudeVersion = & claude --version 2>$null
        if ($claudeVersion) {
            Log-Success "Claude Code is already installed: $claudeVersion"
            return
        }
    }
    catch {
        Log-Info "Claude Code not found. Installing..."
    }

    Log-Info "Installing Claude Code..."
    try {
        & npm install -g $CLAUDE_PACKAGE
        Ensure-ClaudePath

        $claudeVersion = & claude --version 2>$null
        if (-not $claudeVersion) {
            Log-Error "Claude Code installed but command was not found on PATH."
            Log-Error "Try restarting your terminal, then run: claude --version"
            exit 1
        }

        Log-Success "Claude Code installed successfully: $claudeVersion"
    }
    catch {
        Log-Error "Failed to install claude-code"
        exit 1
    }
}

function Configure-ClaudeJson {
    $script = @'
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
'@

    try {
        & node -e $script
    }
    catch {
        Log-Error "Failed to configure .claude.json"
    }
}

# ========================
#     API Key Configuration
# ========================

function Resolve-ApiKey {
    param([string]$InlineApiKey)

    if (-not [string]::IsNullOrWhiteSpace($InlineApiKey)) {
        return $InlineApiKey
    }

    if (-not [string]::IsNullOrWhiteSpace($env:ZAI_API_KEY)) {
        return $env:ZAI_API_KEY
    }

    if (-not [string]::IsNullOrWhiteSpace($env:ANTHROPIC_AUTH_TOKEN)) {
        return $env:ANTHROPIC_AUTH_TOKEN
    }

    Write-Host "   You can get your API key from: $API_KEY_URL"
    $apiKeySecure = Read-Host "🔑 Please enter your Z.AI API key" -AsSecureString
    $apiKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKeySecure)
    )

    return $apiKeyPlain
}

function Configure-Claude {
    param([string]$InlineApiKey)

    Log-Info "Configuring Claude Code..."

    $apiKeyPlain = Resolve-ApiKey -InlineApiKey $InlineApiKey

    if ([string]::IsNullOrWhiteSpace($apiKeyPlain)) {
        Log-Error "API key is required and cannot be empty."
        exit 1
    }

    Ensure-DirExists $CONFIG_DIR

    $apiKeyEscaped = $apiKeyPlain -replace '\\', '\\' -replace '"', '\"'
    $apiBaseUrlEscaped = $API_BASE_URL -replace '\\', '\\' -replace '"', '\"'
    $script = @"
const fs = require('fs');
const path = require('path');
const os = require('os');

const homeDir = os.homedir();
const configDir = path.join(homeDir, '.claude');
const filePath = path.join(configDir, 'settings.json');

if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
}

let content = {};
if (fs.existsSync(filePath)) {
    try {
        const raw = fs.readFileSync(filePath, 'utf-8');
        if (raw.trim()) {
            content = JSON.parse(raw);
        }
    } catch (_) {
        content = {};
    }
}

const env = { ...(content.env || {}) };
env.ANTHROPIC_AUTH_TOKEN = "$apiKeyEscaped";
env.ANTHROPIC_BASE_URL = "$apiBaseUrlEscaped";
env.API_TIMEOUT_MS = "$API_TIMEOUT_MS";

const newContent = { ...content, env };
fs.writeFileSync(filePath, JSON.stringify(newContent, null, 2), 'utf-8');
console.log('Configuration written successfully');
"@

    try {
        & node -e $script
        Log-Success "Claude Code configured successfully"
    }
    catch {
        Log-Error "Failed to write settings.json"
        Log-Error $_.Exception.Message
        exit 1
    }
}

# ========================
#        Main Process
# ========================

function Main {
    if (-not $IsWindows) {
        Log-Error "This script is intended for Windows PowerShell. Use glm-claudecode.sh on macOS/Linux/WSL, or use bootstrap launcher."
        exit 1
    }

    Write-Host "🚀 Starting $SCRIPT_NAME"

    Check-NodeJS
    Install-ClaudeCode
    Configure-ClaudeJson
    Configure-Claude -InlineApiKey $ApiKey

    Write-Host ""
    Log-Success "🎉 Installation completed successfully!"
    Write-Host ""
    Write-Host "🚀 You can now start using Claude Code with:"
    Write-Host "   claude"
    Write-Host ""
    Write-Host "Note: You may need to restart your terminal for changes to take effect."
}

Main
