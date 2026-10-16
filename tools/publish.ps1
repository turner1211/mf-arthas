<#
.SYNOPSIS
    Synchronizes, validates, commits, and pushes mf-arthas plugin updates.

.EXAMPLE
    pwsh tools/publish.ps1 -Only bg_player -Message "Update bg_player"
#>
param(
    [string]$SourceRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string[]]$Only,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,
    [switch]$IncludeDocs,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Sync = Join-Path $PSScriptRoot 'sync_plugins.ps1'
$Test = Join-Path $PSScriptRoot 'test_loader.lua'

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

$syncArgs = @('-NoProfile', '-File', $Sync, '-SourceRoot', $SourceRoot)
if ($Only) { $syncArgs += @('-Only', ($Only -join ',')) }
if ($IncludeDocs) { $syncArgs += '-IncludeDocs' }
Invoke-Checked (Get-Command pwsh -ErrorAction Stop).Source $syncArgs

$Lua = Get-Command luajit -ErrorAction SilentlyContinue
if (-not $Lua) { $Lua = Get-Command lua -ErrorAction SilentlyContinue }
if (-not $Lua) { throw 'LuaJIT or Lua is required to validate the loader before publishing.' }
Invoke-Checked $Lua.Source @($Test)

Push-Location $RepoRoot
try {
    Invoke-Checked (Get-Command git -ErrorAction Stop).Source @('diff', '--check')
    & git status --short
    if (-not (git status --porcelain)) {
        Write-Host 'Nothing changed; no commit or push was needed.'
        return
    }
    Invoke-Checked (Get-Command git).Source @('add', '--all')
    Invoke-Checked (Get-Command git).Source @('commit', '-m', $Message)
    if (-not $NoPush) {
        Invoke-Checked (Get-Command git).Source @('push', 'origin', 'HEAD')
    }
}
finally {
    Pop-Location
}
