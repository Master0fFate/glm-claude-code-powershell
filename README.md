# glm-claude-code-powershell

Cross-platform auto-install scripts that configure Claude Code to use GLM endpoints.

## One-line auto download + execute

### Windows PowerShell (`irm`)

```powershell
irm https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode.ps1 | iex
```

### Windows CMD (`curl`)

```cmd
curl -fsSL -o "%TEMP%\glm-claudecode.ps1" "https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode.ps1" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\glm-claudecode.ps1"
```

### macOS / Linux / WSL (`.sh`)

```bash
curl -fsSL https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode.sh | bash
```

`wget` alternative:

```bash
wget -qO- https://raw.githubusercontent.com/Master0fFate/glm-claude-code-powershell/main/glm-claudecode.sh | bash
```

## What the scripts do

- Checks Node.js version and installs/updates when needed.
- Installs `@anthropic-ai/claude-code` globally via npm.
- Prompts for Z.AI API key.
- Writes `.claude/settings.json` with:
  - `ANTHROPIC_AUTH_TOKEN`
  - `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`
  - `API_TIMEOUT_MS=3000000`
- Marks onboarding completed in `~/.claude.json`.

## Notes

- This is an unofficial community script and is not affiliated with Anthropic or Z.AI.
