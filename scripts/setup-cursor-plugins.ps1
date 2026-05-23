# Link ast-index Cursor plugin from submodule (run once after clone).
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$pluginSrc = Join-Path $repoRoot "tools\ast-index\plugin"
if (-not (Test-Path $pluginSrc)) {
    throw "Run: git submodule update --init --recursive"
}
$pluginDst = Join-Path $env:USERPROFILE ".cursor\plugins\local\ast-index"
New-Item -ItemType Directory -Force (Split-Path $pluginDst) | Out-Null
if (Test-Path $pluginDst) { cmd /c "rmdir `"$pluginDst`"" 2>$null }
cmd /c "mklink /J `"$pluginDst`" `"$pluginSrc`""
Write-Host "Linked ast-index -> $pluginDst"
Write-Host "Reload Cursor. MCP optional: see docs/TOOLS_SETUP.md"
