# AGENTS.md — ytsurf-downloader

## Project structure

Single-file Bash application at `ytsurf.sh` (~490 lines). No build step, no test suite.

## Commands

- **Syntax check**: `bash -n ytsurf.sh` — run before committing
- **Bump version**: update `SCRIPT_VERSION` in `ytsurf.sh:17`, version in `ytsurf.rb:6`, and `package.nix:16`
- **Run the script**: `./ytsurf.sh [OPTIONS] [QUERY]`

## Architecture

- Search → select → watch (mpv) or download (yt-dlp), then loop back for next search
- YouTube scraping: parses `ytInitialData` from HTML with `perl -0777 -ne`, extracts data via `jq`; uses continuation tokens for paginated results
- Search results cached 10 min in `~/.cache/ytsurf-downloader/`
- Config at `~/.config/ytsurf-downloader/config` is `source`d as Bash; values must be valid shell
- fzf keybinding: `d` = download, `Enter`/`w` = watch (indicator shown in fzf header)
- CLI `--download` flag persists for the session; keybinding `d` applies per-selection

## Code conventions

- `snake_case` variables, `UPPER_CASE` constants, 2-space indent, `[[ ]]` for tests
- Script uses `set -u` only
- macOS re-execs with Homebrew `bash` at lines 4–10 if available

## Packaging

- **Nix**: `flake.nix` + `package.nix`; wraps script with `wrapProgram` to add deps to `PATH`
- **Homebrew**: formula at `ytsurf.rb`; version must match `ytsurf.sh`

## Dependencies

Required: `yt-dlp`, `mpv`, `jq`, `curl`, `perl`, `fzf`, `ffmpeg`
Optional: `notify-send`
