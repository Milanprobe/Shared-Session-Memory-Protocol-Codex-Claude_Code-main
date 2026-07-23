$ErrorActionPreference = "Stop"

$sharedHook = (Resolve-Path -LiteralPath (
    Join-Path $PSScriptRoot "..\..\.claude\hooks\inject-session-memory.ps1"
)).Path

& $sharedHook -Client codex
exit $LASTEXITCODE
