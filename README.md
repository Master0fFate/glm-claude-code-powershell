# glm-claude-code-powershell

Cross-platform auto-install scripts that configure Claude Code to use GLM endpoints.

## One-line auto download + execute (bootstrap launcher)

### Windows PowerShell (`irm`)

```powershell
irm https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode-bootstrap.ps1 | iex
```

Pass API key non-interactively:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { irm https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode-bootstrap.ps1 | iex } -ApiKey 'YOUR_ZAI_API_KEY'"
```

### Windows CMD (`curl`)

```cmd
curl -fsSL -o "%TEMP%\glm-claudecode-bootstrap.ps1" "https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode-bootstrap.ps1" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\glm-claudecode-bootstrap.ps1"
```

### macOS / Linux / WSL (`.sh`)

```bash
curl -fsSL https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode-bootstrap.sh | bash
```

`wget` alternative:

```bash
wget -qO- https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode-bootstrap.sh | bash
```

Pass API key non-interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode-bootstrap.sh | bash -s -- --api-key "YOUR_ZAI_API_KEY"
```

## Support matrix

- **Windows**: `glm-claudecode.ps1` (via `glm-claudecode-bootstrap.ps1`)
- **macOS / Linux / WSL**: `glm-claudecode.sh` (via `glm-claudecode-bootstrap.sh`)

## What the scripts do

- Standardize Node.js to **v22 (LTS target)**.
- Install `@anthropic-ai/claude-code` globally via npm.
- Require Z.AI API key input (`--api-key`, `-ApiKey`, or prompt).
- Write `.claude/settings.json` with:
  - `ANTHROPIC_AUTH_TOKEN`
  - `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`
  - `API_TIMEOUT_MS=3000000`
- Mark onboarding completed in `~/.claude.json`.

## Claude Code paths used by scripts

- Config directory (all platforms):
  - `~/.claude/settings.json`
  - `~/.claude.json`
- Windows resolves `~` to `%USERPROFILE%`.
- macOS/Linux/WSL resolves `~` to `$HOME`.
- Claude executable is expected on `PATH` after global npm install (`claude` / `claude.cmd`).

## Notes

- This is an unofficial community script and is not affiliated with Anthropic or Z.AI.
