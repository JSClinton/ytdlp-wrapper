# Jeff YT-DLP Audio Download wrapper
# Version 0.2 - Added config-driven batch download and defaults

function Show-Banner {
    Write-Host "Jeff YT-DLP Tool"
}

function Test-Command {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    } catch {
        return $false
    }
}

function Install-FFmpeg {
    Write-Host "FFmpeg not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install --id=Gyan.FFmpeg -e --source winget
        Write-Host "FFmpeg installed successfully!" -ForegroundColor Green
        Write-Host "You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "Failed to install FFmpeg: $_" -ForegroundColor Red
        return $false
    }
}

function Install-YtDlp {
    Write-Host "yt-dlp not found. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install --id=yt-dlp.yt-dlp -e --source winget
        Write-Host "yt-dlp installed successfully!" -ForegroundColor Green
        Write-Host "You may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "Failed to install yt-dlp: $_" -ForegroundColor Red
        return $false
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Host "Created directory: $Path" -ForegroundColor Green
        } catch {
            Write-Host "Failed to create directory $Path : $_" -ForegroundColor Red
            throw
        }
    }
}

function Download-Audio {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [string]$OutputPath = ".",
        [string]$Format = "mp3"
    )

    # Ensure output path exists
    Ensure-Directory -Path $OutputPath

    $ytDlpArgs = @(
        "-x",
        "--audio-format", $Format,
        "--audio-quality", "0",
        "-o", "$OutputPath/%(title)s.%(ext)s",
        $Url
    )

    Write-Host "`nDownloading audio from: $Url" -ForegroundColor Cyan
    Write-Host "Output format: $Format" -ForegroundColor Cyan
    Write-Host "Output path: $OutputPath`n" -ForegroundColor Cyan

    & yt-dlp @ytDlpArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nDownload completed successfully!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "`nDownload failed for $Url (exit code $LASTEXITCODE) !" -ForegroundColor Red
        return $false
    }
}

function Load-Config {
    param(
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        return $null
    }

    try {
        $json = Get-Content -Path $ConfigPath -Raw
        $obj = $json | ConvertFrom-Json
        return $obj
    } catch {
        Write-Host "Failed to read or parse config file '$ConfigPath': $_" -ForegroundColor Yellow
        return $null
    }
}

# Main Script
Show-Banner

# Locate script directory and default config path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DefaultConfigPath = Join-Path $ScriptDir "ytdlp.config.json"

# Load config if present
$config = Load-Config -ConfigPath $DefaultConfigPath

if ($null -ne $config) {
    Write-Host "Loaded configuration from $DefaultConfigPath" -ForegroundColor Green
}

# Check for yt-dlp
if (-not (Test-Command "yt-dlp")) {
    $install = Read-Host "yt-dlp is not installed. Install it now? (Y/N)"
    if ($install -eq "Y" -or $install -eq "y") {
        if (-not (Install-YtDlp)) {
            Write-Host "Cannot proceed without yt-dlp. Exiting." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Cannot proceed without yt-dlp. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Check for FFmpeg
if (-not (Test-Command "ffmpeg")) {
    $install = Read-Host "FFmpeg is not installed. Install it now? (Y/N)"
    if ($install -eq "Y" -or $install -eq "y") {
        if (-not (Install-FFmpeg)) {
            Write-Host "Warning: FFmpeg installation failed. Audio conversion may not work properly." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Warning: Continuing without FFmpeg. Audio conversion may not work properly." -ForegroundColor Yellow
    }
}

# If config enables batch mode, process the URLs file
$enableBatch = $false
if ($null -ne $config -and $config.PSObject.Properties.Name -contains 'enableBatch') {
    try { $enableBatch = [bool]$config.enableBatch } catch { $enableBatch = $false }
}

if ($enableBatch) {
    # Determine urls file path
    $urlsFile = $config.urlsFile
    if ([string]::IsNullOrWhiteSpace($urlsFile)) {
        # default to urls.txt in script dir
        $urlsFile = Join-Path $ScriptDir "urls.txt"
    } elseif (-not (Split-Path $urlsFile -IsAbsolute)) {
        # if relative path in config, resolve against script dir
        $urlsFile = Join-Path $ScriptDir $urlsFile
    }

    if (-not (Test-Path $urlsFile)) {
        Write-Host "Batch mode enabled but URLs file not found: $urlsFile" -ForegroundColor Red
        exit 1
    }

    # Output defaults from config (if present) or fallback
    $defaultOutput = if ($null -ne $config -and $config.PSObject.Properties.Name -contains 'outputPath' -and -not [string]::IsNullOrWhiteSpace($config.outputPath)) {
        $cfgOut = $config.outputPath
        if (-not (Split-Path $cfgOut -IsAbsolute)) { Join-Path $ScriptDir $cfgOut } else { $cfgOut }
    } else { "." }

    $defaultFormat = if ($null -ne $config -and $config.PSObject.Properties.Name -contains 'format' -and -not [string]::IsNullOrWhiteSpace($config.format)) {
        $config.format
    } else { "mp3" }

    Write-Host "`nBatch mode enabled. Reading URLs from: $urlsFile" -ForegroundColor Cyan
    Write-Host "Default output path: $defaultOutput" -ForegroundColor Cyan
    Write-Host "Default audio format: $defaultFormat`n" -ForegroundColor Cyan

    $lines = Get-Content -Path $urlsFile -ErrorAction Stop
    $urls = $lines | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }

    if ($urls.Count -eq 0) {
        Write-Host "No URLs found in $urlsFile. Exiting." -ForegroundColor Yellow
        exit 0
    }

    $successCount = 0
    $failCount = 0
    foreach ($u in $urls) {
        try {
            $ok = Download-Audio -Url $u -OutputPath $defaultOutput -Format $defaultFormat
            if ($ok) { $successCount++ } else { $failCount++ }
        } catch {
            Write-Host "Error downloading $u : $_" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`nBatch done. Success: $successCount, Failed: $failCount" -ForegroundColor Green
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

# Non-batch interactive flow (use config defaults if present)

# Get URL from user
$url = Read-Host "`nEnter video URL"

if ([string]::IsNullOrWhiteSpace($url)) {
    Write-Host "No URL provided. Exiting." -ForegroundColor Red
    exit 1
}

# Get output path (optional) - use config default if provided
$cfgOutput = $null
if ($null -ne $config -and $config.PSObject.Properties.Name -contains 'outputPath' -and -not [string]::IsNullOrWhiteSpace($config.outputPath)) {
    $cfgOutput = $config.outputPath
    if (-not (Split-Path $cfgOutput -IsAbsolute)) { $cfgOutput = Join-Path $ScriptDir $cfgOutput }
}

if ($cfgOutput) {
    Write-Host "`nUsing configured output directory: $cfgOutput" -ForegroundColor Cyan
    $outputPath = $cfgOutput
} else {
    $outputPath = Read-Host "Enter output directory (press Enter for current directory)"
    if ([string]::IsNullOrWhiteSpace($outputPath)) { $outputPath = "." }
}

# Ensure output directory exists (create if necessary)
Ensure-Directory -Path $outputPath

# Get audio format (optional) - use config default if provided
$cfgFormat = if ($null -ne $config -and $config.PSObject.Properties.Name -contains 'format' -and -not [string]::IsNullOrWhiteSpace($config.format)) { $config.format } else { $null }
if ($cfgFormat) {
    Write-Host "`nUsing configured audio format: $cfgFormat" -ForegroundColor Cyan
    $format = $cfgFormat
} else {
    Write-Host "`nAvailable formats: mp3, m4a, wav, flac, opus, vorbis"
    $format = Read-Host "Enter desired audio format (press Enter for mp3)"
    if ([string]::IsNullOrWhiteSpace($format)) { $format = "mp3" }
}

# Download the audio
Download-Audio -Url $url -OutputPath $outputPath -Format $format

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")