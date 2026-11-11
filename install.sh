#!/bin/bash
# install.sh -- the way in for a Mac with no checkout of this repository (docs/plans/simple-install.md, 2.4).
# It fetches the repository into a temporary folder, hands over to a game's own installer
# (<game>/scripts/install.sh), and removes the folder again. Run from a checkout, it uses the checkout.
#
#   /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/macgameport/1launcher/release/install.sh)"
#   bash install.sh [<game folder> [<ref>]] [options for the game's installer ...]
#
# The game defaults to cities-skylines-2 and the ref to release, the branch that moves forward only on
# purpose. Everything from the first option on goes to the game's installer. With the pasted form, the
# words after the closing quote are a name for the script and then its arguments:
#   ... install.sh)" 1launcher-install cities-skylines-2 release --check
#   exit: the game installer's own code; 1 = the fetch failed or what it brought is not this repository;
#   2 = a wrong game, ref or word.
# The whole script is one function called on its last line, so a download cut short runs nothing.
main() {
  set -u
  local game=cities-skylines-2 ref=release words=0 self here top url rc commit n e
  L1_TMP=""   # not local: the EXIT trap runs after this function has returned

  if [ "$(id -u)" = 0 ]; then
    echo "Do not run the installer as root (with sudo): it would leave files only root can change in your home folder."
    return 1
  fi
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) break ;;
      *) words=$((words + 1))
         case "$words" in
           1) game="$1" ;;
           2) ref="$1" ;;
           *) echo "one word too many: $1 (usage: install.sh [<game folder> [<ref>]] [options])"; return 2 ;;
         esac
         shift ;;
    esac
  done
  if ! printf '%s' "$game" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then echo "not a game folder: $game"; return 2; fi
  case "$ref" in
    -*|/*|*..*|*//*) echo "not a branch, tag or commit of this repository: $ref"; return 2 ;;
  esac
  if ! printf '%s' "$ref" | grep -Eq '^[A-Za-z0-9._/-]+$'; then echo "not a branch, tag or commit of this repository: $ref"; return 2; fi

  # A checkout: this file is a real file with the game's installer beside it. Under bash -c (the pasted line,
  # the installer app) BASH_SOURCE is empty, so those always fetch, whatever folder Terminal is in.
  self="${BASH_SOURCE[0]:-}"
  if [ -n "$self" ] && [ -f "$self" ]; then
    here="$(cd "$(dirname "$self")" && pwd)"
    if [ -f "$here/$game/scripts/install.sh" ]; then
      echo "Using this checkout of 1launcher (nothing is fetched)."
      bash "$here/$game/scripts/install.sh" "$@"
      return $?
    fi
  fi

  L1_TMP="$(mktemp -d "${TMPDIR:-/tmp}/1launcher-fetch.XXXXXX")" || { echo "A temporary folder could not be made."; return 1; }
  trap 'rm -rf "$L1_TMP"' EXIT
  local tmp="$L1_TMP"
  url="https://github.com/macgameport/1launcher/archive/$ref.tar.gz"
  echo "Fetching 1launcher ($ref) from github.com/macgameport/1launcher ..."
  curl --proto '=https' --tlsv1.2 -fsSL --retry 2 -o "$tmp/repo.tar.gz" "$url"; rc=$?
  if [ "$rc" = 22 ]; then
    echo "GitHub has no \"$ref\" of 1launcher. The guide has the current way in:"
    echo "  https://github.com/macgameport/1launcher/blob/main/$game/INSTALL.md"
    return 1
  elif [ "$rc" != 0 ]; then
    echo "GitHub could not be reached (curl exit $rc). Check the network, then try again."
    return 1
  fi
  commit="$(gzip -dc "$tmp/repo.tar.gz" 2>/dev/null | head -c 1024 | LC_ALL=C grep -a -o 'comment=[0-9a-f]\{40\}' | head -n 1)"
  mkdir "$tmp/x"
  if ! tar -xzf "$tmp/repo.tar.gz" -C "$tmp/x" 2>/dev/null; then echo "What GitHub sent could not be unpacked."; return 1; fi
  n=0; top=""
  for e in "$tmp/x"/* "$tmp/x"/.[!.]*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    n=$((n + 1)); top="$e"
  done
  if [ "$n" != 1 ] || [ -L "$top" ] || [ ! -d "$top" ]; then echo "What GitHub sent is not one folder of this repository."; return 1; fi
  if [ ! -f "$top/$game/scripts/install.sh" ]; then
    echo "There is no installer for \"$game\". The games that have one:"
    for e in "$top"/*/scripts/install.sh; do [ -f "$e" ] && echo "  $(basename "$(dirname "$(dirname "$e")")")"; done
    return 1
  fi
  if [ -n "$commit" ]; then echo "1launcher at commit ${commit#comment=}"; else echo "1launcher: commit not read"; fi
  export L1_FETCHED_REF="$ref"
  bash "$top/$game/scripts/install.sh" "$@"
  return $?
}
main "$@"
