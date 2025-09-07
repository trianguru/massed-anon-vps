#!/bin/bash
set -euo pipefail

# pacing
FAST="${FAST:-0}"
t_flight=${t_flight:-0.25}
t_capcom=${t_capcom:-0.18}
t_hold=${t_hold:-1.2}
t_hold_fast=${t_hold_fast:-0.6}

pause(){ sleep "${1:-$t_hold}"; }
cls(){ tput clear 2>/dev/null || printf '\033c'; }
saybox(){ echo -e "$1" | boxes -d parchment | lolcat; }

# Flight animated (twinkling)
flight_frames(){
cat <<'F1'
   ____   _       _     _      
  |  _ \ (_)     | |   | |     
  | |_) | _  __ _| |__ | |_    
  |  _ < | |/ _` | '_ \| __|   
  | |_) || | (_| | | | | |_    
  |____/ |_| \__, |_| |_\__|  
             __/ |             
            |___/              
F1
cat <<'F2'
   ____   _       _     _     * 
  |  _ \ (_)     | |   | |   *  
  | |_) | _  __ _| |__ | |_  *  
  |  _ < | |/ _` | '_ \| __|    
  | |_) || | (_| | | | | |_     
  |____/ |_| \__, |_| |_\__|   
             __/ |              
            |___/               
F2
cat <<'F3'
   ____   _       _     _        
  |  _ \ (_)     | |   | |    *  
  | |_) | _  __ _| |__ | |_   *  
  |  _ < | |/ _` | '_ \| __|  *  
  | |_) || | (_| | | | | |_      
  |____/ |_| \__, |_| |_\__|    
             __/ |               
            |___/                
F3
}

animate_flight(){
  local frames; frames="$(flight_frames)"
  cls
  awk -v d="$t_flight" '
    BEGIN{ RS=""; ORS=""; }
    {
      system("tput clear 2>/dev/null || printf \\\"\\033c\\\"");
      print | "lolcat";
      close("lolcat");
      system("sleep " d);
    }
  ' <<<"$frames"
}

animate_capcom_go(){
  local frames=( " CAPCOM: G O" " CAPCOM: GO " " CAPCOM: G O" " CAPCOM: GO " )
  for f in "${frames[@]}"; do
    cls
    echo "$f" | boxes -d boy | lolcat
    sleep "$t_capcom"
  done
}

capcom_no(){
  cls
  cat <<'NO' | lolcat
 _   _  ____        _____
| \ | |/ __ \ /\   / ____|
|  \| | |  | /  \ | |  __
| . ` | |  |/ /\ \| | |_ |
| |\  | |__| / ____ \ |__|
|_| \_|\____/_/    \_\____|

           NO-GO
NO
  saybox "$1"
}

slide_flight(){
  animate_flight
  saybox "$1"
  if [ "$FAST" = "1" ]; then
    pause "$t_hold_fast"
  else
    pause "$t_hold"
  fi
}

slide_capcom_ok(){
  animate_capcom_go
  saybox "$1"
  if [ "$FAST" = "1" ]; then
    pause "$t_hold_fast"
  else
    pause "$t_hold"
  fi
}

slide_capcom_no(){
  capcom_no "$1"
  if [ "$FAST" = "1" ]; then
    pause "$t_hold_fast"
  else
    pause "$t_hold"
  fi
}

probe(){
  local label="$1"; shift
  local cmd="$*"
  slide_flight "Flight: ${label}?"
  if bash -lc "$cmd" >/dev/null 2>&1; then
    slide_capcom_ok "CAPCOM: ${label} are GO, Flight!"
  else
    slide_capcom_no "CAPCOM: ${label} are NO-GO, Flight!"
    return 1
  fi
}

# Sequence
probe "Docker present"        "docker --version"
probe "Docker daemon"         "docker info"
probe "Kali image built"      "docker image inspect my-kali:latest"
probe "Kali tool: nmap"       "docker run --rm my-kali:latest bash -lc 'command -v nmap'"
probe "Tor SOCKS on :9050"    "ss -ltn 2>/dev/null | grep -q ':9050 ' || netstat -ltn | grep -q ':9050 '"
probe "proxychains4 present"  "command -v proxychains4"
probe "torsocks present"      "command -v torsocks"
probe "nftables rules loaded" "sudo nft list ruleset | grep -q 'table inet filter'"

# Direct egress must FAIL
slide_flight "Flight: Direct egress block test (should fail fast)?"
if timeout 4 bash -lc "curl -fsS https://example.com >/dev/null"; then
  slide_capcom_no "CAPCOM: Unexpected SUCCESS. Kill-switch review required."
else
  slide_capcom_ok "CAPCOM: Direct egress blocked. Kill-switch holding."
fi

# Tor-first + dynamic proxy should SUCCEED
slide_flight "Flight: Tor-first + proxy egress test?"
if timeout 14 pc curl -fsS https://icanhazip.com >/dev/null; then
  slide_capcom_ok "CAPCOM: Proxy egress confirmed. External IP via chain."
else
  slide_capcom_no "CAPCOM: Proxy egress failed. Check Tor and proxies."
fi

cls
echo "Preflight complete." | boxes -d dog | lolcat
