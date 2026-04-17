param(
    [string]$ApiKey
)

$ErrorActionPreference = "Stop"
$RawBase = "https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-LocalOrRemotePs1 {
    param([string]$InlineApiKey)

    $localScript = Join-Path $ScriptRoot "glm-claudecode.ps1"
    if (Test-Path $localScript) {
        & $localScript -ApiKey $InlineApiKey
        return
    }

    $tempFile = Join-Path $env:TEMP "glm-claudecode.ps1"
    Invoke-WebRequest -Uri "$RawBase/glm-claudecode.ps1" -OutFile $tempFile -UseBasicParsing
    & $tempFile -ApiKey $InlineApiKey
}

function Invoke-LocalOrRemoteSh {
    param([string]$InlineApiKey)

    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        throw "bash is required to run Linux/macOS bootstrap path."
    }

    $localScript = Join-Path $ScriptRoot "glm-claudecode.sh"
    if (Test-Path $localScript) {
        if ([string]::IsNullOrWhiteSpace($InlineApiKey)) {
            & bash $localScript
        }
        else {
            & bash $localScript --api-key $InlineApiKey
        }
        return
    }

    $previousApiKey = $env:ZAI_API_KEY
    $tempSh = Join-Path ([System.IO.Path]::GetTempPath()) "glm-claudecode.sh"
    try {
        if (-not [string]::IsNullOrWhiteSpace($InlineApiKey)) {
            $env:ZAI_API_KEY = $InlineApiKey
        }

        Invoke-WebRequest -Uri "$RawBase/glm-claudecode.sh" -OutFile $tempSh -UseBasicParsing
        & bash $tempSh
    }
    finally {
        Remove-Item $tempSh -ErrorAction SilentlyContinue
        if ($null -eq $previousApiKey) {
            Remove-Item Env:ZAI_API_KEY -ErrorAction SilentlyContinue
        }
        else {
            $env:ZAI_API_KEY = $previousApiKey
        }
    }
}

if ($IsWindows) {
    Invoke-LocalOrRemotePs1 -InlineApiKey $ApiKey
}
else {
    Invoke-LocalOrRemoteSh -InlineApiKey $ApiKey
}
