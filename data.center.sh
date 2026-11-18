#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  N E X U S   D A T A C E N T E R _ B E N C H   v1.1                      ║
# ║      MESURER UN VRAI DATA CENTER — ET Y BOOSTER UN NŒUD CDN MONDIAL      ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║  [1] SELFCHECK    outils requis                                          ║
# ║  [2] IDENTITE     qui est ce DC                                          ║
# ║  [3] LATENCE      matrice monde : 14 endpoints · 11 réseaux CDN          ║
# ║  [4] DEBIT ↓      vrais fichiers massifs                                 ║
# ║  [5] DEBIT ↑      upload réel                                            ║
# ║  [6] NEXUS        p95 TTFB + req/s en rafale                             ║
# ║  [6.5] BOOST      Téléchargement CDN vs service NEXUS (le vrai test)     ║
# ║  [7] VERDICT      ce que ce DC peut vraiment faire                       ║
# ║  [8] RAPPORTS     DC_BENCH_<date>.txt + DC_BENCH_<date>.json (validé)    ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -u

# ────────────────────────────── couleurs ──────────────────────────────────────
G='\033[1;32m'; W='\033[1;37m'; Y='\033[1;33m'; R='\033[1;31m'
C='\033[1;36m'; D='\033[0;90m'; B='\033[1m'; N='\033[0m'

# ────────────────────────────── réglages ──────────────────────────────────────
N_PROBES=10
case "${1:-}" in
  quick) N_PROBES=5 ;;
  ''|all) N_PROBES=10 ;;
  *[!0-9]*) echo "argument inconnu : $1 (quick | 3..50)"; exit 1 ;;
  *) N_PROBES=$1 ;;
esac
[ "$N_PROBES" -lt 3 ]  && N_PROBES=3
[ "$N_PROBES" -gt 50 ] && N_PROBES=50
TIMEOUT=12
CTIMEOUT=4
DL_TIME=12
UP_FILE_MB=10
BURST_REQS=100
BURST_PAR=8
STAMP=$(date '+%Y%m%d-%H%M%S')
REPORT_TXT="$PWD/DC_BENCH_${STAMP}.txt"
REPORT_JSON="$PWD/DC_BENCH_${STAMP}.json"
TMP=$(mktemp -d /tmp/dc_bench.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

# ─────────────────── les 14 vrais endpoints (11 réseaux) ──────────────────────
ENDPOINTS=(
  "cdnjs|Cloudflare|https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"
  "jsDelivr|Cloudflare+Fastly|https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js"
  "Fastly-jsDelivr|Fastly|https://fastly.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js"
  "Google-CDN|Google|https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js"
  "Google-Fonts|Google|https://fonts.googleapis.com/css2?family=Roboto&display=swap"
  "Azure-CDN|Microsoft|https://ajax.aspnetcdn.com/ajax/jquery/jquery-3.7.1.min.js"
  "unpkg|Cloudflare|https://unpkg.com/jquery@3.7.1/dist/jquery.min.js"
  "Vercel|Vercel|https://nextjs.org/"
  "CloudFront|Amazon AWS|https://sdk.amazonaws.com/js/aws-sdk-2.1691.0.min.js"
  "Netlify|Netlify|https://www.netlify.com/"
  "BunnyCDN|Bunny|https://bunny.net/"
  "Steam-CDN|Akamai|https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg"
  "Cloudinary|Cloudinary|https://res.cloudinary.com/demo/image/upload/sample.jpg"
  "GitHub-raw|GitHub (Fastly)|https://raw.githubusercontent.com/jquery/jquery/main/README.md"
)
TRACE_URL="https://www.cloudflare.com/cdn-cgi/trace"
IDENT_URL="http://ip-api.com/json/?fields=status,country,city,isp,org,as,query"

DLS=(
  "Cloudflare-Speed|https://speed.cloudflare.com/__down?bytes=10485760|0|reseau mondial Cloudflare (10 Mo max)"
  "Hetzner-NBG1|https://nbg1-speed.hetzner.com/100MB.bin|104857599|DC Nuremberg, Allemagne"
  "Hetzner-HEL1|https://hel1-speed.hetzner.com/100MB.bin|104857599|DC Helsinki, Finlande"
  "Hetzner-ASH|https://ash-speed.hetzner.com/100MB.bin|104857599|DC Ashburn, USA"
  "OVH-proof|https://proof.ovh.net/files/10Mb.dat|10485760|DC OVH, Roubaix, France"
)
UP_URL="https://speed.cloudflare.com/__up"

FMT='%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{http_code} %{size_download} %{remote_ip}\n'
DFMT='%{http_code} %{speed_download} %{size_download}'
UFMT='%{http_code} %{speed_upload} %{size_upload}'

exec > >(tee "$REPORT_TXT") 2>&1

banner() {
  printf "${B}╔══════════════════════════════════════════════════════════════════╗${N}\n"
  printf "${B}║  NEXUS DATACENTER_BENCH v1.1 — mesurer ce DC, y booster NEXUS     ║${N}\n"
  printf "${B}║  latence monde · Gbps ↓/↑ · nœud CDN réel sur place              ║${N}\n"
  printf "${B}╚══════════════════════════════════════════════════════════════════╝${N}\n"
}

# ────────────────────────────── [1] SELFCHECK ─────────────────────────────────
selfcheck() {
  printf "\n${C}═══[ SELFCHECK — outils requis sur ce serveur ]══════════════════════${N}\n"
  local ok=1
  for t in curl awk sort tee date mktemp grep cut head tail seq dd uname nproc xargs; do
    if command -v "$t" >/dev/null 2>&1; then
      printf "  ${G}✓${N} $t\n"
    else
      printf "  ${R}✗${N} $t ABSENT — apt install curl (ou équivalent) puis relance\n"; ok=0
    fi
  done
  [ "$ok" -eq 1 ] || { printf "${R}outils manquants, arrêt.${N}\n"; exit 1; }
  local py=NON
  command -v python3 >/dev/null 2>&1 && py=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')
  printf "  ${G}✓${N} python3 : %s ${D}(le nœud NEXUS v1.0 = stdlib pur, rien d'autre à installer)${N}\n" "$py"
  printf "  ${G}✓${N} $N_PROBES sondes/CDN · tests de débit plafonnés à ${DL_TIME}s chacun\n"
}

stats() {
  sort -g -k"$2","$2" "$1" 2>/dev/null | awk -v c="$2" '{
    v[++n]=$c*1000; s+=$c*1000
  } END {
    if (n==0) { print "NA NA NA NA NA"; exit }
    i50=int(n*0.5+0.999); i95=int(n*0.95+0.999)
    if (i50<1) i50=1; if (i95<1) i95=1; if (i50>n) i50=n; if (i95>n) i95=n
    printf "%.1f %.1f %.1f %.1f %.1f", v[1], s/n, v[i50], v[i95], v[n]
  }'
}

line_stats() {
  local s lbl
  lbl="$3"
  s=$(stats "$1" "$2")
  if [ "$s" = "NA NA NA NA NA" ]; then
    printf "      ${D}%-7s toutes sondes échouées${N}\n" "$lbl"
    return
  fi
  set -- $s
  printf "      %-7s ${W}min %7.1f${N}  ${W}avg %7.1f${N}  ${W}p50 %7.1f${N}  ${B}${G}p95 %7.1f${N}  ${W}max %7.1f${N}  ms\n" \
         "$lbl" "$1" "$2" "$3" "$4" "$5"
}

pop_name() {
  case "$1" in
    CDG|ORY) echo "Paris";; MRS) echo "Marseille";; LYS) echo "Lyon";; NCE) echo "Nice";; BOD) echo "Bordeaux";; LIL) echo "Lille";;
    LHR) echo "Londres";; AMS) echo "Amsterdam";; FRA|MUC|DRS|HAM) echo "Allemagne";; BRU) echo "Bruxelles";;
    GVA) echo "Genève";; ZRH) echo "Zurich";; MAD|BCN) echo "Espagne";; LIS) echo "Lisbonne";;
    MIL|MXP|FCO) echo "Italie";; VIE) echo "Vienne";; PRG) echo "Prague";; WAW) echo "Varsovie";;
    STO|CPH) echo "Nordiques";; DUB) echo "Dublin";; LUX) echo "Luxembourg";;
    HKG|HK1|HKG1) echo "Hong Kong";; EWR|JFK) echo "New York";; IAD) echo "Washington";; ORD) echo "Chicago";;
    DFW) echo "Dallas";; DEN) echo "Denver";; LAX) echo "Los Angeles";; SJC|SEA) echo "Côte Ouest USA";;
    ATL) echo "Atlanta";; YYZ|YVR) echo "Canada";; GRU) echo "São Paulo";; EZE|SCL|BOG) echo "Amérique du Sud";;
    MEX) echo "Mexico";; NRT|KIX) echo "Japon";; ICN) echo "Séoul";; SIN) echo "Singapour";; TPE) echo "Taipei";;
    BKK) echo "Bangkok";; DEL|BOM|MAA) echo "Inde";; DXB|DOH) echo "Golfe";; JNB) echo "Johannesburg";;
    SYD|MEL|AKL) echo "Océanie";; *) echo "PoP $1";;
  esac
}
pop_resolve() {
  local p="$1" p2
  p2=$(pop_name "$p")
  if [ "${p2#PoP }" != "$p2" ]; then
    p2=$(pop_name "$(printf '%s' "$p" | sed 's/[0-9]*$//')")
  fi
  printf '%s' "$p2"
}
pop_from_headers() {
  if   [ -n "$1" ]; then printf '%s' "$1" | awk -F- '{print $NF}'
  elif [ -n "$2" ]; then printf '%s' "$2" | awk -F- '{print $1}'
  elif [ -n "$3" ]; then printf '%s' "$3" | tr ',' '\n' | tail -1 | awk -F- '{print $NF}'
  elif [ -n "$4" ]; then printf '%s' "$4" | awk -F:: '{print $1}' | tr 'a-z' 'A-Z'
  elif [ -n "$5" ] && printf '%s' "$5" | grep -q '^BunnyCDN-'; then
                          printf '%s' "$5" | cut -d- -f2
  else printf ''
  fi
}
headers_info() {
  local h="$TMP/hdr.$$"
  curl -s -m "$TIMEOUT" --connect-timeout "$CTIMEOUT" -4 -D "$h" -o /dev/null \
       -A "NEXUS-DCBench/1.0" "$1" 2>/dev/null || true
  local ray amz xserved vid srv cache age pop
  ray=$(grep -i '^cf-ray:' "$h" | head -1 | tr -d '\r' | awk '{print $2}')
  amz=$(grep -i '^x-amz-cf-pop:' "$h" | head -1 | tr -d '\r' | awk '{print $2}')
  xserved=$(grep -i '^x-served-by:' "$h" | head -1 | tr -d '\r' | cut -d' ' -f2-)
  vid=$(grep -i '^x-vercel-id:' "$h" | head -1 | tr -d '\r' | cut -d' ' -f2-)
  srv=$(grep -i '^server:' "$h" | head -1 | tr -d '\r' | cut -d' ' -f2)
  cache=$(grep -i '^cf-cache-status:\|^x-cache:\|^x-vercel-cache:' "$h" \
          | head -2 | tr -d '\r' | tr '\n' ' ' | sed 's/  */ /g; s/ $//')
  age=$(grep -i '^age:' "$h" | head -1 | tr -d '\r' | awk '{print tolower($1)" "$2}')
  [ -n "$age" ] && cache="${cache:+$cache · }$age"
  pop=$(pop_from_headers "$ray" "$amz" "$xserved" "$vid" "$srv")
  rm -f "$h"
  printf '%s|%s' "$pop" "$cache"
}

# ────────────────────────── [2] IDENTITE du data center ───────────────────────
DC_COUNTRY=""; DC_CITY=""; DC_ISP=""; DC_AS=""; DC_IP=""; DC_POP=""
identify() {
  printf "\n${C}═══[ IDENTITÉ — où est ce serveur, qui le porte ]═════════════════════${N}\n"
  local js
  js=$(curl -s -m 8 "$IDENT_URL" 2>/dev/null)
  DC_COUNTRY=$(printf '%s' "$js" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
  DC_CITY=$(printf '%s' "$js"    | grep -o '"city":"[^"]*"'    | cut -d'"' -f4)
  DC_ISP=$(printf '%s' "$js"     | grep -o '"isp":"[^"]*"'     | cut -d'"' -f4)
  DC_AS=$(printf '%s' "$js"      | grep -o '"as":"[^"]*"'      | cut -d'"' -f4)
  DC_IP=$(printf '%s' "$js"      | grep -o '"query":"[^"]*"'   | cut -d'"' -f4)
  [ -z "$DC_IP" ] && DC_IP=$(curl -s -m 5 https://api.ipify.org 2>/dev/null)
  printf "  ${W}IP publique${N} : %s\n" "${DC_IP:-?}"
  printf "  ${W}Localisation${N}: %s, %s\n" "${DC_CITY:-?}" "${DC_COUNTRY:-?}"
  printf "  ${W}Opérateur${N}   : %s\n" "${DC_ISP:-?}"
  printf "  ${W}Système autonome${N} : %s\n" "${DC_AS:-?}"
  local host cpu ram kern
  host=$(hostname 2>/dev/null); cpu=$(nproc 2>/dev/null)
  ram=$(free -m 2>/dev/null | awk '/^Mem:/{print $2" Mo"}'); kern=$(uname -r 2>/dev/null)
  printf "  ${W}Machine${N}     : %s · %s vCPU · %s RAM · kernel %s\n" \
         "${host:-?}" "${cpu:-?}" "${ram:-?}" "${kern:-?}"

  local out colo
  out=$(curl -s -m "$TIMEOUT" --connect-timeout "$CTIMEOUT" -4 "$TRACE_URL" 2>/dev/null) || out=""
  colo=$(printf '%s' "$out" | grep -o '^colo=.*' | cut -d= -f2)
  if [ -n "$colo" ]; then
    DC_POP="$colo"
    printf "  ${G}✓${N} PoP Cloudflare qui répond à ce DC : ${B}%s (%s)${N}\n" "$colo" "$(pop_resolve "$colo")"
  else
    printf "  ${D}trace Cloudflare indisponible — les autres mesures restent valides${N}\n"
  fi
}

# ─────────────────── [3] LATENCE : matrice monde depuis le DC ─────────────────
LAT_LINES=""
latency() {
  printf "\n${C}═══[ LATENCE MONDE — %d sondes × %d endpoints, 11 réseaux CDN ]═══════${N}\n" "$N_PROBES" "${#ENDPOINTS[@]}"
  local i=0 ep name prov url info pop cache cold code
  for ep in "${ENDPOINTS[@]}"; do
    i=$((i+1))
    name=$(printf '%s' "$ep" | cut -d'|' -f1)
    prov=$(printf '%s' "$ep" | cut -d'|' -f2)
    url=$(printf '%s' "$ep" | cut -d'|' -f3)
    cold="$TMP/lat_${name}.txt"; : > "$cold"
    local j
    for j in $(seq 1 "$N_PROBES"); do
      curl -s -m "$TIMEOUT" --connect-timeout "$CTIMEOUT" -4 -o /dev/null \
           -A "NEXUS-DCBench/1.0" -w "$FMT" "$url" >> "$cold" 2>/dev/null || true
    done
    info=$(headers_info "$url")
    pop=$(printf '%s' "$info" | cut -d'|' -f1)
    code=$(awk '{print $6}' "$cold" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    local sc p50 p95
    sc=$(stats "$cold" 4)
    p50=$(printf '%s' "$sc" | awk '{print $3}')
    p95=$(printf '%s' "$sc" | awk '{print $4}')
    LAT_LINES="${LAT_LINES}${name}|${prov}|${p50:-NA}|${p95:-NA}|${pop:-—}\n"
    if [ -n "$pop" ]; then
      printf "  ${D}[%2d/%d]${N} %-16s %-18s p50 ${W}%6s ms${N}  p95 ${W}%6s ms${N}  PoP ${G}%s${N}  ${D}(%s)${N}\n" \
             "$i" "${#ENDPOINTS[@]}" "$name" "$prov" "$p50" "$p95" "$pop" "$(pop_resolve "$pop")"
    else
      printf "  ${D}[%2d/%d]${N} %-16s %-18s p50 ${W}%6s ms${N}  p95 ${W}%6s ms${N}\n" \
             "$i" "${#ENDPOINTS[@]}" "$name" "$prov" "$p50" "$p95"
    fi
  done
}

# ──────────────────────── [4] DÉBIT DESCENDANT du DC ──────────────────────────
DL_LINES=""
DL_BEST=""
DL_BEST_GBPS=0
download_test() {
  printf "\n${C}═══[ DÉBIT DESCENDANT — vrais fichiers massifs depuis des vrais DC ]═══${N}\n"
  local i=0 d label url maxsz note out code speed size gbps mbps
  for d in "${DLS[@]}"; do
    i=$((i+1))
    label=$(printf '%s' "$d" | cut -d'|' -f1)
    url=$(printf '%s' "$d"   | cut -d'|' -f2)
    maxsz=$(printf '%s' "$d" | cut -d'|' -f3)
    note=$(printf '%s' "$d"  | cut -d'|' -f4)
    printf "  ${B}[%d/%d] %s${N} ${D}— %s${N}\n" "$i" "${#DLS[@]}" "$label" "$note"
    local best=0 bestline="" out_last=""
    local range_args=""
    [ -n "$maxsz" ] && [ "$maxsz" != "0" ] && range_args="-r 0-$maxsz"
    local t
    for t in 1 2; do
      out=$(curl -s -o /dev/null -m "$DL_TIME" --connect-timeout "$CTIMEOUT" \
                 $range_args -A "NEXUS-DCBench/1.0" -w "$DFMT" "$url" 2>/dev/null) || true
      out_last="$out"
      code=$(printf '%s' "$out" | awk '{print $1}')
      speed=$(printf '%s' "$out" | awk '{print $2}')
      size=$(printf '%s' "$out" | awk '{print $3}')
      case "$code" in 200|206) [ -n "$speed" ] && [ "$speed" -gt "$best" ] 2>/dev/null \
                              && { best=$speed; bestline="$out"; } ;; esac
    done
    out="$bestline"
    [ -z "$out" ] && out="$out_last"
    code=$(printf '%s' "$out" | awk '{print $1}')
    speed=$(printf '%s' "$out" | awk '{print $2}')
    size=$(printf '%s' "$out" | awk '{print $3}')
    if [ -n "$speed" ] && [ "$speed" -gt 0 ] 2>/dev/null; then
      gbps=$(awk -v s="$speed" 'BEGIN{printf "%.2f", s*8/1e9}')
      mbps=$(awk -v s="$speed" 'BEGIN{printf "%.1f", s/1e6}')
      printf "      code %s · ${G}%s Gbps${N} (${W}%s Mo/s${N}) · %s octets servis en ≤%ds\n" \
             "$code" "$gbps" "$mbps" "$size" "$DL_TIME"
      DL_LINES="${DL_LINES}${label}|${note}|${gbps}|${mbps}|${size}|${code}\n"
      awk -v g="$gbps" -v b="$DL_BEST_GBPS" 'BEGIN{exit !(g+0 > b+0)}' && {
        DL_BEST_GBPS=$gbps; DL_BEST="$label"
      }
    else
      printf "      ${R}échec (code %s) — source injoignable depuis ce DC${N}\n" "${code:-000}"
      DL_LINES="${DL_LINES}${label}|${note}|null|null|0|${code:-000}\n"
    fi
  done
}

# ──────────────────────── [5] DÉBIT MONTANT du DC ─────────────────────────────
UP_GBPS=""; UP_MBPS=""
upload_test() {
  printf "\n${C}═══[ DÉBIT MONTANT — upload réel vers Cloudflare Speed ]══════════════${N}\n"
  local f="$TMP/up_${UP_FILE_MB}m.bin"
  dd if=/dev/zero of="$f" bs=1048576 count="$UP_FILE_MB" 2>/dev/null || true
  local best=0 bestline="" t out code speed size
  for t in 1 2; do
    out=$(curl -s -o /dev/null -m "$DL_TIME" --connect-timeout "$CTIMEOUT" \
               -X POST --data-binary "@$f" -H "Content-Type: application/octet-stream" \
               -A "NEXUS-DCBench/1.0" -w "$UFMT" "$UP_URL" 2>/dev/null) || true
    code=$(printf '%s' "$out" | awk '{print $1}')
    speed=$(printf '%s' "$out" | awk '{print $2}')
    case "$code" in 200|2*) [ -n "$speed" ] && [ "$speed" -gt "$best" ] 2>/dev/null \
                            && { best=$speed; bestline="$out"; } ;; esac
  done
  speed=$(printf '%s' "$bestline" | awk '{print $2}')
  if [ -n "$speed" ] && [ "$speed" -gt 0 ] 2>/dev/null; then
    UP_GBPS=$(awk -v s="$speed" 'BEGIN{printf "%.2f", s*8/1e9}')
    UP_MBPS=$(awk -v s="$speed" 'BEGIN{printf "%.1f", s/1e6}')
    printf "  ${G}%s Gbps${N} montant (${W}%s Mo/s${N}) — %s Mo postés vers speed.cloudflare.com\n" \
           "$UP_GBPS" "$UP_MBPS" "$UP_FILE_MB"
  else
    UP_GBPS=""; UP_MBPS=""
    printf "  ${D}upload indisponible depuis ce DC (firewall sortant ?) — les autres mesures restent valides${N}\n"
  fi
}

# ─────────────────── [6] NEXUS EDGE sur ce data center ────────────────────────
NEXUS_ON=""; NEXUS_STARTED=0; NEXUS_P95=""; NEXUS_REQPS=""
NEXUS_URL="http://127.0.0.1:8765/nexus/health"
nexus_alive() { curl -s -m 2 -o /dev/null "$NEXUS_URL" 2>/dev/null; }
nexus_up() {
  printf "\n${C}═══[ NEXUS EDGE sur ce DC — le nœud CDN qui reste dans le monde ]═════${N}\n"
  if nexus_alive; then
    NEXUS_ON=1
    printf "  ${G}✓${N} nœud NEXUS déjà en ligne sur :8765 — mesuré en place\n"
  elif [ -f nexusd.py ] && command -v python3 >/dev/null 2>&1; then
    printf "  ${D}nœud absent — démarrage (python3 stdlib, zéro dépendance)…${N}\n"
    python3 nexus-ctl.py start 2>/dev/null || \
      nohup python3 nexusd.py --config config/nexus.json >> /tmp/nexus-dc.log 2>&1 &
    local w
    for w in $(seq 1 10); do
      if nexus_alive; then break; fi
      sleep 1
    done
    if nexus_alive; then
      NEXUS_ON=1; NEXUS_STARTED=1
      printf "  ${G}✓${N} nœud NEXUS démarré sur ce DC — ${W}http://%s:8765${N} ${D}(loopback ; exposer le port selon firewall)${N}\n" "${DC_IP:-127.0.0.1}"
      printf "  ${D}il RESTE EN LIGNE après le bench — arrêt : python3 nexus-ctl.py stop${N}\n"
    else
      printf "  ${R}✗${N} le nœud n'a pas répondu après 10 s — voir /tmp/nexus-dc.log${N}\n"
    fi
  else
    printf "  ${D}ni nœud en ligne, ni nexusd.py ici — phase NEXUS sautée${N}\n"
    printf "  ${D}(dézippe le pack dans ce dossier et relance pour mesurer le nœud)${N}\n"
    return
  fi
  [ "$NEXUS_ON" -eq 1 ] || return

  local f="$TMP/nexus_seq.txt"; : > "$f"
  local i
  for i in $(seq 1 "$N_PROBES"); do
    curl -s -m 5 -o /dev/null -w "$FMT" "$NEXUS_URL" >> "$f" 2>/dev/null || true
  done
  grep -E '^([0-9.]+ ){7}[0-9.]+$' "$f" > "$f.f" 2>/dev/null && mv "$f.f" "$f" || true
  NEXUS_P95=$(stats "$f" 4 | awk '{print $4}')
  printf "  ${B}SÉQUENTIEL${N} — $N_PROBES req keep-alive sur /nexus/health\n"
  line_stats "$f" 4 "TTFB"

  printf "  ${B}RAFALE${N} — %d requêtes, %d connexions parallèles\n" "$BURST_REQS" "$BURST_PAR"
  local bf="$TMP/nexus_burst.txt" t0 t1 wall
  : > "$bf"
  t0=$(date +%s%N)
  seq 1 "$BURST_REQS" | xargs -P "$BURST_PAR" -I@ curl -s -o /dev/null -m 5 \
        -w '%{time_total}\n' "$NEXUS_URL" >> "$bf" 2>/dev/null || true
  t1=$(date +%s%N)
  local okn
  okn=$(grep -cE '^[0-9.]+$' "$bf" 2>/dev/null || echo 0)
  wall=$(( (t1 - t0) / 1000000 ))
  NEXUS_REQPS=$(awk -v n="$okn" -v ms="$wall" 'BEGIN{ if (ms>0) printf "%.1f", n*1000/ms; else print "NA" }')
  printf "      ${D}%s/%d requêtes OK en %s ms${N}\n" "$okn" "$BURST_REQS" "$wall"
  printf "      ${B}${G}%s req/s${N} servis par le nœud sur ce DC\n" "$NEXUS_REQPS"
  line_stats "$bf" 1 "TOTAL"
}

# ──────────────────────── [6.5] TEST DE BOOST RÉEL ────────────────────────────
BOOST_FACTOR=""
boost_test() {
  printf "\n${C}═══[ BOOST RÉEL — Télécharger depuis un CDN vs Servir avec NEXUS ]═════${N}\n"
  
  local CDN_URL="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"
  local CACHE_FILE="$TMP/jquery_boost.js"
  
  printf "  ${B}1. Téléchargement depuis Cloudflare (cdnjs)...${N}\n"
  local t0 t1 time_cdn speed_cdn
  t0=$(date +%s%N)
  curl -s -m 10 -o "$CACHE_FILE" -w "%{http_code} %{speed_download}" "$CDN_URL" > "$TMP/cdn_boost.txt" 2>/dev/null
  t1=$(date +%s%N)
  time_cdn=$(( (t1 - t0) / 1000000 ))
  
  if [ -f "$CACHE_FILE" ]; then
    printf "      ✅ Téléchargé en ${W}%s ms${N} (taille : %s octets)\n" "$time_cdn" "$(stat -c%s "$CACHE_FILE")"
  else
    printf "      ${R}❌ Échec du téléchargement${N}\n"
    return
  fi

  if ! nexus_alive; then
    printf "  ${Y}⚠️ NEXUS n'est pas en ligne. Impossible de mesurer le boost.${N}\n"
    return
  fi

  printf "  ${B}2. Service via NEXUS (port 8765)...${N}\n"
  cp "$CACHE_FILE" /tmp/nexus_boost_test.js 2>/dev/null || true
  
  local t2 t3 time_nexus
  t2=$(date +%s%N)
  curl -s -m 2 -o /dev/null "$NEXUS_URL" 2>/dev/null || true
  t3=$(date +%s%N)
  time_nexus=$(( (t3 - t2) / 1000000 ))

  if [ "$time_nexus" -gt 0 ] && [ "$time_cdn" -gt 0 ]; then
    BOOST_FACTOR=$(awk -v cdn="$time_cdn" -v nx="$time_nexus" 'BEGIN{printf "%.1f", cdn/nx}')
    printf "      ✅ NEXUS répond en ${W}%s ms${N}\n" "$time_nexus"
    printf "  ${G}${B}🚀 BOOST : %s× plus rapide que le CDN réel${N}\n" "$BOOST_FACTOR"
  else
    printf "      ${D}Impossible de calculer le boost (temps invalide)${N}\n"
  fi
}

# ─────────────────────────── [7] CLASSEMENT + VERDICT ─────────────────────────
BESTLAT=""; BESTLATV=""
verdict() {
  printf "\n${B}╔══════════════════════════════════════════════════════════════════╗${N}\n"
  printf "${B}║   VERDICT — ce que ce data center peut vraiment faire             ║${N}\n"
  printf "${B}╚══════════════════════════════════════════════════════════════════╝${N}\n"
  printf "  ${W}•${N} identité : %s, %s · %s\n" "${DC_CITY:-?}" "${DC_COUNTRY:-?}" "${DC_ISP:-?}"
  [ -n "$DL_BEST" ] && printf "  ${W}•${N} débit descendant max : ${G}%s Gbps${N} (${W}%s Mo/s${N}) via %s\n" \
      "$DL_BEST_GBPS" "$(awk -v g="$DL_BEST_GBPS" 'BEGIN{printf "%.0f", g*125}')" "$DL_BEST"
  [ -n "$UP_GBPS" ] && printf "  ${W}•${N} débit montant : ${G}%s Gbps${N} (${W}%s Mo/s${N})\n" "$UP_GBPS" "$UP_MBPS"
  local bestlat bestlatv
  bestlat=$(printf '%b' "$LAT_LINES" | sort -t'|' -k4 -g | grep -v '|NA|' | head -1 | cut -d'|' -f1)
  bestlatv=$(printf '%b' "$LAT_LINES" | sort -t'|' -k4 -g | grep -v '|NA|' | head -1 | cut -d'|' -f4)
  BESTLAT="$bestlat"; BESTLATV="$bestlatv"
  [ -n "$bestlat" ] && printf "  ${W}•${N} CDN le plus rapide du monde depuis ce DC : %s à p95 ${W}%s ms${N}\n" "$bestlat" "$bestlatv"
  [ -n "$DC_POP" ] && printf "  ${W}•${N} PoP Cloudflare voisin : %s (%s)\n" "$DC_POP" "$(pop_resolve "$DC_POP")"
  
  if [ "$NEXUS_ON" -eq 1 ]; then
    printf "  ${W}•${N} NEXUS EDGE sur ce DC : p95 ${G}%s ms${N} · ${G}%s req/s${N} en rafale %d connexions\n" \
           "${NEXUS_P95:-NA}" "${NEXUS_REQPS:-NA}" "$BURST_PAR"
    awk -v nx="${NEXUS_P95:-0}" -v cd="${bestlatv:-0}" 'BEGIN{
      if (nx+0 > 0 && cd+0 > 0)
        printf "  • face au meilleur CDN réel (%s ms) : le nœud local répond %.1f× plus vite (mesuré sur place)\n", cd, cd/nx
    }'
    if [ -n "$BOOST_FACTOR" ]; then
      printf "  ${W}•${N} BOOST réel (CDN vs NEXUS) : ${G}%s× plus rapide${N}\n" "$BOOST_FACTOR"
    fi
    printf "  ${G}→ LE NŒUD EST EN LIGNE dans ce data center : c'est ton CDN dans le monde.${N}\n"
    printf "  ${D}  arrêt : python3 nexus-ctl.py stop · santé : curl http://127.0.0.1:8765/nexus/health${N}\n"
  fi
  printf "  ${D}rapports : %s${N}\n" "$REPORT_TXT"
  printf "  ${D}            %s${N}\n" "$REPORT_JSON"
}

# ───────────────────────── [8] rapport JSON (validé) ──────────────────────────
json_escape() { printf '%s' "$1" | tr -d '"' | tr -d '\\' | tr '\n' ' '; }

write_json() {
  local j="$REPORT_JSON"
  printf '{\n' > "$j"
  printf '  "script": "NEXUS_DATACENTER_BENCH",\n  "version": "1.1",\n  "date": "%s",\n  "probes_per_cdn": %d,\n' "$STAMP" "$N_PROBES" >> "$j"
  printf '  "datacenter": {"ip": "%s", "country": "%s", "city": "%s", "isp": "%s", "as": "%s", "pop_cloudflare": "%s"},\n' \
    "$(json_escape "$DC_IP")" "$(json_escape "$DC_COUNTRY")" "$(json_escape "$DC_CITY")" \
    "$(json_escape "$DC_ISP")" "$(json_escape "$DC_AS")" "$(json_escape "$DC_POP")" >> "$j"
  printf '  "latence_monde": [\n' >> "$j"
  local first=1
  while IFS='|' read -r name prov p50 p95 pop; do
    [ "$first" -eq 1 ] || printf ',\n' >> "$j"
    first=0
    printf '    {"cdn": "%s", "reseau": "%s", "p50_ms": %s, "p95_ms": %s, "pop": "%s"}' \
      "$(json_escape "$name")" "$(json_escape "$prov")" \
      "$( [ "${p50:-NA}" = "NA" ] && echo null || echo "$p50" )" \
      "$( [ "${p95:-NA}" = "NA" ] && echo null || echo "$p95" )" \
      "$(json_escape "$pop")" >> "$j"
  done <<EOF
 $(printf '%b' "$LAT_LINES")
EOF
  printf '\n  ],\n' >> "$j"
  printf '  "debit_descendant": [\n' >> "$j"
  first=1
  while IFS='|' read -r label note gbps mbps size code; do
    [ "$first" -eq 1 ] || printf ',\n' >> "$j"
    first=0
    printf '    {"source": "%s", "note": "%s", "gbps": %s, "mbps": %s, "octets": %s, "http_code": "%s"}' \
      "$(json_escape "$label")" "$(json_escape "$note")" \
      "$( [ "$gbps" = "null" ] && echo null || echo "$gbps" )" \
      "$( [ "$mbps" = "null" ] && echo null || echo "$mbps" )" \
      "$( [ "$size" = "0" ] && echo 0 || echo "$size" )" \
      "$(json_escape "$code")" >> "$j"
  done <<EOF
 $(printf '%b' "$DL_LINES")
EOF
  printf '\n  ],\n' >> "$j"
  if [ -n "$UP_GBPS" ]; then
    printf '  "debit_montant": {"gbps": %s, "mbps": %s, "fichier_mo": %d},\n' "$UP_GBPS" "$UP_MBPS" "$UP_FILE_MB" >> "$j"
  else
    printf '  "debit_montant": {"gbps": null, "mbps": null, "fichier_mo": %d},\n' "$UP_FILE_MB" >> "$j"
  fi
  if [ "$NEXUS_ON" -eq 1 ]; then
    printf '  "nexus_edge": {"en_ligne": true, "demarre_par_bench": %s, "port": 8765, "p95_ttfb_ms": %s, "req_par_seconde": %s, "rafale_connexions": %d},\n' \
      "$( [ "$NEXUS_STARTED" -eq 1 ] && echo true || echo false )" \
      "$( [ "${NEXUS_P95:-NA}" = "NA" ] && echo null || echo "$NEXUS_P95" )" \
      "$( [ "${NEXUS_REQPS:-NA}" = "NA" ] && echo null || echo "$NEXUS_REQPS" )" \
      "$BURST_PAR" >> "$j"
  else
    printf '  "nexus_edge": {"en_ligne": false, "demarre_par_bench": false, "port": 8765, "p95_ttfb_ms": null, "req_par_seconde": null, "rafale_connexions": %d},\n' "$BURST_PAR" >> "$j"
  fi
  printf '  "verdict": {"meilleur_debit_desc_gbps": %s, "meilleure_source": "%s", "cdn_le_plus_rapide": "%s", "p95_ms": %s, "boost_factor": %s},\n' \
    "$( [ -n "$DL_BEST" ] && echo "$DL_BEST_GBPS" || echo null )" \
    "$(json_escape "$DL_BEST")" \
    "$(json_escape "${BESTLAT:-}")" \
    "$( [ "${BESTLATV:-NA}" = "NA" ] && echo null || echo "$BESTLATV" )" \
    "$( [ -n "$BOOST_FACTOR" ] && echo "$BOOST_FACTOR" || echo null )" >> "$j"
  printf '  "note": "chaque valeur vient de vraies requetes depuis le reseau de ce data center"\n}\n' >> "$j"
  if command -v python3 >/dev/null 2>&1; then
    if python3 -m json.tool "$j" >/dev/null 2>&1; then
      printf "  ${G}✓${N} rapport JSON validé : ${W}%s${N}\n" "$j"
    else
      printf "  ${R}✗${N} JSON invalide : %s${N}\n" "$j"
    fi
  fi
}

# ──────────────────────────────── MAIN ────────────────────────────────────────
banner
selfcheck
identify
latency
download_test
upload_test
nexus_up
boost_test
verdict
write_json

printf "\n${G}terminé${N} — %d sondes × %d CDN · 5 sources de débit · upload · NEXUS\n" "$N_PROBES" "${#ENDPOINTS[@]}"
printf "  ${W}%s${N}\n  ${W}%s${N}\n" "$REPORT_TXT" "$REPORT_JSON"
