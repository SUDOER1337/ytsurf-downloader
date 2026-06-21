#!/usr/bin/env bash

# Re-exec with newer bash on macOS if available
if [ -z "$BASH_VERSION" ]; then
  if [ "$(uname)" = "Darwin" ] && [ -x /opt/homebrew/bin/bash ]; then
    exec /opt/homebrew/bin/bash "$0" "$@"
  elif command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  fi
fi

set -u
#=============================================================================
# CONSTANTS AND DEFAULTS
#=============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="ytsurf-downloader"

DEFAULT_LIMIT=15
DEFAULT_AUDIO_ONLY=false
DEFAULT_DOWNLOAD_MODE=false
DEFAULT_FORMAT_SELECTION=false
DEFAULT_NOTIFY=true

# System directories
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$SCRIPT_NAME"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$SCRIPT_NAME"
readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly LOG_FILE="$CACHE_DIR/$SCRIPT_NAME.log"

#=============================================================================
# GLOBAL VARIABLES
#=============================================================================

limit="$DEFAULT_LIMIT"
audio_only="$DEFAULT_AUDIO_ONLY"
download_mode="$DEFAULT_DOWNLOAD_MODE"
format_selection="$DEFAULT_FORMAT_SELECTION"
format_code="bestvideo[height<=720]+bestaudio/best"
download_dir="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
notify="$DEFAULT_NOTIFY"

query=""
TMPDIR=""

command -v notify-send >/dev/null 2>&1 && notify=true || notify=false

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Send notifications to terminal and desktop (if notify-send available)
send_notification() {
  if [ -z "${2:-}" ]; then
    printf "\33[2K\r\033[1;34m%s\n\033[0m" "$1"
  else
    printf "\33[2K\r\033[1;34m%s - %s\n\033[0m" "$1" "$2"
    [ "$notify" = true ] && notify-send "$1" "$2" -t 5000
  fi
}

print_help() {
  cat <<EOF
$SCRIPT_NAME - search, watch, or download YouTube videos from your terminal

USAGE:
  $SCRIPT_NAME [OPTIONS] [QUERY]

OPTIONS:
  --audio         Download/watch audio-only version
  --download, -d  Download instead of playing
  --format, -f    Interactively choose format/resolution
  --limit, -l <N> Limit search results (default: $DEFAULT_LIMIT)
  --debug         Enable debug logging
  --help, -h      Show this help message
  --version       Show version info

KEYBINDINGS (in search results):
  Enter / w       Watch with mpv
  d               Download selected video

CONFIG:
  $CONFIG_FILE can contain default options like:
    limit=5
    audio_only=true
    download_dir="\$HOME/Videos/YouTube"

EXAMPLES:
  $SCRIPT_NAME lo-fi study mix
  $SCRIPT_NAME --audio orchestral soundtrack
  $SCRIPT_NAME --download --format jazz piano
EOF
}

print_version() {
  echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

#=============================================================================
# SETUP
#=============================================================================

configuration() {
  mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

  if [ ! -f "$CONFIG_FILE" ]; then
    cat >"$CONFIG_FILE" <<'EOF'
#limit=10
#audio_only=false
#download_mode=false
#format_selection=false
#download_dir="$HOME/Downloads"
#notify=true
#debug_mode=false
EOF
  fi
  # shellcheck disable=SC1090
  [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
}

setup_cleanup() {
  TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t ytsurf.XXXXXX)
  trap 'rm -rf "$TMPDIR"' EXIT
}

check_dependencies() {
  local missing_deps=()
  local required_deps=("yt-dlp" "jq" "curl" "perl")

  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if ! command -v "fzf" &>/dev/null; then
    missing_deps+=("fzf")
  fi

  if ! command -v "mpv" &>/dev/null; then
    missing_deps+=("mpv")
  fi

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    send_notification "Error" "Missing required dependencies: ${missing_deps[*]}"
    exit 1
  fi
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h)
      print_help
      exit 0
      ;;
    --version | -V)
      print_version
      exit 0
      ;;
    --audio)
      audio_only=true
      shift
      ;;
    --download | -d)
      download_mode=true
      shift
      ;;
    --format | -f)
      format_selection=true
      shift
      ;;
    --debug)
      rm -f "$LOG_FILE"
      exec 3>>"$LOG_FILE"
      BASH_XTRACEFD=3
      set -x
      shift
      ;;
    --limit | -l)
      shift
      if [[ -n "${1:-}" && "$1" =~ ^[0-9]+$ ]]; then
        limit="$1"
        shift
      else
        send_notification "Error" "--limit requires a number"
        exit 1
      fi
      ;;
    *)
      query="$*"
      break
      ;;
    esac
  done
}

#=============================================================================
# FORMAT SELECTION
#=============================================================================

select_format() {
  local video_url="$1"

  if [[ "$audio_only" = true ]]; then
    echo "bestaudio"
    return 0
  fi

  local format_list
  if ! format_list=$(yt-dlp -F "$video_url" 2>/dev/null); then
    echo "Error: Could not retrieve formats for the selected video." >&2
    return 1
  fi

  local format_options=()
  mapfile -t format_options < <(echo "$format_list" | grep -oE '[0-9]+p[0-9]*' | sort -rn | uniq)

  if [[ ${#format_options[@]} -eq 0 ]]; then
    echo "Error: No video formats found." >&2
    return 1
  fi

  local chosen_res
  chosen_res=$(printf "%s\n" "${format_options[@]}" | fzf --prompt="Select video quality:" --header="Available Resolutions")

  if [[ -z "$chosen_res" ]]; then
    return 1
  fi

  local chosen_format
  if [[ "$chosen_res" == "best" || "$chosen_res" == "worst" ]]; then
    chosen_format="$chosen_res"
  else
    local height=${chosen_res%p*}
    chosen_format="bestvideo[height<=${height}]+bestaudio/best"
  fi

  echo "$chosen_format"
  return 0
}

#=============================================================================
# VIDEO ACTIONS
#=============================================================================

download_video() {
  local video_url="$1"
  local fmt="$2"

  mkdir -p "$download_dir"
  send_notification "Ytsurf" "Downloading to $download_dir..."

  local yt_dlp_args=(
    -o "$download_dir/%(title)s [%(id)s].%(ext)s"
    --audio-quality 0
    --quiet
  )

  if [[ "$audio_only" = true ]]; then
    yt_dlp_args+=(-x --audio-format mp3)
  else
    yt_dlp_args+=(--remux-video mp4)
    if [[ -n "$fmt" ]]; then
      yt_dlp_args+=(--format "$fmt")
    fi
  fi

  yt-dlp "${yt_dlp_args[@]}" "$video_url"
  send_notification "Ytsurf" "Download complete"
}

play_video() {
  local video_url="$1"
  local fmt="$2"

  local player="mpv"
  player="$player --keep-open=no --really-quiet"
  [[ "$audio_only" == true ]] && player="$player --no-video"
  [[ -n "$fmt" ]] && player="$player --ytdl-format=\"$fmt\""
  player="$player $video_url"
  eval "$player"
}

#=============================================================================
# SEARCH
#=============================================================================

get_search_query() {
  if [[ -z "$query" ]]; then
    read -rp "Enter YouTube search (empty to exit): " query
  fi

  if [[ -z "$query" ]]; then
    echo "No query entered. Exiting."
    exit 1
  fi
}

fetch_search_results() {
  local cache_key cache_file

  cache_key=$(echo -n "$query" | sha256sum | cut -d' ' -f1)
  cache_file="$CACHE_DIR/$cache_key.json"

  if [[ -f "$cache_file" && $(find "$cache_file" -mmin -10 2>/dev/null) ]]; then
    json_data=$(cat "$cache_file")
    return 0
  fi

  local encoded_query
  encoded_query=$(printf '%s' "$query" | jq -sRr @uri)

  response=$(curl -s --compressed --http1.1 --keepalive-time 30 "https://www.youtube.com/results?search_query=${encoded_query}&sp=EgIQAQ%253D%253D&hl=en&gl=US" |
    perl -0777 -ne 'print $1 if /var ytInitialData = (.*?);\s*<\/script>/s')

  json_data=$(echo "$response" |
    jq -r --argjson limit "$limit" "
      [
        .. | objects |
        select(has(\"videoRenderer\")) |
        .videoRenderer | {
          title: .title.runs[0].text,
          id: .videoId,
          author: .longBylineText.runs[0].text,
          published: .publishedTimeText.simpleText,
          duration: .lengthText.simpleText,
          views: .viewCountText.simpleText,
          thumbnail: (.thumbnail.thumbnails | sort_by(.width) | last.url)
        }
      ] | .[:$limit]
      " 2>/dev/null)

  continuation_token=$(echo "$response" | jq -r "
      .. |objects|
        select(has(\"continuationItemRenderer\")) |
        .continuationItemRenderer.continuationEndpoint.continuationCommand.token |
        select(.!=null)
      " | head -1)

  while [[ $(jq 'length' <<<"$json_data") -lt "$limit" && -n "$continuation_token" ]]; do
    sleep 1
    body=$(jq -n \
      --arg continuation "$continuation_token" \
      '{
                context: {
                    client: {
                        clientName: "WEB",
                        clientVersion: "2.20220101.00.00"
                    }
                },
                continuation: $continuation
            }')

    next_response=$(curl -s --compressed --http1.1 \
      -H "Content-Type: application/json" \
      -d "$body" \
      "https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO90d0o_cimLECsGBARHaB_YvqXMCm5Bk")

    next_json=$(echo "$next_response" |
      jq -r "
      [
        .. | objects |
        select(has(\"videoRenderer\")) |
        .videoRenderer | {
          title: .title.runs[0].text,
          id: .videoId,
          author: .longBylineText.runs[0].text,
          published: .publishedTimeText.simpleText,
          duration: .lengthText.simpleText,
          views: .viewCountText.simpleText,
          thumbnail: (.thumbnail.thumbnails | sort_by(.width) | last.url)
        }
      ]
      " 2>/dev/null)

    if [[ -z "$next_json" || "$next_json" == "[]" ]]; then
      break
    fi

    continuation_token=$(echo "$next_response" | jq -r "
      .. |objects|
        select(has(\"continuationItemRenderer\")) |
        .continuationItemRenderer.continuationEndpoint.continuationCommand.token |
        select(.!=null)
      " | head -1)

    json_data=$(jq -s 'add | unique_by(.id)' <<<"$json_data"$'\n'"$next_json" | jq -r --argjson limit "$limit" "
      .[:$limit]
      ")
  done

  echo "$json_data" >"$cache_file"
}

handle_selection() {
  get_search_query
  fetch_search_results

  [[ "$json_data" == "[]" ]] && {
    send_notification "Error" "No results found for '$query'"
    exit 1
  }

  local menu_list=()
  mapfile -t menu_list < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

  [ ${#menu_list[@]} -eq 0 ] && {
    send_notification "Error" "No results found for '$query'"
    exit 0
  }

  local selected_line
  selected_line=$(printf "%s\n" "${menu_list[@]}" | fzf \
    --prompt="Search YouTube: " \
    --header="[d] Download  [w] Watch  [Enter] Watch" \
    --bind="d:accept" \
    --expect="d,w,enter")

  local key_pressed
  key_pressed=$(head -1 <<<"$selected_line")
  local selected_title
  selected_title=$(tail -1 <<<"$selected_line")

  [ -n "$selected_title" ] || {
    send_notification "Error" "No selection made."
    exit 1
  }

  local selected_index=-1
  for i in "${!menu_list[@]}"; do
    [ "${menu_list[$i]}" == "$selected_title" ] && {
      selected_index=$i
      break
    }
  done

  [ "$selected_index" -lt 0 ] && {
    send_notification "Error" "Could not resolve selected video."
    exit 1
  }

  local video_id
  video_id=$(echo "$json_data" | jq -r ".[$selected_index].id")
  video_url="https://www.youtube.com/watch?v=$video_id"

  # CLI --download flag persists; keybinding applies per-selection
  local do_download="$download_mode"
  [[ "$key_pressed" == "d" ]] && do_download=true

  local fmt="$format_code"
  if [[ "$format_selection" == true ]]; then
    local selected_fmt
    selected_fmt=$(select_format "$video_url") || {
      send_notification "Format selection cancelled."
      exit 1
    }
    fmt="$selected_fmt"
  fi

  if [[ "$do_download" == true ]]; then
    send_notification "Ytsurf" "Downloading $selected_title"
    download_video "$video_url" "$fmt"
  else
    send_notification "Ytsurf" "Playing $selected_title"
    play_video "$video_url" "$fmt"
  fi

  query=""
}

#=============================================================================
# MAIN
#=============================================================================

main() {
  while :; do
    handle_selection
  done
}

configuration
setup_cleanup
parse_arguments "$@"
check_dependencies
main
