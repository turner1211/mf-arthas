<#
.SYNOPSIS
    Synchronizes, validates, commits, and pushes mf-arthas plugin updates.

.EXAMPLE
    pwsh tools/publish.ps1 -Only bg_player -Message "Update bg_player"
#>
param(
    [string]$SourceRoot,
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

$Git = (Get-Command git -ErrorAction Stop).Source
$Python = & $Git -C $RepoRoot config --get mf-arthas.python
if (-not $Python) { $Python = (Get-Command python3,python -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
if (-not $Python) { throw 'Python with Lupa is required. Set git config mf-arthas.python to its executable.' }
if ($SourceRoot) {
    $syncArgs = @('-NoProfile', '-File', $Sync, '-SourceRoot', $SourceRoot)
    if ($Only) { $syncArgs += @('-Only', ($Only -join ',')) }
    if ($IncludeDocs) { $syncArgs += '-IncludeDocs' }
    Invoke-Checked (Get-Command pwsh -ErrorAction Stop).Source $syncArgs
}
# Direct checkout edits are now the default. Never overwrite them from a sibling folder.
$manifestArgs = @((Join-Path $PSScriptRoot 'update_manifests.py'))
if ($Only) { foreach ($id in ($Only -join ',' -split ',')) { $manifestArgs += @('--project', $id) } }
Invoke-Checked $Python $manifestArgs
Invoke-Checked $Python @((Join-Path $PSScriptRoot 'verify.py'))

Push-Location $RepoRoot
try {
    Invoke-Checked (Get-Command git -ErrorAction Stop).Source @('diff', '--check')
    & git status --short
    if (-not (git status --porcelain)) {
        if (-not $NoPush) { Invoke-Checked (Get-Command git).Source @('push', 'origin', 'HEAD') }
        Write-Host 'No new changes; existing commits published unless NoPush was selected.'
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
