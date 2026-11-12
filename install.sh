#!/bin/bash
# install.sh -- the way in for a Mac with no checkout of this repository (docs/plans/simple-install.md, 2.4;
# docs/plans/shared-installer.md, 2.2). It fetches the repository into a temporary folder, finds the game's
# folder in common/games.tsv by the game's Steam app ID, hands over to that game's own installer
# (<folder>/scripts/install.sh), and removes the temporary folder again. Run from a checkout, it uses the
# checkout.
#
#   /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/macgameport/1launcher/release/install.sh)" 1launcher-install <Steam app ID>
#   bash install.sh <Steam app ID> [<ref>] [options for the game's installer ...]
#
# A game is named by its Steam app ID, the first field of its row in common/games.tsv, and never by its
# folder: what is published (the pasted line, the installer app) then holds nothing a renamed folder breaks.
# There is no default game: with no ID this says so and stops. The ref defaults to release, the branch that
# moves forward only on purpose. Everything from the first option on goes to the game's installer. With the
# pasted form, the words after the closing quote are a name for the script and then its arguments:
#   ... install.sh)" 1launcher-install 949230 release --check
#   exit: the game installer's own code; 1 = the fetch failed or what it brought is not this repository;
#   2 = no game named, a game with no installer, or a wrong ref or word.
# The whole script is functions, the last of them called on its last line, so a download cut short runs
# nothing.
game_folder() {   # <table> <id>: the folder in that ID's row, if the row is whole and the folder a plain name
  awk -F'\t' -v id="$2" '$1 == id && NF == 4 && $2 ~ /^[a-z0-9][a-z0-9-]*$/ { print $2; exit }' "$1" 2>/dev/null
}
games_with_installer() {   # <table> <root>: the ID and title of every row whose folder holds an installer
  local i f t g
  echo "The games that have an installer:"
  while IFS=$'\t' read -r i f t g; do
    case "$i" in ''|*[!0-9]*) continue ;; esac
    printf '%s' "$f" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || continue
    [ -f "$2/$f/scripts/install.sh" ] && echo "  $i  $t"
  done < "$1" 2>/dev/null
  return 0
}
main() {
  set -u
  local id="" ref=release words=0 self here="" table="" folder top url rc commit n e
  local front="https://github.com/macgameport/1launcher"
  local usage="usage: install.sh <Steam app ID> [<ref>] [options]"
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
           1) id="$1" ;;
           2) ref="$1" ;;
           *) echo "one word too many: $1 ($usage)"; return 2 ;;
         esac
         shift ;;
    esac
  done

  # A checkout: this file is a real file with the table of games beside it. Under bash -c (the pasted line,
  # the installer app) BASH_SOURCE is empty, so those always fetch, whatever folder Terminal is in.
  self="${BASH_SOURCE[0]:-}"
  if [ -n "$self" ] && [ -f "$self" ]; then
    here="$(cd "$(dirname "$self")" && pwd)"
    [ -f "$here/common/games.tsv" ] && table="$here/common/games.tsv"
  fi

  # No game named, or a word that is not an ID: nothing is fetched. A checkout has the table and lists its
  # games; the pasted line and the app have none yet, and name the page that lists them.
  case "$id" in
    ''|*[!0-9]*)
      if [ -n "$id" ]; then echo "not a Steam app ID: $id"; else echo "Say which game: the first word is its Steam app ID."; fi
      echo "$usage"
      if [ -n "$table" ]; then games_with_installer "$table" "$here"; else echo "The games and their IDs are listed at $front"; fi
      return 2 ;;
  esac
  case "$ref" in
    -*|/*|*..*|*//*) echo "not a branch, tag or commit of this repository: $ref"; return 2 ;;
  esac
  if ! printf '%s' "$ref" | grep -Eq '^[A-Za-z0-9._/-]+$'; then echo "not a branch, tag or commit of this repository: $ref"; return 2; fi

  if [ -n "$table" ]; then
    folder="$(game_folder "$table" "$id")"
    if [ -z "$folder" ] || [ ! -f "$here/$folder/scripts/install.sh" ]; then
      echo "This checkout has no installer for app $id."
      games_with_installer "$table" "$here"
      return 2
    fi
    echo "Using this checkout of 1launcher (nothing is fetched)."
    bash "$here/$folder/scripts/install.sh" "$@"
    return $?
  fi

  L1_TMP="$(mktemp -d "${TMPDIR:-/tmp}/1launcher-fetch.XXXXXX")" || { echo "A temporary folder could not be made."; return 1; }
  trap 'rm -rf "$L1_TMP"' EXIT
  local tmp="$L1_TMP"
  url="https://github.com/macgameport/1launcher/archive/$ref.tar.gz"
  echo "Fetching 1launcher ($ref) from github.com/macgameport/1launcher ..."
  curl --proto '=https' --tlsv1.2 -fsSL --retry 2 -o "$tmp/repo.tar.gz" "$url"; rc=$?
  if [ "$rc" = 22 ]; then
    echo "GitHub has no \"$ref\" of 1launcher. The current way in is at:"
    echo "  $front"
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
  folder="$(game_folder "$top/common/games.tsv" "$id")"
  if [ -z "$folder" ] || [ ! -f "$top/$folder/scripts/install.sh" ]; then
    echo "There is no installer for app $id."
    games_with_installer "$top/common/games.tsv" "$top"
    return 2
  fi
  if [ -n "$commit" ]; then echo "1launcher at commit ${commit#comment=}"; else echo "1launcher: commit not read"; fi
  export L1_FETCHED_REF="$ref"
  bash "$top/$folder/scripts/install.sh" "$@"
  return $?
}
main "$@"
