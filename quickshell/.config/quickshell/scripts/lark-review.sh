#!/usr/bin/env bash
# Ask OpenCode to review / rewrite a task's title and content before it is created
# on Lark. The instructions live in ../todo/lark-review-prompt.md (edit that file to
# tune the result); the original text is appended to it as one JSON object.
#
# Always prints exactly one JSON object and exits 0:
#   {"ok":true,"title":"…","content":"…"}  or  {"ok":false,"error":"<short message>"}
#
# Usage: lark-review.sh <title> <content>
#
# OpenCode runs without --auto and from an empty directory: no tools, no project
# context. Optional LARK_REVIEW_MODEL (provider/model) in ../todo/.env picks the model.

set -uo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
prompt_file="$here/../todo/lark-review-prompt.md"
env_file="$here/../todo/.env"

fail() { jq -nc --arg e "$1" '{ok:false,error:$e}'; exit 0; }

command -v jq >/dev/null || { printf '{"ok":false,"error":"jq not installed"}\n'; exit 0; }
command -v opencode >/dev/null || fail "opencode not installed"
[ -r "$prompt_file" ] || fail "review prompt missing"

model=""
if [ -r "$env_file" ]; then
  model=$(sed -n 's/^LARK_REVIEW_MODEL=//p' "$env_file" | tail -n 1 | tr -d '"\r')
fi

message="$(cat "$prompt_file")
$(jq -nc --arg title "${1:-}" --arg content "${2:-}" '{title:$title,content:$content}')"

work=$(mktemp -d) || fail "review failed"
trap 'rm -rf "$work"' EXIT
cd "$work" || fail "review failed"

args=(run --archived --title "lark-review")
[ -n "$model" ] && args+=(--model "$model")

# stdin from /dev/null: `opencode run` reads a piped stdin as extra input and would
# wait forever on the pipe quickshell leaves open. Run it as a background child so a
# SIGTERM to this script (review cancelled in the panel) is forwarded and opencode
# does not keep running (and billing) for the rest of the timeout.
timeout 60 opencode "${args[@]}" -- "$message" > "$work/out" 2>/dev/null < /dev/null &
child=$!
trap 'kill "$child" 2>/dev/null; exit 0' TERM INT
wait "$child"; rc=$?
out=$(cat "$work/out" 2>/dev/null)
[ $rc -eq 124 ] && fail "review timed out"
[ $rc -eq 0 ] || fail "review failed"

# Keep everything from the first "{" to the last "}" (the model may add a fence or a
# sentence), then make sure it is the object we asked for.
json=$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr '\n' '\r' \
  | sed -n 's/^[^{]*\({.*}\)[^}]*$/\1/p' | tr '\r' '\n')
jq -ce 'select(type == "object" and (.title | type == "string") and (.title | test("\\S")))
        | {ok:true, title:.title, content:(if (.content | type) == "string" then .content else "" end)}' \
  <<< "$json" 2>/dev/null || fail "review failed"
