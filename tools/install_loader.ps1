<# Install one stable loader; move prior matching installs outside scripts first. #>
param(
    [Parameter(Mandatory=$true)][string]$ScriptsPath,
    [ValidatePattern('^[A-Za-z0-9_]+$')][string]$Project='MasterArthasNav'
)
$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$ScriptsRoot=(Resolve-Path -LiteralPath $ScriptsPath).Path.TrimEnd('\','/')
if ((Split-Path -Leaf $ScriptsRoot) -ne 'scripts') { throw 'ScriptsPath must name the existing Sylvanas scripts directory.' }
$Source=Join-Path $RepoRoot "loaders/$($Project)_loader"
if (-not (Test-Path -LiteralPath (Join-Path $Source 'plugin_loader.lua'))) { throw "No stable loader for $Project" }
$Target=Join-Path $ScriptsRoot "$($Project)_loader"
$AccountRoot=Split-Path -Parent $ScriptsRoot
$BackupRoot=Join-Path $AccountRoot ('mf_arthas_backups/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$Names=@("$($Project)_loader")
if ($Project -eq 'MasterArthasNav') { $Names+=@('ArthasNav','MasterArthasNav') }
foreach ($Name in $Names) {
    $Old=Join-Path $ScriptsRoot $Name
    if (-not (Test-Path -LiteralPath $Old)) { continue }
    $Resolved=(Resolve-Path -LiteralPath $Old).Path
    if (-not $Resolved.StartsWith($ScriptsRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Backup source escaped scripts directory.' }
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    $Backup=Join-Path $BackupRoot $Name
    $FullBackup=[IO.Path]::GetFullPath($Backup)
    if (-not $FullBackup.StartsWith([IO.Path]::GetFullPath($BackupRoot)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid backup target.' }
    Move-Item -LiteralPath $Resolved -Destination $FullBackup
    Write-Host "Previous install preserved: $FullBackup"
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
Get-ChildItem -LiteralPath $Source -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Target $_.Name) -Force }
# Seed the optional fallback font locally; other clients fetch the same version
# asynchronously from the repository the first time a non-English GUI is drawn.
$Font=Join-Path $RepoRoot 'shared/fonts/unifont-18.0.01.otf'
if (Test-Path -LiteralPath $Font) {
    $FontCache=Join-Path $AccountRoot 'scripts_data/mf_arthas/fonts'
    New-Item -ItemType Directory -Force -Path $FontCache | Out-Null
    Copy-Item -LiteralPath $Font -Destination (Join-Path $FontCache 'unifont-18.0.01.otf') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'shared/fonts/OFL-1.1.txt') -Destination (Join-Path $FontCache 'OFL-1.1.txt') -Force
}
Write-Host "Installed stable loader: $Target"
Write-Host 'Reload plugins in Sylvanas to activate. The separate navigation companion must already be installed.'
