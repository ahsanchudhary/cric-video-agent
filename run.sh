#!/usr/bin/env bash
set -euo pipefail

# === Video Workflow: Fully Automated Mode ===
#
# Usage: ./run.sh <input_directory> --title "Video Title" [--parallel N] [--privacy public|private|unlisted]
#
# Runs the complete workflow: bootstrap -> encode -> upload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT_DIR=""
TITLE=""
PARALLEL=3
PRIVACY="public"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --title)
            TITLE="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL="$2"
            shift 2
            ;;
        --privacy)
            PRIVACY="$2"
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

if [ -z "$INPUT_DIR" ] || [ -z "$TITLE" ]; then
    echo "Usage: ./run.sh <input_directory> --title \"Video Title\" [--parallel N] [--privacy public|private|unlisted]" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  ./run.sh ~/recordings/april --title \"April Recordings\"" >&2
    echo "  ./run.sh ~/recordings/april --title \"April Recordings\" --parallel 5 --privacy private" >&2
    exit 1
fi

echo "============================================"
echo "  Video Workflow"
echo "============================================"
echo ""

# Step 1: Bootstrap
echo "--- Step 1: Bootstrap ---"
bash "$SCRIPT_DIR/scripts/bootstrap.sh"
echo ""

# Step 2: Encode (stream to terminal so ffmpeg progress is visible; also save log for path parsing)
echo "--- Step 2: Encode ---"
ENCODE_LOG=$(mktemp "${TMPDIR:-/tmp}/vw_encode_XXXXXX.log")
set +e
bash "$SCRIPT_DIR/scripts/encode.sh" "$INPUT_DIR" --parallel "$PARALLEL" 2>&1 | tee "$ENCODE_LOG"
ENCODE_STATUS=${PIPESTATUS[0]}
set -e
OUTPUT_FILE=$(grep "Output:" "$ENCODE_LOG" | tail -1 | sed 's/.*Output: //')
rm -f "$ENCODE_LOG"

if [ "$ENCODE_STATUS" -ne 0 ]; then
    echo "Error: Encode step failed." >&2
    exit 1
fi

if [ -z "$OUTPUT_FILE" ] || [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Could not determine encoded output file." >&2
    exit 1
fi
echo ""

# Step 3: Upload
echo "--- Step 3: Upload ---"
bash "$SCRIPT_DIR/scripts/upload.sh" "$OUTPUT_FILE" --title "$TITLE" --privacy "$PRIVACY" --not-for-kids

echo ""
echo "============================================"
echo "  Workflow complete!"
echo "============================================"
