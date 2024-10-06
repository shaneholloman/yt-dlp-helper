<#
.SYNOPSIS
    A PowerShell script for easy video downloading using yt-dlp.

.DESCRIPTION
    This script provides a user-friendly interface for downloading videos from various websites
    using the yt-dlp program. It offers multiple download options, including automatic best quality,
    custom format selection, and playlist handling.

.NOTES
    Version: 1.5.2
    Author: Shane Holloman
    GitHub: https://github.com/shaneholloman

.LINK
    yt-dlp documentation: https://github.com/yt-dlp/yt-dlp#readme
    Supported sites for downloading: https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md

.PARAMETER exe
    Set the name of the YouTube downloader executable. Default is "yt-dlp".

.PARAMETER desktop
    Place the 'Outputs' folder on the Desktop instead of the current directory.

.PARAMETER options
    Manually set additional parameters for the YouTube downloader executable.

.PARAMETER debug
    Display potentially helpful info for debugging, including resulting variable values.

.EXAMPLE
    .\yt-dlp-helper.ps1 -exe "yt-dlp.exe" -desktop -options "--no-mtime --add-metadata --extract-audio"

.REQUIREMENTS
    This script requires the "yt-dlp" program to be installed and in your system PATH.
#>

param (
  [string]$exe,
  [switch]$desktop,
  [string]$options,
  [switch]$debug
)

# Default configuration
$output_location = "%(title)s.%(ext)s" # Outputs to the current directory
$downloader_exe = "yt-dlp" # Assumes yt-dlp is in the system PATH
$other_options = "--no-mtime --add-metadata"

# Override defaults with command-line parameters if provided
if ($exe) {
  $downloader_exe = $exe
}

if ($desktop) {
  $output_location = "$HOME\Desktop\Outputs\%(title)s.%(ext)s"
}

if ($options) {
  $other_options = $options
}

$options = "$other_options -o `"$output_location`""

# Display debug information if requested
if ($debug) {
  Write-Host "`nDebug Information:"
  Write-Host "=================="
  Write-Host "Downloader Executable: $downloader_exe"
  Write-Host "Output Location: $output_location"
  Write-Host "Other Options: $other_options"
  Write-Host "Final Options string: $options"
  Write-Host "==================`n"
}

# Function definitions

<#
.SYNOPSIS
    Sets the format variable based on user input.

.DESCRIPTION
    This function determines the appropriate format options for yt-dlp based on the user's choice.
    It handles various scenarios like automatic selection, best quality, custom formats, etc.

.PARAMETER choice
    The user's choice number corresponding to the desired download format.

.OUTPUTS
    Returns a string containing the appropriate yt-dlp format options.
#>
function Set-Format {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true)]
    [int]$choice
  )

  if ($PSCmdlet.ShouldProcess("Setting format based on user choice")) {
    Switch ($choice) {
      1 { Write-Output $null } # Automatic default (best video + audio muxed)
      2 { Write-Output "-f best" } # Best quality audio+video single file, no mux
      3 { Write-Output "-f bestvideo+bestaudio/best --merge-output-format mp4" } # Highest quality video and audio, combined
      4 { Write-Output "-f $format --merge-output-format mp4" } # Custom video and audio formats, combined
      5 { Write-Output "-f $format" } # Download only audio or video
      6 { Write-Output "-f $format" } # Specific single audio+video file
    }
  }
}

<#
.SYNOPSIS
    Previews the selected format and asks for user confirmation.

.DESCRIPTION
    This function displays the output format that will be used for the download
    using the yt-dlp --get-format option. It then prompts the user to confirm
    if the displayed format is acceptable for the download.

.OUTPUTS
    Returns the user's response (Y/N) to the confirmation prompt.
#>
function Test-Format {
  Write-Host "Output will be: "
  Write-Host (& $downloader_exe $format $URL --get-format)
  Read-Host "Ok? (Enter Y/N)"
}

<#
.SYNOPSIS
    Handles custom format selection for specific user choices.

.DESCRIPTION
    This function prompts the user to input custom format codes for video and/or audio
    when they choose options that require manual format selection (choices 4, 5, and 6).
    It guides the user through the process of selecting appropriate format codes based
    on the available options displayed by yt-dlp.

.OUTPUTS
    Returns a string containing the user-selected format code(s) to be used for the download.
#>
function Get-CustomFormats {
  if ($choice -eq 4) {
    Write-Host ""
    Write-Host "INSTRUCTIONS: Choose the format codes for the video and audio quality you want from the list at the top." -ForegroundColor Cyan
    Write-Host ""
    $videoFormat = Read-Host "Video Format Code"
    $audioFormat = Read-Host "Audio Format Code"
    $chosenFormat = ${videoFormat} + "+" + ${audioFormat}
    Write-Output $chosenFormat
  } elseif ($choice -eq 5) {
    Write-Host ""
    Write-Host "INSTRUCTIONS: Choose the format code for the video or audio quality you want from the list at the top." -ForegroundColor Cyan
    Write-Host ""
    $chosenFormat = Read-Host "Format Code"
    Write-Output $chosenFormat
  } elseif ($choice -eq 6) {
    Write-Host ""
    Write-Host "INSTRUCTIONS: Choose the format code for a specific single audio+video file (one that DOESN'T say 'video only' or 'audio only')." -ForegroundColor Cyan
    Write-Host ""
    $chosenFormat = Read-Host "Format Code"
    Write-Output $chosenFormat
  }
}

<#
.SYNOPSIS
    Updates the yt-dlp program.

.DESCRIPTION
    This function runs the update command for yt-dlp and then exits the script.
    Note that administrative privileges may be required for the update process.
#>
function Update-Program {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param()

  if ($PSCmdlet.ShouldProcess("yt-dlp", "Update")) {
    & $downloader_exe --update
    exit
  }
}

<#
.SYNOPSIS
    Checks if the given URL is a YouTube playlist.

.DESCRIPTION
    This function determines whether the provided URL is a YouTube playlist
    by checking for the presence of "playlist?list=" in the URL.

.PARAMETER url
    The URL to be checked.

.OUTPUTS
    Returns $true if the URL is a playlist, $false otherwise.
#>
function Test-PlaylistUrl {
  param($url)
  return $url -like "*playlist?list=*"
}

<#
.SYNOPSIS
    Checks if the given URL contains both a video ID and a playlist ID.

.DESCRIPTION
    This function determines whether the provided URL contains both a specific
    video ("watch?v=") and a playlist ("list=") component.

.PARAMETER url
    The URL to be checked.

.OUTPUTS
    Returns $true if the URL contains both video and playlist IDs, $false otherwise.
#>
function Test-DualUrl {
  param($url)
  return ($url -like "*list=*") -and ($url -like "*watch?v=*")
}

<#
.SYNOPSIS
    Removes the playlist component from a URL.

.DESCRIPTION
    This function takes a URL that may contain both video and playlist components
    and removes the playlist part, leaving only the video-specific URL.

.PARAMETER url
    The URL to be modified.

.OUTPUTS
    Returns the URL with the playlist component removed.
#>
function Remove-PlaylistFromUrl {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$url
  )

  if ($PSCmdlet.ShouldProcess($url, "Remove playlist component")) {
    $url = $url -replace "&list=[^&]+", ""
    return $url
  }
}

<#
.SYNOPSIS
    Extracts the playlist ID from a URL.

.DESCRIPTION
    This function parses the given URL to extract the playlist ID,
    which is typically found after "list=" in the URL.

.PARAMETER url
    The URL from which to extract the playlist ID.

.OUTPUTS
    Returns the playlist ID if found, or $null if not found.
#>
function Get-PlaylistId {
  param($url)
  $regex = [regex]"list=([^&/]+)"
  $match = $regex.Match($url)
  if ($match.Success) {
    return $match.Groups[1].Value
  } else {
    return $null
  }
}

# Main program execution
Write-Output ""
Write-Output '--------------------------------- Video Downloader Script ---------------------------------'
Write-Output ""
Write-Output 'REQUIRES the yt-dlp program to be installed and in your system PATH'
Write-Output 'Supported Video Sites: https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md'
Write-Output ""
$URL = Read-Host "Enter video URL here"

# URL analysis and handling
if (Test-PlaylistUrl $URL) {
  Write-Output "Regular playlist URL detected. Skipping to format selection...`n"
  $isPlaylist = $true
} elseif (Test-DualUrl $URL) {
  $playlistId = Get-PlaylistId $URL
  Write-Output "`nThe provided URL contains both a video ID and a playlist ID.`n"
  $choice = Read-Host "Do you want to download only the video or the entire playlist? (Enter 'V' for video or 'P' for playlist)"
  if ($choice -eq "P") {
    $isPlaylist = $true
    $URL = "https://www.youtube.com/playlist?list=$playlistId"
    Write-Output "Will download playlist..."
  } else {
    $isPlaylist = $false
    $URL = Remove-PlaylistFromUrl $URL
    Write-Output "Will download video..."
    & $downloader_exe --list-formats $URL
  }
} else {
  $isPlaylist = $false
  Write-Output ""
  & $downloader_exe --list-formats $URL
}

# Format selection loop
while ($confirm -ne "y") {
  Write-Output ""
  Write-Output "---------------------------------------------------------------------------"
  Write-Output "Options:"
  Write-Output "1. Download automatically (default is best video + audio muxed)"
  Write-Output "2. Download the best quality audio+video single file, no mux"
  Write-Output "3. Download the highest quality audio + video formats, attempt merge to mp4"
  Write-Output "4. Let me individually choose the video and audio formats to combine"
  Write-Output "5. Download ONLY audio or video"
  Write-Output "6. Download a specific audio+video single file, no mux"
  Write-Output "7. -UPDATE PROGRAM- (Admin May Be Required)"
  Write-Output ""

  $choice = Read-Host "Type your choice number"
  if (($choice -eq 4) -or ($choice -eq 5) -or ($choice -eq 6)) { $format = Get-CustomFormats }
  if ($choice -eq 7) { Update-Program }
  $format = Set-Format -choice $choice
  if (-not $isPlaylist) {
    $confirm = Test-Format
  } else {
    Write-Host "Skipping format list for playlist..."
    $confirm = Read-Host "Proceed and download playlist videos? (Enter Y/N)"
  }
}

# Final download execution
Write-Output ""
$command = "$downloader_exe $format $URL $options"
Write-Output "Running Command: $command"
Start-Process -FilePath $downloader_exe -ArgumentList "$format $URL $options" -NoNewWindow -Wait
