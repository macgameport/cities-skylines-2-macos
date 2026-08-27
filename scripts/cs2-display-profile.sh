#!/bin/bash
# cs2-display-profile.sh — home (external) vs mobile (built-in) display profile for the CS2
# launcher. Contract + design: docs/plans/launcher-display-profiles.md. Repo original lives in
# scripts/; the launcher runs the deployed copy in ~/cs2-patch/.
#
# What it does, per boot, stateless: classify by the MAIN display (that is where Unity's
# displayIndex 0 opens the window) and assert the matching profile —
#   mobile (main = built-in):  Screenmanager "Use Native"=1 + DRS Constant 0.5 + CAS
#   home   (main = external):  Screenmanager "Use Native"=1 + DRS off
# It never writes the resolution tuple (measured unreliable from disk — GOTCHAS § Retina mode).
#
# Env: WINEPREFIX + WINE (exported by the launcher) · CS2_PROFILE=home|mobile|off (unset = auto)
#      DRY=1 = print classification + would-do actions, write nothing
# Test surface: CS2_SP_FIXTURE=<json file> replaces system_profiler output;
#      CS2_SETTINGS=<file> overrides the Settings.coc path (tests also set WINE=/usr/bin/true —
#      real wine pointed at a fake prefix would CREATE one).
# Fail-open: every path exits 0 with exactly one stdout line (DRY adds a would-do line);
#      a crash exits non-zero and the launcher hook's || catches it.
set -u
python3 - <<'PYEOF'
import glob, json, os, re, shutil, subprocess, sys

def out(line):
    print(line); sys.exit(0)

HATCH = 'set CS2_PROFILE=off to silence'
DRY  = os.environ.get('DRY') == '1'
prof = os.environ.get('CS2_PROFILE', '').strip().lower()
if prof == 'off':
    out('Display profile: skipped (CS2_PROFILE=off)')
if prof not in ('', 'home', 'mobile'):
    out(f'Display profile: skipped (unknown CS2_PROFILE={prof!r}; {HATCH})')

WP   = os.environ.get('WINEPREFIX', '')
WINE = os.environ.get('WINE', '')
acts = []

# Game-running guard (double-launch window): lsof-vs-prefix attribution, never bare pgrep alone.
try:
    pids = subprocess.run(['pgrep', '-f', '/Cities2\\.exe'],
                          capture_output=True, text=True, timeout=5).stdout.split()
    for p in pids:
        ls = subprocess.run(['lsof', '-p', p], capture_output=True, text=True, timeout=10).stdout
        if WP and WP in ls:
            out(f'Display profile: skipped (game running; {HATCH})')
except Exception:
    pass  # guard is best-effort; failure to check must not block a boot

# ---- classify ------------------------------------------------------------------------------
if prof in ('home', 'mobile'):
    mode, label = prof, f'forced (CS2_PROFILE={prof})'
else:
    try:
        fix = os.environ.get('CS2_SP_FIXTURE')
        if fix:
            raw = open(fix, encoding='utf-8').read()
        else:
            r = subprocess.run(['system_profiler', 'SPDisplaysDataType', '-json'],
                               capture_output=True, text=True, timeout=10)
            if r.returncode != 0:
                out(f'Display profile: skipped (system_profiler rc={r.returncode}; {HATCH})')
            raw = r.stdout
        entries = []
        for gpu in json.loads(raw).get('SPDisplaysDataType', []) or []:
            for nd in (gpu or {}).get('spdisplays_ndrvs', []) or []:
                if isinstance(nd, dict) and nd.get('spdisplays_online') == 'spdisplays_yes':
                    entries.append(nd)
        if not entries:
            out(f'Display profile: skipped (no online displays parsed; {HATCH})')
        internal = lambda nd: nd.get('spdisplays_connection_type') == 'spdisplays_internal'
        mains = [nd for nd in entries if nd.get('spdisplays_main') == 'spdisplays_yes']
        if mains:                                   # primary rule: the main display decides
            nd = mains[0]
            mode  = 'mobile' if internal(nd) else 'home'
            label = ('main display internal' if internal(nd)
                     else 'main display external ' + str(nd.get('_name', '?')))
        else:                                       # fallback: presence rule
            ext = [nd for nd in entries if not internal(nd)]
            if ext:
                mode, label = 'home', 'external present, no main flag: ' + str(ext[0].get('_name', '?'))
            elif any(internal(nd) for nd in entries):
                mode, label = 'mobile', 'internal only, no main flag'
            else:
                out(f'Display profile: skipped (unclassifiable displays; {HATCH})')
    except subprocess.TimeoutExpired:
        out(f'Display profile: skipped (system_profiler timeout; {HATCH})')
    except Exception as e:
        out(f'Display profile: skipped (detection {type(e).__name__}; {HATCH})')

# ---- apply 1/2: Screenmanager "Use Native"=1 (both profiles; self-heals the saved-res ratchet)
# Value name: discover from user.reg (guards a game-update rename; the "_h" suffix is a
# deterministic DJB2-XOR of the name — same on every install), fall back to the known literal.
# The " Default" sibling value must NOT match, hence the _h[0-9]+ anchor.
reg_name = 'Screenmanager Resolution Use Native_h1405027254'
reg_set  = False
try:
    ur = open(os.path.join(WP, 'user.reg'), encoding='utf-8', errors='replace').read() if WP else ''
    found = sorted(set(re.findall(r'"(Screenmanager Resolution Use Native_h[0-9]+)"', ur)))
    if len(found) == 1:
        reg_name = found[0]
    reg_set = bool(re.search(re.escape('"%s"' % reg_name) + r'=dword:00000001', ur))
except Exception:
    pass
if reg_set:
    acts.append('registry: Use Native already 1')
else:
    acts.append('registry: reg add "%s"=1' % reg_name)
    if not DRY:
        try:
            subprocess.run([WINE, 'reg', 'add',
                            r'HKCU\Software\Colossal Order\Cities Skylines II',
                            '/v', reg_name, '/t', 'REG_DWORD', '/d', '1', '/f'],
                           capture_output=True, timeout=30)
        except Exception as e:
            acts.append('WARN: reg add %s — continuing' % type(e).__name__)

# ---- apply 2/2: Settings.coc DRS block (the one Settings.coc surface proven editable from disk)
sc = os.environ.get('CS2_SETTINGS')
if not sc:
    # user dir discovered by glob + realpath dedupe — the non-Wineskin user dirs are symlinks
    cands = sorted(set(os.path.realpath(p) for p in glob.glob(os.path.join(
        WP, 'drive_c/users/*/AppData/LocalLow/Colossal Order/Cities Skylines II/Settings.coc'))))
    if len(cands) != 1:
        out(f'Display profile: {mode} — {label} (registry only; Settings.coc candidates={len(cands)}; {HATCH})')
    sc = cands[0]

A = r'(,\s*"isAdaptive")'   # bare "enabled" occurs 9x in the file — this adjacency anchor is load-bearing
if mode == 'mobile':
    edits = [(r'"enabled": (?:true|false)' + A, r'"enabled": true\1',  r'"enabled": true' + A),
             (r'"minScale": [0-9.]+',           '"minScale": 0.5',     r'"minScale": 0\.5'),
             (r'"upscaleFilter": "[A-Za-z]+"',  '"upscaleFilter": "ContrastAdaptiveSharpen"',
                                                r'"upscaleFilter": "ContrastAdaptiveSharpen"')]
    what = 'native swapchain + DRS 0.5 CAS'
else:
    edits = [(r'"enabled": (?:true|false)' + A, r'"enabled": false\1', r'"enabled": false' + A)]
    what = 'DRS off, native 1:1'

try:
    s = open(sc, encoding='utf-8').read()
    if all(len(re.findall(chk, s)) == 1 for _, _r, chk in edits):
        out(f'Display profile: {mode} — {label} ({what}; already set)')
    for pat, _r, _c in edits:
        n = len(re.findall(pat, s))
        if n != 1:
            out(f'Display profile: {mode} — {label} (registry ok; settings SKIPPED: pattern matched {n}, need 1; {HATCH})')
    acts.append('settings: %s -> %s' % (what, sc))
    if not DRY:
        for pat, rep, _c in edits:
            s = re.sub(pat, rep, s)
        shutil.copy2(sc, sc + '.pre-profile')          # rolling backup, only on real writes
        tmp = sc + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write(s)
        os.replace(tmp, sc)                            # atomic — no torn Settings.coc, ever
        post = open(sc, encoding='utf-8').read()
        if not all(len(re.findall(chk, post)) == 1 for _, _r, chk in edits):
            out(f'Display profile: {mode} — {label} (WARN: post-write verify failed — restore {sc}.pre-profile)')
except Exception as e:
    out(f'Display profile: {mode} — {label} (WARN: settings step {type(e).__name__} — continuing; {HATCH})')

if DRY:
    print('DRY: would do -> ' + '; '.join(acts))
    out(f'Display profile: {mode} — {label} ({what}; DRY, nothing written)')
out(f'Display profile: {mode} — {label} ({what})')
PYEOF
