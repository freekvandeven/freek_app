<#
.SYNOPSIS
    Builds the Personal App Windows installer.

.DESCRIPTION
    1. Runs `flutter build windows --release`
    2. Compiles the Inno Setup script into a single-file installer EXE
    The resulting installer is placed in personal_app/build/installer/

.NOTES
    Prerequisites:
    - Flutter SDK on PATH
    - Inno Setup 6+ installed (https://jrsoftware.org/isinfo.php)
      Default location: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    - Visual Studio with C++ desktop workload (for flutter build windows)

.EXAMPLE
    .\scripts\build-windows-installer.ps1
#>

param(
    [string]$InnoSetupPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$AppDir     = Join-Path $RepoRoot "personal_app"
$IssFile    = Join-Path $AppDir "installer\installer.iss"

# --- Locate Inno Setup compiler ---
if ($InnoSetupPath -eq "") {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $InnoSetupPath = $c; break }
    }
    if ($InnoSetupPath -eq "") {
        Write-Error @"
Inno Setup compiler (ISCC.exe) not found.
Install Inno Setup 6 from https://jrsoftware.org/isinfo.php
or pass the path explicitly:
  .\build-windows-installer.ps1 -InnoSetupPath 'C:\path\to\ISCC.exe'
"@
        exit 1
    }
}

Write-Host "=== Using Inno Setup: $InnoSetupPath ===" -ForegroundColor Cyan

# --- Step 1: Flutter release build ---
Write-Host "`n=== Building Flutter Windows release ===" -ForegroundColor Cyan
Push-Location $AppDir
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$releaseDir = Join-Path $AppDir "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $releaseDir "personal_app.exe"))) {
    Write-Error "Release build not found at $releaseDir"
    exit 1
}

# --- Step 2: Compile installer ---
Write-Host "`n=== Compiling installer ===" -ForegroundColor Cyan
& $InnoSetupPath $IssFile
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed with exit code $LASTEXITCODE" }

$outputDir = Join-Path $AppDir "build\installer"
Write-Host "`n=== Done! Installer written to: ===" -ForegroundColor Green
Get-ChildItem $outputDir -Filter "*.exe" | ForEach-Object { Write-Host "  $($_.FullName)" }
