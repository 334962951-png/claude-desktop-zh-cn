[CmdletBinding()]
param(
    [string]$Version = "1.11187.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $repoRoot "dist"
$packageRoot = Join-Path $distDir "claude-desktop-zh-cn-$Version"
$zipPath = Join-Path $distDir "claude-desktop-zh-cn-$Version.zip"

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

[System.IO.Directory]::CreateDirectory($packageRoot) | Out-Null

$batFiles = Get-ChildItem -LiteralPath $repoRoot -Filter "*.bat" -File

$batInstall = $batFiles |
    Where-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        $content -notmatch '-Uninstall'
    } |
    Select-Object -First 1

$batUninstall = $batFiles |
    Where-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        $content -match '-Uninstall'
    } |
    Select-Object -First 1

if (-not $batInstall) {
    throw "Missing install bat file"
}

if (-not $batUninstall) {
    throw "Missing uninstall bat file"
}

$includePaths = @(
    "LanguagePack.ps1",
    $batInstall.Name,
    $batUninstall.Name,
    "README.md",
    "LICENSE",
    "NOTICE",
    "translated-zh-CN"
)

foreach ($relativePath in $includePaths) {
    $source = Join-Path $repoRoot $relativePath
    $target = Join-Path $packageRoot $relativePath

    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing release asset: $relativePath"
    }

    if ((Get-Item -LiteralPath $source).PSIsContainer) {
        Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
    }
    else {
        $parent = Split-Path -Parent $target
        if ($parent) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "Release package created:"
Write-Host "  Folder: $packageRoot"
Write-Host "  Zip:    $zipPath"
