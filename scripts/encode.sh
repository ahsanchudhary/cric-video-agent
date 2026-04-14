#!/usr/bin/env bash
set -euo pipefail

# === Parallel video encoding + chronological concatenation ===
#
# Usage: encode.sh <input_directory> [--parallel N]
#
# Encodes all media files in <input_directory> using ffmpeg (H.264/AAC, CRF 23).
# Files are encoded in parallel (default: 3 jobs), then concatenated in
# chronological order (by original file modification time) into a single output.
#
# Output file is written to <input_directory>/combined_YYYYMMDD_HHMMSS.mp4

PARALLEL=3
INPUT_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --parallel)
            PARALLEL="$2"
            shift 2
            ;;
        *)
            if [ -z "$INPUT_DIR" ]; then
                INPUT_DIR="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: encode.sh <input_directory> [--parallel N]" >&2
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory not found: $INPUT_DIR" >&2
    exit 1
fi

# Supported media extensions
EXTENSIONS="mp4 mkv ts avi mov webm"

# Find all media files
FILES=()
for ext in $EXTENSIONS; do
    while IFS= read -r -d '' f; do
        FILES+=("$f")
    done < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null)
done

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Error: No media files found in $INPUT_DIR" >&2
    echo "Supported formats: $EXTENSIONS" >&2
    exit 1
fi

echo "Found ${#FILES[@]} media file(s) in $INPUT_DIR"

# Sort files by modification time (chronological order)
# Store as: "mtime\tfilepath" then sort numerically
SORTED_FILES=()
for f in "${FILES[@]}"; do
    if [[ "$(uname -s)" == "Darwin" ]]; then
        mtime=$(stat -f "%m" "$f")
    else
        mtime=$(stat -c "%Y" "$f")
    fi
    echo "${mtime}	${f}"
done | sort -n | while IFS=$'\t' read -r _ fpath; do
    echo "$fpath"
done > /tmp/vw_sorted_files_$$

while IFS= read -r fpath; do
    SORTED_FILES+=("$fpath")
done < /tmp/vw_sorted_files_$$
rm -f /tmp/vw_sorted_files_$$

echo "Files in chronological order:"
for i in "${!SORTED_FILES[@]}"; do
    echo "  $((i+1)). $(basename "${SORTED_FILES[$i]}")"
done
echo ""

# Create temp directory for encoded files
ENCODE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/.encoding_XXXXXX")
trap 'rm -rf "$ENCODE_DIR"' EXIT

# === Parallel encoding ===
echo "Encoding ${#SORTED_FILES[@]} files with $PARALLEL parallel job(s)..."
echo ""

TOTAL=${#SORTED_FILES[@]}
COMPLETED=0
FAILED=0
PIDS=()
ENCODED_FILES=()

# Track pid-to-file mapping
declare -A PID_TO_FILE
declare -A PID_TO_OUTPUT

encode_file() {
    local input="$1"
    local index="$2"
    local basename_noext
    basename_noext="$(basename "${input%.*}")"
    local output="${ENCODE_DIR}/${index}_${basename_noext}.mp4"

    ffmpeg -y -i "$input" \
        -c:v libx264 -crf 23 -preset medium \
        -c:a aac -b:a 128k \
        -loglevel warning -stats \
        "$output" 2>&1 | sed "s/^/  [$(basename "$input")] /"

    echo "$output"
}

# Run encoding jobs with parallelism limit
running=0
job_index=0

for i in "${!SORTED_FILES[@]}"; do
    input="${SORTED_FILES[$i]}"
    padded_index=$(printf "%04d" "$i")
    output="${ENCODE_DIR}/${padded_index}_$(basename "${input%.*}").mp4"
    ENCODED_FILES+=("$output")

    echo "  Starting: $(basename "$input")"

    (
        ffmpeg -y -i "$input" \
            -c:v libx264 -crf 23 -preset medium \
            -c:a aac -b:a 128k \
            -loglevel warning \
            "$output"
    ) &

    PIDS+=($!)
    PID_TO_FILE[$!]="$(basename "$input")"
    running=$((running + 1))

    # Wait if we've hit the parallelism limit
    if [ "$running" -ge "$PARALLEL" ]; then
        for pid in "${PIDS[@]}"; do
            if wait "$pid" 2>/dev/null; then
                COMPLETED=$((COMPLETED + 1))
                echo "  Done ($COMPLETED/$TOTAL): ${PID_TO_FILE[$pid]}"
            else
                FAILED=$((FAILED + 1))
                echo "  FAILED: ${PID_TO_FILE[$pid]}" >&2
            fi
        done
        PIDS=()
        running=0
    fi
done

# Wait for remaining jobs
for pid in "${PIDS[@]}"; do
    if wait "$pid" 2>/dev/null; then
        COMPLETED=$((COMPLETED + 1))
        echo "  Done ($COMPLETED/$TOTAL): ${PID_TO_FILE[$pid]}"
    else
        FAILED=$((FAILED + 1))
        echo "  FAILED: ${PID_TO_FILE[$pid]}" >&2
    fi
done

echo ""
echo "Encoding complete: $COMPLETED succeeded, $FAILED failed out of $TOTAL"

if [ "$FAILED" -gt 0 ]; then
    echo "Error: Some files failed to encode. Check the output above." >&2
    exit 1
fi

# === Concatenation ===
echo ""
echo "Concatenating files in chronological order..."

# Build ffmpeg concat file list
CONCAT_LIST="${ENCODE_DIR}/concat_list.txt"
for f in "${ENCODED_FILES[@]}"; do
    echo "file '${f}'" >> "$CONCAT_LIST"
done

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${INPUT_DIR}/combined_${TIMESTAMP}.mp4"

ffmpeg -y -f concat -safe 0 -i "$CONCAT_LIST" -c copy "$OUTPUT_FILE" -loglevel warning

# Get file size
if [[ "$(uname -s)" == "Darwin" ]]; then
    SIZE_BYTES=$(stat -f "%z" "$OUTPUT_FILE")
else
    SIZE_BYTES=$(stat -c "%s" "$OUTPUT_FILE")
fi
SIZE_GB=$(echo "scale=2; $SIZE_BYTES / 1073741824" | bc)

echo ""
echo "=== Encoding + concatenation complete ==="
echo "  Output: $OUTPUT_FILE"
echo "  Size:   ${SIZE_GB}GB"
