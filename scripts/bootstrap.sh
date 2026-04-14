#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"

echo "=== Video Workflow Bootstrap ==="

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="mac" ;;
    Linux)  PLATFORM="linux" ;;
    *)      echo "Error: Unsupported OS: $OS"; exit 1 ;;
esac
echo "Detected platform: $PLATFORM"

# --- Install ffmpeg ---
if command -v ffmpeg &>/dev/null; then
    echo "ffmpeg already installed: $(ffmpeg -version | head -1)"
else
    echo "Installing ffmpeg..."
    if [ "$PLATFORM" = "mac" ]; then
        if ! command -v brew &>/dev/null; then
            echo "Error: Homebrew is required on macOS. Install it from https://brew.sh"
            exit 1
        fi
        brew install ffmpeg
    else
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y ffmpeg
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y ffmpeg
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm ffmpeg
        else
            echo "Error: Could not detect package manager. Please install ffmpeg manually."
            exit 1
        fi
    fi
    echo "ffmpeg installed: $(ffmpeg -version | head -1)"
fi

# --- Install youtubeuploader ---
mkdir -p "$BIN_DIR"

YOUTUBEUPLOADER="$BIN_DIR/youtubeuploader"

if [ -x "$YOUTUBEUPLOADER" ]; then
    echo "youtubeuploader already installed."
else
    echo "Downloading youtubeuploader..."

    # Determine architecture
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) ARCH_SUFFIX="amd64" ;;
        arm64|aarch64) ARCH_SUFFIX="arm64" ;;
        *)             echo "Error: Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    if [ "$PLATFORM" = "mac" ]; then
        OS_SUFFIX="darwin"
    else
        OS_SUFFIX="linux"
    fi

    RELEASE_URL="https://github.com/porjo/youtubeuploader/releases/latest"
    # Fetch the latest release tag
    LATEST_TAG=$(curl -sI "$RELEASE_URL" | grep -i "^location:" | sed 's/.*tag\///' | tr -d '\r\n')

    if [ -z "$LATEST_TAG" ]; then
        echo "Error: Could not determine latest youtubeuploader release."
        exit 1
    fi

    DOWNLOAD_URL="https://github.com/porjo/youtubeuploader/releases/download/${LATEST_TAG}/youtubeuploader_${OS_SUFFIX}_${ARCH_SUFFIX}"

    echo "Downloading from: $DOWNLOAD_URL"
    curl -sL "$DOWNLOAD_URL" -o "$YOUTUBEUPLOADER"
    chmod +x "$YOUTUBEUPLOADER"
    echo "youtubeuploader installed to $YOUTUBEUPLOADER"
fi

echo ""
echo "=== Bootstrap complete ==="
echo "  ffmpeg:           $(which ffmpeg)"
echo "  youtubeuploader:  $YOUTUBEUPLOADER"
