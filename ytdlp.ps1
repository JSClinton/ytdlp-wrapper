# Jeff YT-DLP Audio Download wrapper
# Version 0.1

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

function Download-Audio {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [string]$OutputPath = ".",
        [string]$Format = "mp3"
    )

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
    } else {
        Write-Host "`nDownload failed!" -ForegroundColor Red
    }
}

# Main Script
Show-Banner

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

# Get URL from user
$url = Read-Host "`nEnter video URL"

if ([string]::IsNullOrWhiteSpace($url)) {
    Write-Host "No URL provided. Exiting." -ForegroundColor Red
    exit 1
}

# Get output path (optional)
$outputPath = Read-Host "Enter output directory (press Enter for current directory)"
if ([string]::IsNullOrWhiteSpace($outputPath)) {
    $outputPath = "."
}

# Get audio format (optional)
Write-Host "`nAvailable formats: mp3, m4a, wav, flac, opus, vorbis"
$format = Read-Host "Enter desired audio format (press Enter for mp3)"
if ([string]::IsNullOrWhiteSpace($format)) {
    $format = "mp3"
}

# Download the audio
Download-Audio -Url $url -OutputPath $outputPath -Format $format

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
