# A powershell version of the installation script for claude-code by Master0fFate

# ========================
#       Constants
# ========================
$ErrorActionPreference = "Stop"
$SCRIPT_NAME = $MyInvocation.MyCommand.Name
$NODE_MIN_VERSION = 18
$NODE_INSTALL_VERSION = 22
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
    Log-Info "Installing Node.js on Windows..."

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

    Log-Info "Installing Node.js $NODE_INSTALL_VERSION..."
    try {
        & nvm install $NODE_INSTALL_VERSION
        & nvm use $NODE_INSTALL_VERSION
        
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    catch {
        Log-Error "Failed to install Node.js via nvm"
        exit 1
    }

    # Verify installation
    Start-Sleep -Seconds 2
    try {
        $nodeVersion = & node -v
        $npmVersion = & npm -v
        Log-Success "Node.js installed: $nodeVersion"
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
        if ($nodeVersion) {
            $version = $nodeVersion -replace 'v', ''
            $majorVersion = [int]($version.Split('.')[0])
            
            if ($majorVersion -ge $NODE_MIN_VERSION) {
                Log-Success "Node.js is already installed: $nodeVersion"
                return
            }
            else {
                Log-Info "Node.js $nodeVersion is installed but version < $NODE_MIN_VERSION. Upgrading..."
                Install-NodeJS
            }
        }
    }
    catch {
        Log-Info "Node.js not found. Installing..."
        Install-NodeJS
    }
}

# ========================
#     Claude Code Installation
# ========================

function Install-ClaudeCode {
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
        Log-Success "Claude Code installed successfully"
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
if (fs.existsSync(filePath)) {
    const content = JSON.parse(fs.readFileSync(filePath, "utf-8"));
    fs.writeFileSync(filePath, JSON.stringify({ ...content, hasCompletedOnboarding: true }, null, 2), "utf-8");
} else {
    fs.writeFileSync(filePath, JSON.stringify({ hasCompletedOnboarding: true }, null, 2), "utf-8");
}
'@

    try {
        $script | & node --eval $script
    }
    catch {
        Log-Error "Failed to configure .claude.json"
    }
}

# ========================
#     API Key Configuration
# ========================

function Configure-ClaudeJson {
    $script = @'
const os = require("os");
const fs = require("fs");
const path = require("path");

const homeDir = os.homedir();
const filePath = path.join(homeDir, ".claude.json");
if (fs.existsSync(filePath)) {
    const content = JSON.parse(fs.readFileSync(filePath, "utf-8"));
    fs.writeFileSync(filePath, JSON.stringify({ ...content, hasCompletedOnboarding: true }, null, 2), "utf-8");
} else {
    fs.writeFileSync(filePath, JSON.stringify({ hasCompletedOnboarding: true }, null, 2), "utf-8");
}
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

function Configure-Claude {
    Log-Info "Configuring Claude Code..."
    Write-Host "   You can get your API key from: $API_KEY_URL"
    
    $apiKey = Read-Host "🔑 Please enter your Z.AI API key" -AsSecureString
    $apiKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
    )

    if ([string]::IsNullOrWhiteSpace($apiKeyPlain)) {
        Log-Error "API key cannot be empty. Please run the script again."
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

// Ensure directory exists
if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
}

let content = {};
if (fs.existsSync(filePath)) {
    try {
        const fileContent = fs.readFileSync(filePath, 'utf-8');
        if (fileContent.trim()) {
            content = JSON.parse(fileContent);
        }
    } catch (e) {
        console.log('Creating new settings file...');
    }
}

const newContent = {
    ...content,
    env: {
        ANTHROPIC_AUTH_TOKEN: "$apiKeyEscaped",
        ANTHROPIC_BASE_URL: "$apiBaseUrlEscaped",
        API_TIMEOUT_MS: "$API_TIMEOUT_MS"
    }
};

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
    Write-Host "🚀 Starting $SCRIPT_NAME"

    Check-NodeJS
    Install-ClaudeCode
    Configure-ClaudeJson
    Configure-Claude

    Write-Host ""
    Log-Success "🎉 Installation completed successfully!"
    Write-Host ""
    Write-Host "🚀 You can now start using Claude Code with:"
    Write-Host "   claude"
    Write-Host ""
    Write-Host "Note: You may need to restart your terminal for changes to take effect."
}

Main