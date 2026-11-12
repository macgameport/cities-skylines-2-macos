# fetch.sh -- read with `.`, never run: fetch and sha, for common/make-wrapper.sh and
# surviving-mars-relaunched/tools/fetch-d3dmetal.sh (docs/plans/shared-installer.md, 2.1).
# The caller defines say, die and tilde first.
# L1_DOWNLOADS=<folder> names a folder of files already downloaded: a copy is used only if its size and
# sha256 match.
sha() { shasum -a 256 "$1" | awk '{ print $1 }'; }
fetch() {   # <url> <bytes> <sha256> <file>
  local url="$1" bytes="$2" want="$3" out="$4" name size got rc bar=-sS
  name="$(basename "$url")"
  if [ -n "${L1_DOWNLOADS:-}" ] && [ -f "$L1_DOWNLOADS/$name" ]; then
    cp "$L1_DOWNLOADS/$name" "$out"
    if [ "$(stat -f %z "$out")" = "$bytes" ] && [ "$(sha "$out")" = "$want" ]; then say "$name: the copy in $(tilde "$L1_DOWNLOADS")"; return 0; fi
    rm -f "$out"; say "$name in $(tilde "$L1_DOWNLOADS") is not the file this was tested with: downloading it instead"
  fi
  say "downloading $name ($((bytes / 1000000)) MB)"
  [ -t 1 ] && bar=-#
  curl --proto '=https' --tlsv1.2 -fL --retry 2 $bar -o "$out" "$url"; rc=$?
  if [ "$rc" = 22 ]; then die "$name is no longer published at $url. Please open an issue: https://github.com/macgameport/1launcher/issues"
  elif [ "$rc" != 0 ]; then die "the download of $name failed (curl exit $rc). Check the network, then try again."
  fi
  size="$(stat -f %z "$out")"; got="$(sha "$out")"
  if [ "$size" != "$bytes" ] || [ "$got" != "$want" ]; then
    rm -f "$out"
    die "$name is not the file this was tested with: $size bytes, sha256 $got, where $bytes bytes, sha256 $want was expected. Please open an issue: https://github.com/macgameport/1launcher/issues"
  fi
}
