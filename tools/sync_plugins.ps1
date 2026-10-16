<#
.SYNOPSIS
    Copies the local projects into plugins/, writes each plugin's manifest.txt,
    and creates any missing loader folder under loaders/.

.DESCRIPTION
    Run this before every push. The loaders read plugins/<project>/manifest.txt
    to find out what to download, so a push without a fresh manifest is not
    seen by players.

    A loader's header.lua and main.lua are only created, never rewritten: they
    stay the same for every update. mf_loader.lua is copied from
    tools/loader_template/ into every loader folder on each run so the copies
    never drift apart.

.EXAMPLE
    pwsh tools/sync_plugins.ps1
    pwsh tools/sync_plugins.ps1 -Only sylvanas_mage,sylvanas_hunter
    pwsh tools/sync_plugins.ps1 -SourceRoot D:\Arthas_Projects -IncludeDocs
#>
param(
    # Folder that holds the project folders. Defaults to the repo's parent.
    [string]$SourceRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    # Limit the run to these project ids.
    [string[]]$Only,
    # Also publish .md files next to the code. They are never downloaded.
    [switch]$IncludeDocs
)

$ErrorActionPreference = 'Stop'
# "pwsh -File" hands "-Only a,b" over as one string.
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $RepoRoot 'tools/loader_template/mf_loader.lua'

# Project id (folder in plugins/, never changes) -> local source folder.
# A Source with * picks the highest _v<version> folder, so a renamed release
# folder such as sylvanas_mage_v1.2.25 is found without editing this table.
# Name is the display name the loader shows before the first download; keep it
# equal to the project's own header name so saved menu settings carry over.
# ClassIds lets the loader skip other classes before anything is downloaded.
$Projects = @(
    @{ Id = 'MasterArthasNav';        Source = 'MasterArthasNav';             Name = 'MasterArthasNav' }
    @{ Id = 'assassination_rogue';    Source = 'assassination_rogue_v*';      Name = 'Assassination Rogue Activity Profiles'; ClassIds = @(4) }
    @{ Id = 'bg_player';              Source = 'bg player';                   Name = 'Sylvanas Battleground Command' }
    @{ Id = 'bloodcrypt_delver';      Source = 'bloodcrypt_delver';           Name = 'Bloodcrypt Delver' }
    @{ Id = 'guardian_druid_mplus';   Source = 'guardian_druid_mplus_v*';     Name = 'Arthas Druid Suite 12.1.5'; ClassIds = @(11) }
    @{ Id = 'holy_paladin_mplus';     Source = 'holy_paladin_mplus_v*';       Name = 'Holy Paladin Healing Profiles'; ClassIds = @(2) }
    @{ Id = 'prot_paladin_mplus';     Source = 'prot_paladin_mplus_v*';       Name = 'Protection Paladin Mythic+'; ClassIds = @(2) }
    @{ Id = 'resto_shaman_mplus';     Source = 'resto_shaman_mplus_v*';       Name = 'Resto Shaman M+'; ClassIds = @(7) }
    @{ Id = 'ret_paladin_plugin';     Source = 'ret_paladin_plugin_v*';       Name = 'Ret Paladin 12.1'; ClassIds = @(2) }
    @{ Id = 'sylvanas_auto_leveler';  Source = 'sylvanas_auto_leveler';       Name = 'Sylvanas Auto Leveler (development)' }
    @{ Id = 'sylvanas_bg_link_probe'; Source = 'sylvanas_bg_link_probe';      Name = 'Sylvanas BG Link Probe (diagnostic)' }
    @{ Id = 'sylvanas_hunter';        Source = 'sylvanas_hunter_v*';          Name = 'Sylvanas Hunter — BM / MM / Survival'; ClassIds = @(3) }
    @{ Id = 'sylvanas_mage';          Source = 'sylvanas_mage_v*';            Name = 'Sylvanas Mage — Arcane / Fire / Frost'; ClassIds = @(8) }
    @{ Id = 'sylvanas_universal_ui';  Source = 'sylvanas_universal_ui';       Name = 'Sylvanas Universal UI' }
    @{ Id = 'sylvanas_warrior';       Source = 'sylvanas_warrior_v*';         Name = 'Sylvanas Warrior — Arms / Fury / Protection'; ClassIds = @(1) }
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Sha = [System.Security.Cryptography.SHA256]::Create()

function Get-Hex([byte[]]$Bytes) { -join ($Sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) }

function Resolve-Source($Pattern) {
    $dirs = @(Get-ChildItem -LiteralPath $SourceRoot -Directory | Where-Object { $_.Name -like $Pattern })
    if ($dirs.Count -le 1) { return $dirs | Select-Object -First 1 }
    $dirs | Sort-Object -Descending -Property @{ Expression = {
        $v = $null
        if ($_.Name -match '_v(\d+(\.\d+){0,3})$' -and [version]::TryParse($Matches[1], [ref]$v)) { $v } else { [version]'0.0' }
    } } | Select-Object -First 1
}

# Files the loader downloads: everything except docs and tests.
function Test-Runtime([string]$Rel) {
    if ($Rel -match '\.md$') { return $false }
    if ($Rel -match '(^|/)tests/') { return $false }
    if ($Rel -match '(^|/)tests[^/]*\.lua$') { return $false }
    return $true
}

function Get-Version($Dir) {
    $header = Join-Path $Dir 'header.lua'
    if (Test-Path -LiteralPath $header) {
        $text = Get-Content -LiteralPath $header -Raw
        if ($text -match 'version\s*=\s*([''"])([^''"]+)\1') { return $Matches[2] }
        if ($text -match 'version\s*=\s*require\s*\(?\s*[''"]([^''"]+)[''"]') {
            $mod = Join-Path $Dir (($Matches[1] -replace '\.lua$', '') + '.lua')
            if ((Test-Path -LiteralPath $mod) -and ((Get-Content -LiteralPath $mod -Raw) -match '([''"])([^''"]+)\1')) { return $Matches[2] }
        }
    }
    if ((Split-Path -Leaf $Dir) -match '_v(\d+(\.\d+)*)$') { return $Matches[1] }
    return 'unversioned'
}

function Lua-String([string]$s) { '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"' }

function Sync-Loader($P) {
    $dir = Join-Path $RepoRoot "loaders/$($P.Id)_loader"
    $created = -not (Test-Path -LiteralPath $dir)
    if ($created) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $fields = @("    project = $(Lua-String $P.Id),", "    name = $(Lua-String $P.Name),")
        if ($P.ClassIds) { $fields += "    class_ids = { $($P.ClassIds -join ', ') }," }
        $config = "require(`"mf_loader`").new({`n" + ($fields -join "`n") + "`n})"
        $note = "-- mf-arthas loader. This file stays the same for every update: the plugin's`n" +
                "-- code, version and load rules are downloaded from GitHub by mf_loader.lua.`n"
        [IO.File]::WriteAllText((Join-Path $dir 'header.lua'), "$note`nreturn $($config):header()`n", $Utf8)
        [IO.File]::WriteAllText((Join-Path $dir 'main.lua'), "$note`n$($config):main()`n", $Utf8)
    }
    Copy-Item -LiteralPath $Template -Destination (Join-Path $dir 'mf_loader.lua') -Force
    return $created
}

foreach ($p in $Projects) {
    if ($Only -and ($Only -notcontains $p.Id)) { continue }
    $src = Resolve-Source $p.Source
    if (-not $src) { Write-Warning "$($p.Id): no folder matches '$($p.Source)' in $SourceRoot"; continue }
    if (-not (Test-Path -LiteralPath (Join-Path $src.FullName 'main.lua'))) { Write-Warning "$($p.Id): $($src.Name) has no main.lua"; continue }

    $dest = Join-Path $RepoRoot "plugins/$($p.Id)"
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    $entries = New-Object System.Collections.Generic.List[string]
    $files = Get-ChildItem -LiteralPath $src.FullName -Recurse -File |
        ForEach-Object { [pscustomobject]@{ File = $_; Rel = $_.FullName.Substring($src.FullName.Length + 1) -replace '\\', '/' } } |
        Sort-Object -Property Rel -CaseSensitive
    foreach ($f in $files) {
        $runtime = Test-Runtime $f.Rel
        $keepDoc = $f.Rel -match '\.md$' -and ($IncludeDocs -or $f.Rel -eq 'README.md')
        if (-not $runtime -and -not $keepDoc) { continue }
        $target = Join-Path $dest $f.Rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $f.File.FullName -Destination $target
        if ($runtime) {
            $bytes = [IO.File]::ReadAllBytes($f.File.FullName)
            $entries.Add("file $($bytes.Length) $(Get-Hex $bytes) $($f.Rel)")
        }
    }

    $version = Get-Version $src.FullName
    $header = if (Test-Path -LiteralPath (Join-Path $src.FullName 'header.lua')) { "header header.lua`n" } else { '' }
    $body = "project $($p.Id)`nversion $version`nentry main.lua`n$header" + ($entries -join "`n") + "`n"
    $build = (Get-Hex $Utf8.GetBytes($body)).Substring(0, 16)
    [IO.File]::WriteAllText((Join-Path $dest 'manifest.txt'), "# mf-arthas-manifest 1`nbuild $build`n$body", $Utf8)

    $created = Sync-Loader $p
    "{0,-24} {1,-34} v{2,-12} {3,4} files  build {4}{5}" -f $p.Id, $src.Name, $version, $entries.Count, $build, $(if ($created) { '  (new loader)' } else { '' })
}
