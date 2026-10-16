param([Parameter(Mandatory=$true)][string]$PythonExecutable)
$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$Python=(Resolve-Path -LiteralPath $PythonExecutable).Path
& $Python -c 'import sys; from pathlib import Path; sys.path.insert(0,str(Path(sys.argv[1])/".dev"/"python")); import lupa.luajit21' $RepoRoot
if ($LASTEXITCODE -ne 0) { throw 'Install Lupa for this Python, or into .dev/python, before enabling publishing checks.' }
& git -C $RepoRoot config mf-arthas.python $Python
if ($LASTEXITCODE -ne 0) { throw 'Could not save repository-local Python setting.' }
& git -C $RepoRoot config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) { throw 'Could not enable the repository pre-push checks.' }
Write-Host 'Pre-push validation enabled. Edit this checkout, then run tools/publish.ps1 -Message "Describe the update".'
