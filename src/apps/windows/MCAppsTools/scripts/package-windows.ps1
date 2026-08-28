[CmdletBinding()]
param(
    [string]$ProjectRoot = "",
    [ValidateSet("win-x64")]
    [string]$Runtime = "win-x64",
    [switch]$SingleFile,
    [switch]$ReadyToRun,
    [switch]$KeepSolidCompression,
    [switch]$SkipRestore,
    [switch]$NoClean,
    [string]$NexKeyDllPath = "",
    [string]$SignToolPath = "",
    [string]$CertificateThumbprint = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

$scriptRootPath = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRootPath) -and ![string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootPath = Split-Path -Parent $PSCommandPath
}
if ([string]::IsNullOrWhiteSpace($scriptRootPath) -and $MyInvocation.MyCommand.Path) {
    $scriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    if ([string]::IsNullOrWhiteSpace($scriptRootPath)) {
        throw "Could not resolve the script directory. Pass -ProjectRoot explicitly."
    }

    $ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRootPath "..")).Path
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not found: $Path"
    }
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Resolve-InnoCompiler {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw "Inno Setup compiler was not found. Install Inno Setup 6 or update Resolve-InnoCompiler."
}

function Invoke-CodeSignIfConfigured {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($SignToolPath) -and [string]::IsNullOrWhiteSpace($CertificateThumbprint)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($SignToolPath) -or [string]::IsNullOrWhiteSpace($CertificateThumbprint)) {
        throw "Both -SignToolPath and -CertificateThumbprint are required to sign artifacts."
    }

    Assert-FileExists -Path $SignToolPath -Description "signtool.exe"
    Assert-FileExists -Path $Path -Description "Artifact to sign"

    Write-Host "Signing $Path"
    Invoke-CheckedCommand -FilePath $SignToolPath -Arguments @(
        "sign",
        "/fd", "SHA256",
        "/td", "SHA256",
        "/tr", $TimestampUrl,
        "/sha1", $CertificateThumbprint,
        $Path
    )
}

$projectRootPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
$csprojPath = Join-Path $projectRootPath "MCAppsTools.csproj"
$versionPath = Join-Path $projectRootPath "VERSION"
$installerDir = Join-Path $projectRootPath "installer"
$issPath = Join-Path $installerDir "MCNexus.iss"
$installerNotesPath = Join-Path $installerDir "INSTALLATION-NOTES.txt"
$distDir = Join-Path $projectRootPath "dist"
$distInstallerDir = Join-Path $projectRootPath "dist-installer"

Assert-FileExists -Path $csprojPath -Description "Project file"
Assert-FileExists -Path $versionPath -Description "VERSION file"
Assert-FileExists -Path $issPath -Description "Inno Setup script"
Assert-FileExists -Path $installerNotesPath -Description "Installer notes"

# NexKeyRuntime shared library (Fase 5, §7.5) — vendored, not built by this
# project. Unlike Lex on the macOS side there's no symlink trick here (NTFS
# symlinks need admin/dev-mode, and MCAppsTools.csproj's <None Include=
# "NexKey\bin\nexkeyruntime.dll"> just needs a plain file), so this copies
# rather than links. Fails loud, same as the macOS script's LexActivator
# check — a build that silently ships without it looks identical to a good
# one until someone activates a NexKeyRuntime-routed license, far from here.
# See MCManager/Windows/docs/nexkeyruntime-windows-build.md.
$nexKeyDestDir = Join-Path $projectRootPath "NexKey\bin"
$nexKeyDestDll = Join-Path $nexKeyDestDir "nexkeyruntime.dll"

if (![string]::IsNullOrWhiteSpace($NexKeyDllPath)) {
    Assert-FileExists -Path $NexKeyDllPath -Description "NexKeyRuntime shared library (-NexKeyDllPath)"
    New-Item -ItemType Directory -Force -Path $nexKeyDestDir | Out-Null
    Copy-Item -LiteralPath $NexKeyDllPath -Destination $nexKeyDestDll -Force
}

if (!(Test-Path -LiteralPath $nexKeyDestDll -PathType Leaf)) {
    throw "NexKeyRuntime shared library not found at $nexKeyDestDll. Pass -NexKeyDllPath, or vendor it manually first (see MCManager/Windows/docs/nexkeyruntime-windows-build.md)."
}

$version = (Get-Content -LiteralPath $versionPath -Raw).Trim().TrimStart("v")
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "VERSION file is empty: $versionPath"
}

$publishSingleFile = if ($SingleFile.IsPresent) { "true" } else { "false" }
$publishReadyToRun = if ($ReadyToRun.IsPresent) { "true" } else { "false" }
$solidCompression = if ($KeepSolidCompression.IsPresent) { "yes" } else { "no" }

Write-Host "Packaging MCNexus v$version"
Write-Host "Project root: $projectRootPath"
Write-Host "Runtime: $Runtime"
Write-Host "PublishSingleFile: $publishSingleFile"
Write-Host "PublishReadyToRun: $publishReadyToRun"
Write-Host "Inno SolidCompression: $solidCompression"

if (!$NoClean.IsPresent) {
    Remove-Item -LiteralPath $distDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $distInstallerDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
New-Item -ItemType Directory -Force -Path $distInstallerDir | Out-Null

if (!$SkipRestore.IsPresent) {
    Invoke-CheckedCommand -FilePath "dotnet" -Arguments @(
        "restore",
        $csprojPath
    )
}

Invoke-CheckedCommand -FilePath "dotnet" -Arguments @(
    "publish",
    $csprojPath,
    "-c", "Release",
    "-r", $Runtime,
    "--self-contained", "true",
    "-p:PublishSingleFile=$publishSingleFile",
    "-p:PublishReadyToRun=$publishReadyToRun",
    "-o", $distDir
)

$appExePath = Join-Path $distDir "MCNexus.exe"
Assert-FileExists -Path $appExePath -Description "Published app executable"
Invoke-CodeSignIfConfigured -Path $appExePath

$isccPath = Resolve-InnoCompiler
Invoke-CheckedCommand -FilePath $isccPath -Arguments @(
    $issPath,
    "/DAppVersion=$version",
    "/DSourceDir=$distDir",
    "/DInstallerDir=$installerDir",
    "/DOutputDir=$distInstallerDir",
    "/DInstallerSolidCompression=$solidCompression"
)

$installerPath = Join-Path $distInstallerDir "MCNexus-Setup-v$version.exe"
Assert-FileExists -Path $installerPath -Description "Installer"
Invoke-CodeSignIfConfigured -Path $installerPath

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $installerPath

Write-Host ""
Write-Host "Done."
Write-Host "Installer: $installerPath"
Write-Host "SHA-256: $($hash.Hash.ToLowerInvariant())"
