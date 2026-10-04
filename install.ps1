#requires -Version 5.1
<#
.SYNOPSIS
Fetch and install Terminal for Spicetify on Windows.
.PARAMETER Ref
GitHub branch, tag, or commit to install. Defaults to main.
.PARAMETER NoApply
Install the theme files without selecting the theme or restarting Spotify.
.PARAMETER LocalSource
Use a downloaded repository or Terminal folder instead of fetching from GitHub.
.PARAMETER SpicetifyPath
Use a specific Spicetify executable instead of the one found on PATH.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._/-]+$')]
    [string]$Ref = 'main',
    [switch]$NoApply,
    [string]$LocalSource,
    [string]$SpicetifyPath
)

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
$repository = 'braces157/spicetify-terminal'
$themeFiles = @('color.ini', 'user.css', 'theme.js', 'README.md')
$stage = $null
$backup = $null
$destination = $null
$configPath = $null
$changedFiles = @()
$configChanged = $false
$useGitHubCli = $false

function Invoke-Spicetify {
    param([string[]]$ArgumentList)
    $output = @(& $SpicetifyPath @ArgumentList 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Spicetify $($ArgumentList -join ' ') failed: $($output -join [Environment]::NewLine)"
    }
    $output | ForEach-Object { [string]$_ }
}

function Get-AuthenticatedThemeFile {
    param([string]$Name, [string]$OutputPath)
    $gh = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw 'This repository is private or unavailable. Install GitHub CLI, run gh auth login with an account that has repository access, and retry. You can also use -LocalSource with a downloaded copy.'
    }
    $endpoint = "repos/$repository/contents/Terminal/$Name`?ref=$([Uri]::EscapeDataString($Ref))"
    $response = @(& $gh.Source api $endpoint 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub download failed for $Name. Check gh auth status and repository access. $($response -join [Environment]::NewLine)"
    }
    $file = ($response -join [Environment]::NewLine) | ConvertFrom-Json
    if ($file.type -ne 'file' -or $file.encoding -ne 'base64' -or -not $file.content) {
        throw "GitHub returned an unexpected response for $Name."
    }
    [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($file.content))
}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'This installer supports Windows. Use the manual theme installation on other platforms.'
    }
    if (-not $SpicetifyPath) {
        $command = Get-Command spicetify -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { $SpicetifyPath = $command.Source }
        elseif ($env:LOCALAPPDATA) {
            $SpicetifyPath = Join-Path $env:LOCALAPPDATA 'spicetify\spicetify.exe'
        }
    }
    if (-not $SpicetifyPath -or -not (Test-Path -LiteralPath $SpicetifyPath -PathType Leaf)) {
        throw 'Spicetify was not found. Install and set up Spicetify first: https://spicetify.app/docs/getting-started'
    }
    $SpicetifyPath = (Resolve-Path -LiteralPath $SpicetifyPath).ProviderPath
    $configOutput = @(Invoke-Spicetify -ArgumentList @('--config'))
    if ($configOutput.Count -eq 0) { throw 'Spicetify did not return its config file path.' }
    $configPath = ($configOutput | Select-Object -Last 1) -replace '\x1b\[[0-9;]*m', ''
    $configPath = $configPath.Trim()
    if (-not [IO.Path]::IsPathRooted($configPath) -or -not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw 'Spicetify did not return an existing config file. Finish Spicetify setup and retry.'
    }
    $configPath = (Resolve-Path -LiteralPath $configPath).ProviderPath
    $configRoot = [IO.Path]::GetDirectoryName($configPath)
    $destination = Join-Path $configRoot 'Themes\Terminal'
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('spicetify-terminal-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null

    $source = $null
    if ($LocalSource) {
        $source = (Resolve-Path -LiteralPath $LocalSource).ProviderPath
        if (-not (Test-Path -LiteralPath (Join-Path $source 'color.ini') -PathType Leaf)) {
            $source = Join-Path $source 'Terminal'
        }
    }
    Write-Host "Fetching Terminal ($Ref)..."
    foreach ($name in $themeFiles) {
        $filePath = Join-Path $stage $name
        if ($source) {
            Copy-Item -LiteralPath (Join-Path $source $name) -Destination $filePath
        }
        elseif ($useGitHubCli) { Get-AuthenticatedThemeFile -Name $name -OutputPath $filePath }
        else {
            try {
                $url = "https://raw.githubusercontent.com/$repository/$Ref/Terminal/$name"
                Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $filePath -TimeoutSec 30
            }
            catch {
                $useGitHubCli = $true
                Get-AuthenticatedThemeFile -Name $name -OutputPath $filePath
            }
        }
        if ((Get-Item -LiteralPath $filePath).Length -eq 0) { throw "Downloaded $name is empty." }
    }
    if ((Get-Content -LiteralPath (Join-Path $stage 'color.ini') -Raw) -notmatch '(?m)^\[Terminal\]\s*$') {
        throw 'The downloaded theme does not contain the Terminal color scheme.'
    }

    $backupName = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $backup = Join-Path $configRoot (Join-Path 'TerminalBackups' $backupName)
    New-Item -ItemType Directory -Path (Join-Path $backup 'Terminal') -Force | Out-Null
    Copy-Item -LiteralPath $configPath -Destination (Join-Path $backup 'config-xpui.ini')
    foreach ($name in $themeFiles) {
        $existing = Join-Path $destination $name
        if (Test-Path -LiteralPath $existing -PathType Leaf) {
            Copy-Item -LiteralPath $existing -Destination (Join-Path $backup "Terminal\$name")
        }
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($name in $themeFiles) {
        $changedFiles += $name
        Copy-Item -LiteralPath (Join-Path $stage $name) -Destination (Join-Path $destination $name) -Force
    }

    if (-not $NoApply) {
        Write-Host 'Selecting Terminal and applying it. Spotify may restart...'
        $configChanged = $true
        Invoke-Spicetify -ArgumentList @('config', 'current_theme', 'Terminal', 'color_scheme', 'Terminal', 'inject_css', '1', 'inject_theme_js', '1', 'replace_colors', '1') | ForEach-Object { Write-Host $_ }
        Invoke-Spicetify -ArgumentList @('apply') | ForEach-Object { Write-Host $_ }
    }
    Write-Host "Installed: $destination" -ForegroundColor Green
    Write-Host "Backup: $backup"
    if ($NoApply) { Write-Host 'Theme files are ready. Your selected theme and running Spotify were not changed.' }
    else { Write-Host 'Done. Press F8 in Spotify to show or hide window controls.' }
}
catch {
    $failure = $_
    if ($backup -and ($changedFiles.Count -gt 0 -or $configChanged)) {
        try {
            foreach ($name in $changedFiles) {
                $previous = Join-Path $backup "Terminal\$name"
                $installed = Join-Path $destination $name
                if (Test-Path -LiteralPath $previous -PathType Leaf) {
                    Copy-Item -LiteralPath $previous -Destination $installed -Force
                }
                elseif (Test-Path -LiteralPath $installed -PathType Leaf) {
                    Remove-Item -LiteralPath $installed -Force
                }
            }
            if ($configChanged) { Copy-Item -LiteralPath (Join-Path $backup 'config-xpui.ini') -Destination $configPath -Force }
            Write-Host 'Previous theme files and settings restored. If Spotify was partially modified, run spicetify apply to reapply the previous theme.'
        }
        catch { Write-Warning "Could not finish restoring the backup at $backup : $($_.Exception.Message)" }
    }
    throw $failure
}
finally {
    # Only remove this run's four known staging files and its empty directory.
    if ($stage -and (Test-Path -LiteralPath $stage -PathType Container)) {
        foreach ($name in $themeFiles) {
            $temporaryFile = Join-Path $stage $name
            if (Test-Path -LiteralPath $temporaryFile -PathType Leaf) {
                Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue
    }
    $ErrorActionPreference = $previousErrorActionPreference
}
