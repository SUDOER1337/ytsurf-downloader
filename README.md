# ytsurf-downloader

Search, watch, or download YouTube videos from your terminal. A stripped fork of [ytsurf](https://github.com/Stan-breaks/ytsurf) — no subscriptions, history, playlists, or syncplay.

## Dependencies

**Required:** `bash`, `yt-dlp`, `mpv`, `jq`, `curl`, `perl`, `fzf`, `ffmpeg`
**Optional:** `notify-send`

## Usage

```bash
USAGE:
  ytsurf-downloader [OPTIONS] [QUERY]

OPTIONS:
  --audio         Download/watch audio-only
  --download, -d  Download instead of playing
  --format, -f    Choose format/resolution interactively
  --limit, -l <N> Limit search results (default: 15)
  --debug         Enable debug logging
  --help, -h      Show help
  --version       Show version

KEYBINDINGS (fzf):
  Enter / w       Watch with mpv
  d               Download

EXAMPLES:
  ytsurf-downloader lo-fi study mix
  ytsurf-downloader --audio orchestral soundtrack
  ytsurf-downloader --download --format jazz piano
```

## Configuration

`~/.config/ytsurf-downloader/config` — CLI flags override.

```bash
limit=25
audio_only=true
download_dir="$HOME/Videos/YouTube"
```

## License

GNU General Public License v3.0
