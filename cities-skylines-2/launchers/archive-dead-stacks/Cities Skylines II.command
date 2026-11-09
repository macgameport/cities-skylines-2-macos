#!/bin/bash
# ONE launcher: Steam (auto-login, or prompt if token expired) → license sync → Cities: Skylines II.
# Free stack: Wine 11 + DXVK. Low graphics preset pre-set. Virtual-desktop mode for mouse input.
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
export WINEESYNC=1 ROSETTA_ADVERTISE_AVX=1 WINEDEBUG=-all
export MVK_CONFIG_RESUME_LOST_DEVICE=1 MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1 MVK_CONFIG_LOG_LEVEL=0
export SteamAppId=949230 SteamGameId=949230 SteamOverlayGameId=949230
export WINEDLLOVERRIDES="gameoverlayrenderer64=d;gameoverlayrenderer=d;winemenubuilder.exe=d"
export DXVK_CONFIG_FILE="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II/dxvk.conf"
STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
GDIR="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Cities Skylines II"
CL="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
CDP="$HOME/cs2-mac/cdpenv/bin/python $HOME/cs2-mac/cdp.py"
echo "949230" > "$GDIR/steam_appid.txt"
touch "$WINEPREFIX/drive_c/Program Files (x86)/Steam/.cef-enable-remote-debugging"

logged_in() { grep -qE "\[U:1:[1-9][0-9]+\]" <(tail -3 "$CL" 2>/dev/null); }

# 1) Start Steam if needed (with debug channel, in case we must prompt for login)
if ! pgrep -f "cs2-mac/prefix.*steam.exe" >/dev/null 2>&1; then
  echo "Starting Steam..."; nohup "$WINE" "$STEAM" -no-cef-sandbox -cef-enable-debugging >/dev/null 2>&1 &
fi

# 2) Wait for auto-login
echo "Signing in to Steam..."
for i in $(seq 1 20); do logged_in && break; sleep 3; done

# 3) Fallback: if still not logged in, prompt (token expired / logged out)
if ! logged_in; then
  echo "Auto-login didn't take — prompting for credentials..."
  ask() { osascript -e "text returned of (display dialog \"$1\" default answer \"\" buttons {\"OK\"} default button 1 with title \"Steam Login\")" 2>/dev/null; }
  askpw() { osascript -e "text returned of (display dialog \"$1\" default answer \"\" with hidden answer buttons {\"OK\"} default button 1 with title \"Steam Login\")" 2>/dev/null; }
  fill() { $CDP eval "(()=>{const el=document.querySelectorAll('input')[$1];const s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;el.focus();s.call(el,$2);el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));})()" >/dev/null 2>&1; }
  for i in $(seq 1 20); do curl -s --max-time 2 http://localhost:8080/json | grep -qi "sign in to steam" && break; sleep 2; done
  U=$(ask "Steam account name:"); P=$(askpw "Steam password:")
  if [ -n "$U" ] && [ -n "$P" ]; then
    fill 0 "\"$U\""; fill 1 "\"$P\""
    $CDP eval "(()=>{const b=[...document.querySelectorAll('button')].find(x=>/sign in/i.test(x.innerText));if(b)b.click();})()" >/dev/null 2>&1
    sleep 4
    $CDP eval "(()=>{const a=[...document.querySelectorAll('a,button')].find(x=>/enter a code instead/i.test(x.innerText));if(a)a.click();})()" >/dev/null 2>&1
    sleep 2
    if [ "$($CDP eval "[...document.querySelectorAll('input')].filter(i=>i.offsetParent&&i.maxLength<=5&&i.type!=='password').length" 2>/dev/null)" != "0" ]; then
      C=$(ask "Steam Guard code (email or app):")
      [ -n "$C" ] && $CDP eval "(()=>{const code='$C'.replace(/\s/g,'');const b=[...document.querySelectorAll('input')].filter(i=>i.offsetParent&&i.maxLength<=5&&i.type!=='password');const s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;if(b.length>=code.length){b.forEach((x,i)=>{x.focus();s.call(x,code[i]||'');x.dispatchEvent(new Event('input',{bubbles:true}));});}else{b[0].focus();s.call(b[0],code);b[0].dispatchEvent(new Event('input',{bubbles:true}));}})()" >/dev/null 2>&1
    fi
    for i in $(seq 1 20); do logged_in && break; sleep 2; done
  fi
fi

if ! logged_in; then echo "Still not logged in. If you use the mobile app, approve the push, then re-run."; echo "Press any key."; read -n1; exit 1; fi

# 4) License sync, then launch the game (direct exe, virtual desktop for input)
echo "Logged in. Waiting 40s for Steam license sync (required)..."; sleep 40
echo "Launching Cities: Skylines II..."
rm -f "$WINEPREFIX/drive_c/users/$WINEUSER/AppData/LocalLow/Colossal Order/Cities Skylines II/Player.log"
"$WINE" explorer /desktop=CS2,1512x982 "$GDIR/Cities2.exe"
