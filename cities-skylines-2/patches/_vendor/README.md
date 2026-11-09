# Vendored Python libraries

Five of the patch scripts, `dis_pdx.py` and three tools in `../../scripts/` read .NET metadata with
`dnfile`, which needs `pefile`. Both are small, pure Python and MIT-licensed, so they ship here: setup
needs no network, no `pip` and no virtual environment, and any `python3` from 3.8 up can run the patches.

| Library | Version | Wheel this was unpacked from | sha256 of that wheel |
|---|---|---|---|
| [dnfile](https://github.com/malwarefrank/dnfile) | 0.18.0 | `dnfile-0.18.0-py3-none-any.whl` | `7579fe2d6bb1d854aa154929c309fbf34e70b622053a043a51d42f079fad1772` |
| [pefile](https://github.com/erocarrera/pefile) | 2024.8.26 | `pefile-2024.8.26-py3-none-any.whl` | `76f8b485dcd3b1bb8166f1128d395fa3d87af26360c2358fb75b80019b957c6f` |

What is here: `dnfile/`, and from the `pefile` wheel `pefile.py` and `ordlookup/`. The wheel's `peutils.py`
is left out: nothing here imports it. `LICENSE-dnfile` and `LICENSE-pefile` are the licence files from the
two wheels.

**These files are never edited here.** Every one is byte-identical to its member of the wheel, and
`MANIFEST.sha256` lists the sha256 of each. `../../scripts/test-vendor.sh` checks the folder against the
manifest. `.gitattributes` at the repository root marks this folder `-text`, so git stores every byte as it
came: one file, `ordlookup/wsock32.py`, has CRLF line endings.

The scripts that use it put this folder first on `sys.path` and set `sys.dont_write_bytecode`, so running
them leaves no `__pycache__` here.

## To update

1. `pip download --only-binary :all: --no-deps dnfile==<new> pefile==<new> -d <scratch>`, and check each
   wheel against the hash PyPI shows for it.
2. Replace `dnfile/`, `ordlookup/` and `pefile.py` with the wheels' contents, and the two licence files.
3. Regenerate the manifest from this folder:
   `find dnfile ordlookup pefile.py -type f | LC_ALL=C sort | xargs shasum -a 256 > MANIFEST.sha256`
4. Update the table above, run `../../scripts/test-vendor.sh`, and run the patches on copies of the game's
   files before anything is deployed.
