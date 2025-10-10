# glm-claude-code-powershell
A powershell equivalent of the auto-install script that enables using GLM in Claude Code.



## Description

This PowerShell script provides an alternative convenient way to install and configure `glm` for `claude-code`,
based on the popular script
```shell
curl -O "http://bigmodel-us3-prod-marketplace.cn-wlcb.ufileos.com/1753683755292-30b3431f487b4cc1863e57a81d78e289.sh?ufileattname=claude_code_prod_zai.sh"
```

## Features

*   **Dependency Checking**: Automatically checks if a compatible version of Node.js is installed and installs it if necessary.
*   **Automated Installation**: Installs `claude-code` globally using npm.
*   **API Configuration**: Prompts the user for an API key and configures the necessary environment variables for the tool to function.

## How to Use

1.  Save the script as a `.ps1` file (e.g., `glm-claudecode.ps1`).
2.  Open a PowerShell terminal and navigate to the directory where you saved the file.
3.  Execute the script by running: `.\glm-claudecode.ps1`
4.  Follow the prompts to provide your API key when requested.

Upon completion, `claude-code` will be installed and configured on your system and it's gonna be using `GLM AI Models`. You may need to restart your terminal for all changes to take effect.

- This script is unofficial and not afilliated with either Anthropic and/or Z.ai (or any other relevant affiliates)
