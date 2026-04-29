#!/bin/bash

# Usage: ./serve.sh [port] [root_directory] [--spa]

set -u

SPA_MODE=false
ARGS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --spa)
      SPA_MODE=true
      ;;
    *)
      ARGS+=("$1")
      ;;
  esac
  shift
done

PORT="${ARGS[0]:-8000}"
ROOT="${ARGS[1]:-.}"

if ! command -v nc >/dev/null 2>&1; then
  echo "Error: nc was not found on this machine." >&2
  exit 1
fi

if ! nc -h 2>&1 | grep -Eq '(^|[[:space:]])-k([^[:alpha:]]|$)|\[[^]]*k[^]]*\]'; then
  echo "Error: this script requires an nc version that supports the -k option." >&2
  exit 1
fi

if [[ ! -d "$ROOT" ]]; then
  echo "Error: root directory does not exist: $ROOT" >&2
  exit 1
fi

ROOT="$(cd "$ROOT" && pwd)"
SERVER_TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$SERVER_TMPDIR"
}

trap cleanup EXIT
trap 'exit 0' INT TERM

mime_type() {
  case "$1" in
    *.html|*.htm) printf 'text/html; charset=utf-8' ;;
    *.css) printf 'text/css; charset=utf-8' ;;
    *.js|*.mjs) printf 'application/javascript; charset=utf-8' ;;
    *.json) printf 'application/json; charset=utf-8' ;;
    *.map) printf 'application/json; charset=utf-8' ;;
    *.svg) printf 'image/svg+xml' ;;
    *.png) printf 'image/png' ;;
    *.jpg|*.jpeg) printf 'image/jpeg' ;;
    *.gif) printf 'image/gif' ;;
    *.webp) printf 'image/webp' ;;
    *.avif) printf 'image/avif' ;;
    *.ico) printf 'image/x-icon' ;;
    *.wasm) printf 'application/wasm' ;;
    *.woff) printf 'font/woff' ;;
    *.woff2) printf 'font/woff2' ;;
    *.ttf) printf 'font/ttf' ;;
    *.otf) printf 'font/otf' ;;
    *.pdf) printf 'application/pdf' ;;
    *.xml) printf 'application/xml; charset=utf-8' ;;
    *.csv) printf 'text/csv; charset=utf-8' ;;
    *.mp4) printf 'video/mp4' ;;
    *.webm) printf 'video/webm' ;;
    *.mov) printf 'video/quicktime' ;;
    *.mp3) printf 'audio/mpeg' ;;
    *.wav) printf 'audio/wav' ;;
    *.ogg) printf 'audio/ogg' ;;
    *.txt) printf 'text/plain; charset=utf-8' ;;
    *) printf 'application/octet-stream' ;;
  esac
}

url_decode() {
  local value="${1//+/ }"
  printf '%b' "${value//%/\\x}"
}

send_text() {
  local status="$1"
  local body="$2"

  printf 'HTTP/1.1 %s\r\n' "$status"
  printf 'Content-Type: text/plain; charset=utf-8\r\n'
  printf 'Content-Length: %s\r\n' "${#body}"
  printf 'Cache-Control: no-store\r\n'
  printf 'Connection: close\r\n'
  printf '\r\n'
  printf '%s' "$body"
}

send_file() {
  local file="$1"
  local method="$2"
  local content_type content_length

  content_type="$(mime_type "$file")"
  content_length="$(wc -c < "$file" | tr -d ' ')"

  printf 'HTTP/1.1 200 OK\r\n'
  printf 'Content-Type: %s\r\n' "$content_type"
  printf 'Content-Length: %s\r\n' "$content_length"
  printf 'Cache-Control: no-store\r\n'
  printf 'Connection: close\r\n'
  printf '\r\n'

  if [[ "$method" == "GET" ]]; then
    cat "$file"
  fi
}

handle_request() {
  local request_line method target path file header accept_header
  accept_header=""

  IFS= read -r request_line || return
  request_line="${request_line%$'\r'}"

  method="${request_line%% *}"
  target="${request_line#* }"
  target="${target%% *}"
  target="${target%%\?*}"

  while IFS= read -r header; do
    header="${header%$'\r'}"
    case "$header" in
      [Aa][Cc][Cc][Ee][Pp][Tt]:*)
        accept_header="${header#*:}"
        ;;
    esac
    [[ -z "$header" ]] && break
  done

  if [[ "$method" != "GET" && "$method" != "HEAD" ]]; then
    send_text "405 Method Not Allowed" "Only GET and HEAD are supported."
    return
  fi

  path="$(url_decode "$target")"
  [[ "$path" == "/" ]] && path="/index.html"
  path="${path#/}"

  if [[ -z "$path" || "$path" == /* || "$path" == ".." || "$path" == ../* || "$path" == */../* || "$path" == */.. ]]; then
    send_text "403 Forbidden" "Forbidden."
    return
  fi

  file="$ROOT/$path"
  [[ -d "$file" ]] && file="$file/index.html"

  if [[ ! -f "$file" ]]; then
    if [[ "$SPA_MODE" == "true" && -f "$ROOT/index.html" ]] && [[ "$path" != *.* || "$accept_header" == *text/html* ]]; then
      send_file "$ROOT/index.html" "$method"
      return
    fi

    send_text "404 Not Found" "Not found: /$path"
    return
  fi

  send_file "$file" "$method"
}

echo "Serving $ROOT at http://localhost:$PORT/"
echo "Press Ctrl+C to stop."

RESPONSE_FIFO="$SERVER_TMPDIR/response"
mkfifo "$RESPONSE_FIFO" || exit 1

# Keep the FIFO open so nc does not see EOF after the first response.
exec 3<> "$RESPONSE_FIFO"

nc -lk "$PORT" < "$RESPONSE_FIFO" | while true; do
  handle_request > "$RESPONSE_FIFO"
done
