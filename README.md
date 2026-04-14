# Video Workflow

Encode video files with ffmpeg and upload to YouTube — driven by an LLM agent (Claude Code or Cursor) or run standalone.

## Quick Start

### With an LLM Agent (recommended)

1. Clone this repo and open it in Claude Code or Cursor
2. Set up YouTube credentials (see [YouTube Setup](#youtube-setup) below)
3. Tell the agent: **"encode and upload my videos"**
4. The agent walks you through each step interactively

### Standalone

```bash
./run.sh ~/my-videos --title "My Video Title"
```

Options:
- `--parallel N` — number of concurrent encoding jobs (default: 3)
- `--privacy public|private|unlisted` — YouTube privacy setting (default: public)

### Individual Scripts

```bash
# Install dependencies (ffmpeg + youtubeuploader)
bash scripts/bootstrap.sh

# Encode all files in a directory (parallel, then concatenate chronologically)
bash scripts/encode.sh ~/my-videos --parallel 5

# Upload to YouTube
bash scripts/upload.sh combined_20260414_153000.mp4 --title "My Video" --not-for-kids
```

## What It Does

1. **Bootstrap** — auto-installs `ffmpeg` and `youtubeuploader` (macOS via Homebrew, Linux via apt/dnf)
2. **Encode** — compresses each video file in parallel using H.264/AAC (CRF 23), then concatenates them in chronological order into a single file
3. **Upload** — uploads the combined file to YouTube with resumable upload support (handles large files)

## YouTube Setup

`client_secrets.json` is included in this repo — no API setup needed.

On first upload, a browser window opens asking you to sign in with your Google account and authorize access to your YouTube channel. The token is saved locally for future uploads.

## Requirements

- macOS or Linux
- Internet connection (for bootstrap + upload)
- A Google account with a YouTube channel

ffmpeg and youtubeuploader are installed automatically by `scripts/bootstrap.sh`.

## Supported Formats

Input: `.mp4`, `.mkv`, `.ts`, `.avi`, `.mov`, `.webm`

Output: `.mp4` (H.264 video, AAC audio)
