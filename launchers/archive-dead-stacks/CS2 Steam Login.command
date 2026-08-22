#!/bin/bash
# Native login for Steam-under-Wine when its window renders black.
# Prompts for credentials with real macOS dialogs and drives Steam's CEF login via CDP.
# Handles Steam Guard: EMAIL code OR mobile-app code (whatever the account uses).
export WINE="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin/wine"
export WINEPREFIX="$HOME/cs2-mac/prefix"
CDP="$HOME/cs2-mac/cdpenv/bin/python $HOME/cs2-mac/cdp.py"
STEAM="$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"

ask() { osascript -e "text returned of (display dialog \"$1\" default answer \"\" buttons {\"OK\"} default button 1 with title \"Steam Login\")" 2>/dev/null; }
askpw() { osascript -e "text returned of (display dialog \"$1\" default answer \"\" with hidden answer buttons {\"OK\"} default button 1 with title \"Steam Login\")" 2>/dev/null; }
say() { osascript -e "display notification \"$1\" with title \"Steam Login\"" 2>/dev/null; echo "$1"; }

# 1) Ensure Steam is running with the debug port + a login page (relaunch if already logged in)
touch "$WINEPREFIX/drive_c/Program Files (x86)/Steam/.cef-enable-remote-debugging"
if ! curl -s --max-time 2 http://localhost:8080/json >/dev/null 2>&1; then
  echo "Starting Steam with debug channel..."
  export PATH="$HOME/cs2-mac/Wine Staging.app/Contents/Resources/wine/bin:$PATH"
  nohup "$WINE" "$STEAM" -no-cef-sandbox -cef-enable-debugging >/dev/null 2>&1 &
  for i in $(seq 1 25); do curl -s --max-time 2 http://localhost:8080/json | grep -qi "sign in to steam" && break; sleep 3; done
fi

# 2) Credentials via native dialogs
U=$(ask "Steam account name:"); [ -z "$U" ] && exit 0
P=$(askpw "Steam password:");   [ -z "$P" ] && exit 0

# 3) Fill + submit via the debug channel (React-safe setter)
fill() { $CDP eval "(()=>{const el=document.querySelectorAll('input')[$1];const s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;el.focus();s.call(el,$2);el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return el.value.length;})()"; }
fill 0 "\"$U\""; fill 1 "\"$P\""
$CDP eval "(()=>{const b=[...document.querySelectorAll('button')].find(x=>/sign in/i.test(x.innerText));if(b)b.click();return !!b;})()" >/dev/null

# 4) Steam Guard — wait for the code screen, click "Enter a code instead" if it's showing app-confirm
sleep 4
$CDP eval "(()=>{const a=[...document.querySelectorAll('a,button')].find(x=>/enter a code instead/i.test(x.innerText));if(a){a.click();return 'switched to code';}return 'no switch';})()" >/dev/null
sleep 2
# Is a code field present now?
NEED=$($CDP eval "[...document.querySelectorAll('input')].filter(i=>i.offsetParent&&i.maxLength<=5&&i.type!=='password').length" 2>/dev/null)
if [ "${NEED:-0}" != "0" ]; then
  C=$(ask "Enter your Steam Guard code (from your EMAIL, or the mobile app if you use it):")
  if [ -n "$C" ]; then
    # fill either a single code input or a segmented 5-box input
    $CDP eval "(()=>{const code='$C'.replace(/\s/g,'');const boxes=[...document.querySelectorAll('input')].filter(i=>i.offsetParent&&i.maxLength<=5&&i.type!=='password');const s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;if(boxes.length>=code.length){boxes.forEach((b,i)=>{b.focus();s.call(b,code[i]||'');b.dispatchEvent(new Event('input',{bubbles:true}));});}else{const b=boxes[0];b.focus();s.call(b,code);b.dispatchEvent(new Event('input',{bubbles:true}));}return 'code entered';})()" >/dev/null
  fi
fi

# 5) Confirm
for i in $(seq 1 20); do
  ID=$(tail -3 "$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt" 2>/dev/null | grep -oE "\[U:1:[1-9][0-9]+\]" | tail -1)
  [ -n "$ID" ] && break; sleep 2
done
if [ -n "$ID" ]; then say "Logged in ✓ ($ID). You can close this and launch the game."; else say "Not logged in yet — if you use the mobile app, approve the push, or re-run and enter the code."; fi
echo "Done. Press any key to close."; read -n1
