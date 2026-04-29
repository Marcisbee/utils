#!/bin/bash

# Usage: ./serve.sh [port] [root_directory]

set -u

PORT="${1:-8000}"
ROOT="${2:-.}"

if ! command -v nc >/dev/null 2>&1; then
  echo "Error: nc was not found on this machine." >&2
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
    *.svg) printf 'image/svg+xml' ;;
    *.png) printf 'image/png' ;;
    *.jpg|*.jpeg) printf 'image/jpeg' ;;
    *.gif) printf 'image/gif' ;;
    *.webp) printf 'image/webp' ;;
    *.ico) printf 'image/x-icon' ;;
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
  printf 'Connection: close\r\n'
  printf '\r\n'
  printf '%s' "$body"
}

handle_request() {
  local request_line method target path file content_type content_length header

  IFS= read -r request_line || return
  request_line="${request_line%$'\r'}"

  method="${request_line%% *}"
  target="${request_line#* }"
  target="${target%% *}"
  target="${target%%\?*}"

  while IFS= read -r header; do
    header="${header%$'\r'}"
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
    send_text "404 Not Found" "Not found: /$path"
    return
  fi

  content_type="$(mime_type "$file")"
  content_length="$(wc -c < "$file" | tr -d ' ')"

  printf 'HTTP/1.1 200 OK\r\n'
  printf 'Content-Type: %s\r\n' "$content_type"
  printf 'Content-Length: %s\r\n' "$content_length"
  printf 'Connection: close\r\n'
  printf '\r\n'

  if [[ "$method" == "GET" ]]; then
    cat "$file"
  fi
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
