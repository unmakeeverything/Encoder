function Calculate-Bitrate {
    param (
        [string]$FilePath
    )
    $fileSizeBytes = (Get-Item $FilePath).Length
    $videoDuration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $FilePath
    $bitrateKbps = [math]::Round(($fileSizeBytes * 8) / $videoDuration / 1024, 2)
    return $bitrateKbps
}

function Get-AudioChannels {
    param (
        [string]$FilePath
    )
    return & ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 $FilePath
}

function Get-Duration {
    param (
        [string]$FilePath
    )
    return & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $FilePath
}

function Get-FFmpegFormat {
    param (
        [string]$FilePath
    )
    $extension = [System.IO.Path]::GetExtension($FilePath).TrimStart('.')
    switch ($extension) {
        'mkv' { return 'matroska' }
        'mp4' { return 'mp4' }
        default { return $extension }
    }
}

$topLevelDirectory = if ($args[0]) { $args[0] } else { '.' }

Get-ChildItem -Path $topLevelDirectory -Recurse -File | Where-Object { $_.Extension -match 'mp4|mkv|avi' } | ForEach-Object {
    $file = $_.FullName
    $fileSizeMb = ($_.Length / 1MB)
    if ($fileSizeMb -lt 200) {
        Write-Host "Skipping $file due to its size ($fileSizeMb MB) being under 200 MB."
        return
    }

    $bitrate = Calculate-Bitrate -FilePath $file
    $audioChannels = Get-AudioChannels -FilePath $file
    $originalDuration = Get-Duration -FilePath $file
    $ffmpegFormat = Get-FFmpegFormat -FilePath $file

    if ([math]::Round($bitrate, 2) -gt 3800) {
        if (Test-Path -LiteralPath "${file}.tmp") {
            Remove-Item -LiteralPath "${file}.tmp"
            Write-Output "The file '${file}.tmp' has been deleted."
        } else {
            Write-Output "The file '${file}.tmp' does not exist."
        }
        & ffmpeg -hwaccel auto -i $file -nostdin -b:v 2M -minrate 1M -maxrate 10M -c:v libx265 -pix_fmt yuv420p10le -x265-params rc-lookahead=120 -profile:v main10 -c:a aac -b:a 128k -ac 2 -af loudnorm -y -f $ffmpegFormat "${file}.tmp"
        $newDuration = Get-Duration -FilePath "${file}.tmp"
        $durationDiff = [math]::Round(($newDuration - $originalDuration) / $originalDuration, 4)

        if ($durationDiff -lt 0.02 -and $durationDiff -gt -0.02) {
            Move-Item -LiteralPath "${file}.tmp" -Destination $file -Force
            Write-Host "Duration match for $file"
        } else {
            Write-Host "Duration mismatch for $file"
            Remove-Item -LiteralPath "${file}.tmp"
        }
    } elseif ([math]::Round($bitrate, 2) -le 3800) {
        if ($audioChannels -gt 2) {
            if (Test-Path -LiteralPath "${file}.tmp") {
                Remove-Item -LiteralPath "${file}.tmp"
                Write-Output "The file '${file}.tmp' has been deleted."
            } else {
                Write-Output "The file '${file}.tmp' does not exist."
            }
            & ffmpeg -i $file -nostdin -c:v copy -c:a aac -ac 2 -filter:a loudnorm -f $ffmpegFormat "${file}.tmp"
            $newDuration = Get-Duration -FilePath "${file}.tmp"
            $durationDiff = [math]::Round(($newDuration - $originalDuration) / $originalDuration, 4)

            if ($durationDiff -lt 0.02 -and $durationDiff -gt -0.02) {
                Move-Item -LiteralPath "${file}.tmp" -Destination $file -Force
                Write-Host "Duration match for $file"
            } else {
                Write-Host "Duration mismatch for $file"
                Remove-Item -LiteralPath "${file}.tmp"
            }
        }
    }
}
 