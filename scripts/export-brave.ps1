<#
.SYNOPSIS
    Exports the portable parts of a Brave profile from Windows into this repo.

.DESCRIPTION
    Run this on the Windows machine BEFORE migrating to Linux. It captures the
    two things that actually port across operating systems:

      * bookmarks      -> home/dot_config/brave/bookmarks.json
      * extension list -> printed as a ready-to-paste block for
                          home/.chezmoidata/brave.yaml

    It deliberately does NOT touch:

      * Login Data, Cookies, Web Data, Local Storage

    Those are encrypted with a key in "Local State" that is sealed by Windows
    DPAPI and bound to this Windows user account. They are mathematically
    undecryptable on Linux, where Brave uses gnome-keyring/kwallet instead.
    Copying them produces a corrupt profile, not a migrated one. Use Brave Sync
    for passwords, history and open tabs.

.PARAMETER ProfileName
    Display name of the profile, as shown in Brave. Defaults to "KD".

.PARAMETER Encrypt
    Encrypt the exported bookmarks with `chezmoi encrypt` before writing them.
    STRONGLY recommended: this repository is public and bookmarks routinely
    contain internal hostnames, client names and vendor portals.

.EXAMPLE
    .\scripts\export-brave.ps1 -Encrypt

.EXAMPLE
    .\scripts\export-brave.ps1 -ProfileName Perso
#>
[CmdletBinding()]
param(
    [string] $ProfileName = 'KD',
    [switch] $Encrypt
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$UserData = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data'

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Blue }
function Write-Ok   { param($m) Write-Host "  ok $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "warn $m" -ForegroundColor Yellow }

if (-not (Test-Path $UserData)) {
    throw "Brave user data not found at: $UserData"
}

# ---------------------------------------------------------------- profile --
Write-Step "Locating profile '$ProfileName'"

$localState = Get-Content (Join-Path $UserData 'Local State') -Raw -Encoding UTF8 | ConvertFrom-Json
$profileDir = $null
foreach ($p in $localState.profile.info_cache.PSObject.Properties) {
    if ($p.Value.name -eq $ProfileName) { $profileDir = $p.Name; break }
}
if (-not $profileDir) {
    $available = ($localState.profile.info_cache.PSObject.Properties |
        ForEach-Object { "$($_.Name) => '$($_.Value.name)'" }) -join "`n    "
    throw "No profile named '$ProfileName'. Available:`n    $available"
}

$profilePath = Join-Path $UserData $profileDir
Write-Ok "'$ProfileName' is the '$profileDir' folder"

# -------------------------------------------------------------- bookmarks --
Write-Step 'Exporting bookmarks'

$bookmarksSrc = Join-Path $profilePath 'Bookmarks'
if (-not (Test-Path $bookmarksSrc)) {
    Write-Warn 'No Bookmarks file in this profile — skipping.'
} else {
    $destDir = Join-Path $RepoRoot 'home\dot_config\brave'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    # Copied verbatim so Chromium's internal checksum stays valid.
    $plain = Join-Path $destDir 'bookmarks.json'

    if ($Encrypt) {
        if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
            throw 'chezmoi is not on PATH, cannot encrypt. Install it or omit -Encrypt.'
        }
        $encrypted = Join-Path $destDir 'encrypted_bookmarks.json'
        & chezmoi encrypt --output $encrypted $bookmarksSrc
        if ($LASTEXITCODE -ne 0) { throw "chezmoi encrypt failed (exit $LASTEXITCODE)" }
        if (Test-Path $plain) { Remove-Item $plain -Force }
        Write-Ok "encrypted -> home/dot_config/brave/encrypted_bookmarks.json"
    } else {
        Copy-Item $bookmarksSrc $plain -Force
        Write-Ok "plaintext -> home/dot_config/brave/bookmarks.json"
        Write-Warn 'NOT ENCRYPTED. This repo is public — check the hosts below'
        Write-Warn 'before committing, or re-run with -Encrypt.'
    }

    # Report which hosts are about to be committed, so an internal URL cannot
    # slip into a public repo unnoticed.
    $bm = Get-Content $bookmarksSrc -Raw -Encoding UTF8 | ConvertFrom-Json
    function Get-Urls($n) {
        if ($n.type -eq 'url') { return @($n) }
        $out = @()
        foreach ($c in $n.children) { $out += Get-Urls $c }
        return $out
    }
    $all = @()
    foreach ($r in $bm.roots.PSObject.Properties) {
        if ($r.Value.children) { $all += Get-Urls $r.Value }
    }
    Write-Host "`n  $($all.Count) bookmarks across these hosts:" -ForegroundColor Cyan
    $all | ForEach-Object { try { ([uri]$_.url).Host } catch { '(non-http)' } } |
        Group-Object | Sort-Object Count -Descending |
        ForEach-Object { '    {0,-42} x{1}' -f $_.Name, $_.Count }
}

# ------------------------------------------------------------- extensions --
Write-Step 'Enumerating extensions'

$extRoot = Join-Path $profilePath 'Extensions'
$rows = @()
if (Test-Path $extRoot) {
    foreach ($dir in Get-ChildItem $extRoot -Directory) {
        $id = $dir.Name
        if ($id -eq 'Temp') { continue }

        $ver = Get-ChildItem $dir.FullName -Directory -ErrorAction SilentlyContinue |
               Select-Object -Last 1
        if (-not $ver) { continue }

        $manifestPath = Join-Path $ver.FullName 'manifest.json'
        if (-not (Test-Path $manifestPath)) { continue }
        $mf = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Names are often i18n placeholders like __MSG_extName__; resolve them
        # against the extension's own locale files.
        $name = $mf.name
        if ($name -match '^__MSG_(.+)__$') {
            $key    = $Matches[1]
            $locale = if ($mf.default_locale) { $mf.default_locale } else { 'en' }
            $msgs   = Join-Path $ver.FullName "_locales\$locale\messages.json"
            if (Test-Path $msgs) {
                $m = Get-Content $msgs -Raw -Encoding UTF8 | ConvertFrom-Json
                $prop = $m.PSObject.Properties | Where-Object { $_.Name -eq $key }
                if ($prop) { $name = $prop.Value.message }
            }
        }
        $rows += [pscustomobject]@{ Id = $id; Name = $name; Version = $mf.version }
    }
}

Write-Ok "$($rows.Count) extensions found"
Write-Host "`n  Paste into home/.chezmoidata/brave.yaml under brave.extensions:`n" -ForegroundColor Cyan
foreach ($r in $rows | Sort-Object Name) {
    Write-Host "    - id: $($r.Id)"
    Write-Host "      name: $($r.Name)"
}

# ------------------------------------------------------------------ notes --
Write-Host @"

==> Deliberately NOT exported

    Login Data / Cookies / Web Data / Local Storage
      Encrypted with a DPAPI-sealed key bound to this Windows account.
      They cannot be decrypted on Linux. Enable Brave Sync instead:
      brave://settings/braveSync  (keep the 24-word seed in Dashlane)

==> Next

    1. Review the host list above before committing.
    2. git add home/dot_config/brave home/.chezmoidata/brave.yaml
    3. On Linux: chezmoi apply

"@ -ForegroundColor DarkGray
