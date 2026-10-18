# install-fork.ps1 — one-line installer for this fork's cc-fleet build on Windows.
#
# Replaces cc-fleet.exe (and the ccf.exe alias) with the fork's latest release. It
# installs the binary only: the Claude Code plugin/skill still comes from upstream.
#
#   irm https://raw.githubusercontent.com/KuroIVeko/cc-fleet/main/install-fork.ps1 | iex
#
# Env vars (args don't survive `irm | iex`):
#   $env:CCF_VERSION = 'fork-0.4.2-ps1'   # a specific release tag (default: latest)
#   $env:CCF_PREFIX  = 'C:\dir'           # install dir (default: %LOCALAPPDATA%\cc-fleet\bin)
#
# The existing cc-fleet.exe is kept once as cc-fleet.exe.upstream-bak so you can go back.
# Windows PowerShell 5.1 compatible; the body runs in a child scope like upstream's.

& {

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$REPO = 'KuroIVeko/cc-fleet'

function Die($msg) { throw "install-fork.ps1: $msg" }

switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { $arch = 'amd64' }
    'ARM64' { $arch = 'arm64' }
    default { Die "unsupported architecture '$($env:PROCESSOR_ARCHITECTURE)'" }
}

if ($env:CCF_PREFIX) { $PREFIX = $env:CCF_PREFIX } else { $PREFIX = Join-Path $env:LOCALAPPDATA 'cc-fleet\bin' }

$VERSION = $env:CCF_VERSION
if (-not $VERSION) {
    # Same trick as upstream: read the tag from the /releases/latest redirect.
    $loc = $null
    try {
        $resp = Invoke-WebRequest -Uri "https://github.com/$REPO/releases/latest" -MaximumRedirection 0 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($resp) { $loc = $resp.Headers['Location'] }
    } catch {
        $r = $null
        if ($_.Exception.PSObject.Properties['Response']) { $r = $_.Exception.Response }
        if ($r -is [System.Net.HttpWebResponse]) { $loc = $r.Headers['Location'] }
        elseif ($r) { $loc = "$($r.Headers.Location)" }
    }
    if ($loc) { $VERSION = ($loc -split '/tag/')[-1] }
    if (-not $VERSION) { Die "could not resolve the latest release of $REPO; set `$env:CCF_VERSION" }
}

$ASSET_BASE = "https://github.com/$REPO/releases/download/$VERSION"
$ZIP = "cc-fleet-windows-$arch.zip"

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cc-fleet-fork-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zipPath = Join-Path $tmp $ZIP
    $sumPath = Join-Path $tmp 'checksums.txt'

    Write-Host "==> Downloading $ZIP ($VERSION)"
    Invoke-WebRequest -Uri "$ASSET_BASE/$ZIP" -OutFile $zipPath -UseBasicParsing
    Invoke-WebRequest -Uri "$ASSET_BASE/checksums.txt" -OutFile $sumPath -UseBasicParsing

    $expected = $null
    foreach ($line in Get-Content $sumPath) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -eq 2 -and $parts[1].Trim() -eq $ZIP) { $expected = $parts[0].Trim(); break }
    }
    if (-not $expected) { Die "no checksum for $ZIP in checksums.txt" }
    $actual = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash
    if ($expected -ine $actual) { Die "checksum mismatch for $ZIP" }
    Write-Host "==> Checksum OK"

    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
    $src = Join-Path $tmp "cc-fleet-windows-$arch\cc-fleet.exe"

    New-Item -ItemType Directory -Path $PREFIX -Force | Out-Null
    $dst = Join-Path $PREFIX 'cc-fleet.exe'
    $bak = Join-Path $PREFIX 'cc-fleet.exe.upstream-bak'
    if ((Test-Path $dst) -and -not (Test-Path $bak)) {
        Copy-Item -Path $dst -Destination $bak
        Write-Host "==> Kept the existing binary as $bak"
    }
    try {
        Copy-Item -Path $src -Destination $dst -Force
        Copy-Item -Path $src -Destination (Join-Path $PREFIX 'ccf.exe') -Force
    } catch {
        Die "could not overwrite $dst - is cc-fleet still running (a subagent, the TUI)? Close it and retry. ($($_.Exception.Message))"
    }
    Write-Host "==> Installed $dst (+ ccf alias), build $VERSION"
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

}
