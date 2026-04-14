#!/usr/bin/env bash
set -euo pipefail

# === YouTube Upload ===
#
# Usage: upload.sh <file> --title "Video Title" [--privacy public|private|unlisted] [--not-for-kids]
#
# Uploads a video file to YouTube using youtubeuploader.
# Requires client_secrets.json in the repo root (see config.env.example for setup).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
YOUTUBEUPLOADER="$REPO_DIR/bin/youtubeuploader"

FILE=""
TITLE=""
PRIVACY="public"
NOT_FOR_KIDS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --title)
            TITLE="$2"
            shift 2
            ;;
        --privacy)
            PRIVACY="$2"
            shift 2
            ;;
        --not-for-kids)
            NOT_FOR_KIDS=true
            shift
            ;;
        --for-kids)
            NOT_FOR_KIDS=false
            shift
            ;;
        *)
            if [ -z "$FILE" ]; then
                FILE="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$FILE" ]; then
    echo "Usage: upload.sh <file> --title \"Video Title\" [--privacy public|private|unlisted] [--not-for-kids]" >&2
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
fi

if [ -z "$TITLE" ]; then
    echo "Error: --title is required" >&2
    exit 1
fi

# Check youtubeuploader exists
if [ ! -x "$YOUTUBEUPLOADER" ]; then
    echo "Error: youtubeuploader not found. Run scripts/bootstrap.sh first." >&2
    exit 1
fi

# Check for client_secrets.json (shipped with the repo)
SECRETS_FILE="$REPO_DIR/client_secrets.json"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: client_secrets.json not found in $REPO_DIR" >&2
    echo "This file should be included in the repo. Try re-cloning." >&2
    exit 1
fi

# Build metadata JSON
if [ "$NOT_FOR_KIDS" = true ]; then
    MADE_FOR_KIDS="false"
else
    MADE_FOR_KIDS="true"
fi

# Create a temporary metadata file
META_FILE=$(mktemp /tmp/vw_meta_XXXXXX.json)
trap 'rm -f "$META_FILE"' EXIT

cat > "$META_FILE" <<EOF
{
  "title": "$TITLE",
  "privacyStatus": "$PRIVACY",
  "madeForKids": $MADE_FOR_KIDS
}
EOF

# Get file size for progress info
if [[ "$(uname -s)" == "Darwin" ]]; then
    SIZE_BYTES=$(stat -f "%z" "$FILE")
else
    SIZE_BYTES=$(stat -c "%s" "$FILE")
fi
SIZE_GB=$(echo "scale=2; $SIZE_BYTES / 1073741824" | bc)

echo "=== YouTube Upload ==="
echo "  File:    $FILE (${SIZE_GB}GB)"
echo "  Title:   $TITLE"
echo "  Privacy: $PRIVACY"
echo "  Kids:    $([ "$NOT_FOR_KIDS" = true ] && echo "Not made for kids" || echo "Made for kids")"
echo ""
echo "Uploading... (progress lines show speed, bytes, and ETA)"
echo ""

# Run youtubeuploader
"$YOUTUBEUPLOADER" \
    -filename "$FILE" \
    -title "$TITLE" \
    -privacy "$PRIVACY" \
    -metaJSON "$META_FILE" \
    -secrets "$SECRETS_FILE"

echo ""
echo "=== Upload complete ==="
