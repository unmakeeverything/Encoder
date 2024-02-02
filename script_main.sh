#!/bin/bash

# Function to calculate bitrate
calculate_bitrate() {
    local file_size_bytes=$(wc -c < "$1")
    local video_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1")

    # Calculate bit rate in kilobits per second (kbps)
    local bitrate_kbps=$(echo "scale=2; ($file_size_bytes * 8) / $video_duration / 1024" | bc)
    echo $bitrate_kbps
}

# Function to get the number of audio channels
get_audio_channels() {
    ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$1"
}

# Function to get the duration of a video file
get_duration() {
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

# Extract file extension and determine format for ffmpeg
get_ffmpeg_format() {
    local extension="${1##*.}"
    if [ "$extension" = "mkv" ]; then
        echo "matroska"
    elif [ "$extension" = "mp4" ]; then
        echo "mp4"
    else
        echo "$extension"
    fi
}

# Define top-level directory
top_level_directory="${1:-.}"

# Main loop to process files
find "$top_level_directory" -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.avi' \) | while read file; do
    # Check file size, skip files under 200 MB
    file_size_mb=$(stat -c %s "$file")
    file_size_mb=$((file_size_mb / 1024 / 1024))
    if [ "$file_size_mb" -lt 200 ]; then
        echo "Skipping $file due to its size ($file_size_mb MB) being under 200 MB."
        continue # Skip to the next file
    fi

    bitrate=$(calculate_bitrate "$file")
    audio_channels=$(get_audio_channels "$file")
    original_duration=$(get_duration "$file")
    ffmpeg_format=$(get_ffmpeg_format "$file")

    if (( $(echo "$bitrate > 3800" | bc -l) )); then
        # Convert video over 3800 kbps to HEVC with 2000 kbps bitrate
        ffmpeg -hwaccel auto -i "$file" -nostdin -b:v 2M -minrate 1M -maxrate 10M -c:v libx265 -pix_fmt yuv420p10le -x265-params rc-lookahead=120 -profile:v main10 -c:a aac -b:a 128k -ac 2 -af loudnorm -y -f "$ffmpeg_format" "${file}.tmp"

        new_duration=$(get_duration "${file}.tmp")
        duration_diff=$(echo "($new_duration - $original_duration) / $original_duration" | bc -l)

        # Check if the new duration is within 2% of the original
        if (( $(echo "($duration_diff < 0.02) && ($duration_diff > -0.02)" | bc -l) )); then
            mv "${file}.tmp" "$file"
        else
            echo "Duration mismatch for $file"
            rm "${file}.tmp"
        fi
    elif (( $(echo "$bitrate <= 3800" | bc -l) )); then
        if [ "$audio_channels" -gt "2" ]; then
            # Normalize audio and convert to 2 channels for files under 3800 kbps with more than 2 audio channels
            ffmpeg -i "$file" -nostdin -c:v copy -c:a aac -ac 2 -filter:a loudnorm -f "$ffmpeg_format" "${file}.tmp"

            new_duration=$(get_duration "${file}.tmp")
            duration_diff=$(echo "($new_duration - $original_duration) / $original_duration" | bc -l)

            # Check if the new duration is within 2% of the original
            if (( $(echo "($duration_diff < 0.02) && ($duration_diff > -0.02)" | bc -l) )); then
                mv "${file}.tmp" "$file"
            else
                echo "Duration mismatch for $file"
                rm "${file}.tmp"
            fi
        fi
    fi
done
