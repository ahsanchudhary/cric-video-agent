# Video Workflow Agent Instructions

You are an agent that helps users encode video files and upload them to YouTube.
This file tells you how to orchestrate the workflow using the shell scripts in this repo.

## Prerequisites

Before running any workflow steps, ensure tools are installed:

```bash
bash scripts/bootstrap.sh
```

This is idempotent — safe to run every time. It installs `ffmpeg` and `youtubeuploader` if missing.

## Workflow

### Step 1: Get Input Directory

Ask the user: **"What directory are your video files in?"**

Once they provide a path, verify it exists and list the media files found:

```bash
ls -la <directory>/*.{mp4,mkv,ts,avi,mov,webm} 2>/dev/null
```

Report the number of files and total size to the user.

### Step 2: Encode

Ask the user: **"I'll encode these files in parallel with 3 concurrent jobs. Want to change the parallelization?"**

Default is 3. Then run:

```bash
bash scripts/encode.sh <input_directory> --parallel <N>
```

**What to monitor:**
- Progress lines showing which files are done (e.g., `Done (5/12): filename.mp4`)
- Any `FAILED` lines indicate a file that couldn't be encoded

**On success:** The script prints the combined output file path and size. Report both to the user.

**On failure:** Report which file(s) failed and ask the user if they want to:
- Retry the entire encode
- Skip the failed files and continue

### Step 3: Upload

Ask the user: **"What title do you want for the YouTube video?"**

Then run:

```bash
bash scripts/upload.sh <combined_file> --title "<title>" --privacy public --not-for-kids
```

**First-time OAuth:** If this is the first upload, `youtubeuploader` will print a URL and ask the user to visit it in their browser to authorize. Tell the user to follow the OAuth prompt. The token is saved for future uploads.

**On success:** Report the YouTube video URL to the user.

**On failure:** Check if:
- `client_secrets.json` is missing → guide user through API setup (see config.env.example)
- OAuth token expired → ask user to re-authorize
- Network error → suggest retry

### Defaults

- **Privacy:** public
- **Made for kids:** false (not made for kids)
- **Description:** none
- **Parallelism:** 3

## Modes of Operation

### Mode A: Orchestrator
The user says something like "encode and upload my videos." Run the full workflow above, asking questions at each step.

### Mode B: Step-by-Step (Primary)
Walk the user through each step interactively. Explain what each script does before running it. This is the default mode.

### Mode C: Fully Automated
Direct the user to run the single command:

```bash
./run.sh <input_directory> --title "Video Title" [--parallel N]
```

## File Locations

| File | Purpose |
|------|---------|
| `scripts/bootstrap.sh` | Installs ffmpeg + youtubeuploader |
| `scripts/encode.sh` | Parallel encoding + chronological concatenation |
| `scripts/upload.sh` | YouTube upload with metadata |
| `run.sh` | Single-command automated mode |
| `client_secrets.json` | YouTube OAuth credentials (user must create) |
| `config.env.example` | Setup instructions for credentials |

## Error Recovery

- **ffmpeg not found:** Run `scripts/bootstrap.sh`
- **youtubeuploader not found:** Run `scripts/bootstrap.sh`
- **No media files found:** Check the directory path and supported formats (.mp4, .mkv, .ts, .avi, .mov, .webm)
- **Encoding failed on a file:** Report the filename, ask user to skip or retry
- **Upload failed — no client_secrets.json:** Guide user through Google Cloud Console setup
- **Upload failed — auth error:** Ask user to re-authorize via browser
- **Upload failed — network:** Suggest retry (youtubeuploader supports resumable uploads)
