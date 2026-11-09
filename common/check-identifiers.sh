#!/bin/bash
# check-identifiers.sh [--cached | --dir <folder>] [--message <file>]
# Counts where the personal identifiers of THIS Mac appear in what is about to be public: by default
# the tracked files of this repo as they are on disk, with --cached the staged tree, with --dir any
# folder (a tree not yet in git). File names are scanned too, and with --message a commit message.
# The identifiers are read from the machine at run time and never printed: the output is one count
# per class. Nothing identifying lives in this file.
#   exit 0 = the total equals ACCEPT (default 0)      ACCEPT=<n> = the repo's recorded residual
# Classes: Steam ID64 and account id, Steam login and display name (every Steam config found under
# ~/Applications/*.app and the native client), the personal git login, address and numeric id (global
# git config), the home folder's user name as /Users/<name> or users\<name>, the Mac's names (scutil)
# and ssh HostName values. Plus two patterns that need no source: any SteamID64, and any [U:1:<n>] with
# five or more digits ([U:1:0] is Steam's logged-off id and appears in quoted logs).
set -u
MODE=tracked; DIR=""; MSG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cached) MODE=cached; shift ;;
    --dir) MODE=dir; DIR="${2:-}"; shift 2 ;;
    --message) MSG="${2:-}"; shift 2 ;;
    *) echo "usage: check-identifiers.sh [--cached | --dir <folder>] [--message <file>]"; exit 64 ;;
  esac
done
REPO="$(cd "$(dirname "$0")/.." && pwd)"
K="$(mktemp /tmp/check-identifiers.XXXXXX)"; chmod 600 "$K"; trap 'rm -f "$K"' EXIT
add() { local v; v="$(printf '%s' "$2" | tr -d '\r')"; [ "${#v}" -ge "${3:-5}" ] && printf '%s\t%s\n' "$1" "$v" >> "$K"; return 0; }

for cfg in "$HOME/Library/Application Support/Steam" "$HOME"/Applications/*.app/Contents/SharedSupport/prefix/drive_c/"Program Files (x86)"/Steam; do
  [ -f "$cfg/config/loginusers.vdf" ] || continue
  for v in $(grep -oE '"7656119[0-9]{10}"' "$cfg/config/loginusers.vdf" | tr -d '"'); do add steam-id64 "$v"; done
  add steam-login   "$(awk -F'"' '/"AccountName"/{print $4; exit}' "$cfg/config/loginusers.vdf")" 6
  add steam-display "$(awk -F'"' '/"PersonaName"/{print $4; exit}' "$cfg/config/loginusers.vdf")" 6
  for v in $(ls "$cfg/userdata" 2>/dev/null | grep -E '^[0-9]{5,}$'); do add steam-account-id "$v"; done
done
add git-personal-login   "$(git config --global user.name)"
add git-personal-address "$(git config --global user.email)"
add git-personal-id      "$(git config --global user.email | grep -oE '^[0-9]{5,}')"
U="$(id -un)"
add home-path "/Users/$U/" 8
add home-path "/Users/$U\"" 8
add home-path "users\\$U\\" 8
# A computer name that is just the product ("Mac Studio", "MacBook Pro") identifies nobody and is all over the docs.
for n in LocalHostName ComputerName HostName; do
  v="$(scutil --get "$n" 2>/dev/null)"
  case "$v" in "Mac Studio"|"Mac mini"|"Mac Pro"|"MacBook"|"MacBook Air"|"MacBook Pro"|"iMac") ;; *) add mac-name "$v" ;; esac
done
if [ -f "$HOME/.ssh/config" ]; then
  for v in $(awk 'tolower($1)=="hostname"{print $2}' "$HOME/.ssh/config"); do add ssh-hostname "$v" 6; done
fi
sort -u "$K" -o "$K"

count() {   # <fixed|regex> <value> -> number of matching lines in content + names + message
  local flag=-F n=0 m
  [ "$1" = regex ] && flag=-E
  case "$MODE" in
    tracked) m=$(git -C "$REPO" grep -I -i -c $flag -e "$2" -- . 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
             n=$((n + m + $(git -C "$REPO" ls-files | grep -i -c $flag -e "$2"))) ;;
    cached)  m=$(git -C "$REPO" grep --cached -I -i -c $flag -e "$2" -- . 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
             n=$((n + m + $(git -C "$REPO" ls-files | grep -i -c $flag -e "$2"))) ;;
    dir)     m=$(grep -rIi -c $flag -e "$2" "$DIR" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
             n=$((n + m + $(cd "$DIR" && find . -type f | grep -i -c $flag -e "$2"))) ;;
  esac
  [ -n "$MSG" ] && n=$((n + $(grep -i -c $flag -e "$2" "$MSG")))
  echo "$n"
}

total=0
for class in $(cut -f1 "$K" | sort -u); do
  c=0
  while IFS=$'\t' read -r k v; do [ "$k" = "$class" ] && c=$((c + $(count fixed "$v"))); done < "$K"
  printf '%5d  %s\n' "$c" "$class"; total=$((total + c))
done
for pat in 'any-steam-id64:7656119[0-9]{10}' 'any-u1-id:\[U:1:[0-9]{5,}\]'; do
  c=$(count regex "${pat#*:}"); printf '%5d  %s (pattern)\n' "$c" "${pat%%:*}"; total=$((total + c))
done
echo "identifiers known on this Mac: $(wc -l < "$K" | tr -d ' ')   total hits: $total   accepted: ${ACCEPT:-0}"
[ "$total" = "${ACCEPT:-0}" ]
