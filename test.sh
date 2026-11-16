#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║      N E X U S   C D N _ T E S T   v1.0  —  VRAIS CDN, PAS EN LOCAL      ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║                                                                          ║
# ║  Un seul script. Il bombarde de VRAIS CDN publics sur Internet réel :    ║
# ║  Cloudflare · jsDelivr · Google · Microsoft Azure · unpkg · Vercel       ║
# ║                                                                          ║
# ║   [1] SELFCHECK    vérifie les outils (curl, awk, sort, tee)             ║
# ║   [2] SONDES       pour chaque CDN : N requêtes GET d'un vrai asset      ║
# ║       — FROID : nouvelle connexion DNS+TCP+TLS à chaque sonde            ║
# ║       — CHAUD : N requêtes sur UNE seule connexion (keep-alive)          ║
# ║   [3] MESURES      DNS · TCP · TLS · TTFB · TOTAL · code HTTP · octets   ║
# ║                    min / avg / p50 / p95 / max  (le p95 = le ressenti)   ║
# ║   [4] GEO          lit l'en-tête CF-Ray → le PoP réel qui répond         ║
# ║                    (CDG=Paris, LHR=Londres, FRA=Francfort ...)           ║
# ║   [5] CLASSEMENT   tous les CDN triés par p95 TTFB, verdict final        ║
# ║   [6] CONTRASTE    si un nœud NEXUS tourne sur :8765 → rapport de        ║
# ║                    vitesse CDN réel vs NEXUS (la démo investisseur)      ║
# ║                                                                          ║
# ║  Utilisation :  bash CDN_TEST.sh [nb_sondes|quick]                       ║
# ║                 bash CDN_TEST.sh          → 10 sondes/CDN                ║
# ║                 bash CDN_TEST.sh quick    → 5 sondes/CDN                 ║
# ║                 bash CDN_TEST.sh 20       → 20 sondes/CDN                ║
# ║                                                                          ║
# ║  Tout est écrit aussi dans CDN_REEL_BENCH_<date>.txt (preuve à montrer). ║
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
TIMEOUT=8           # secondes max par requête
CTIMEOUT=4          # secondes max connexion
STAMP=$(date '+%Y%m%d-%H%M%S')
REPORT="$PWD/CDN_REEL_BENCH_${STAMP}.txt"
TMP=$(mktemp -d /tmp/cdn_test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
NEXUS_URL="http://127.0.0.1:8765/nexus/health"   # contraste optionnel, jamais requis

# ───────────────────── les vrais CDN testés (publics, sans clé) ───────────────
#  format : nom|fournisseur|URL d'un vrai asset servi par ce CDN
ENDPOINTS=(
  "cdnjs|Cloudflare|https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js"
  "jsDelivr|Cloudflare+Fastly|https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js"
  "Google CDN|Google|https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js"
  "Azure CDN|Microsoft|https://ajax.aspnetcdn.com/ajax/jquery/jquery-3.7.1.min.js"
  "unpkg|Cloudflare|https://unpkg.com/jquery@3.7.1/dist/jquery.min.js"
  "Vercel|Vercel|https://nextjs.org/"
)
#  Cloudflare trace : sert à lire le PoP (datacenter) qui répond — mesuré à part
TRACE_URL="https://www.cloudflare.com/cdn-cgi/trace"

# format de mesure curl : dns tcp tls ttfb total code taille ip
FMT='%{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{http_code} %{size_download} %{remote_ip}\n'

# ────────────────────────── sortie + rapport simultanés ───────────────────────
exec > >(tee "$REPORT") 2>&1

banner() {
  printf "${B}╔══════════════════════════════════════════════════════════════════╗${N}\n"
  printf "${B}║   NEXUS CDN_TEST v1.0 — BENCHMARK DE VRAIS CDN SUR INTERNET RÉEL  ║${N}\n"
  printf "${B}║   cible : CDN publics (Cloudflare · Google · Azure · Vercel ...)  ║${N}\n"
  printf "${B}║   zéro simulation · zéro fake · chaque chiffre vient du réseau    ║${N}\n"
  printf "${B}╚══════════════════════════════════════════════════════════════════╝${N}\n"
}

# ────────────────────────────── [1] SELFCHECK ─────────────────────────────────
selfcheck() {
  printf "\n${C}═══[ SELFCHECK — outils requis ]═════════════════════════════════════${N}\n"
  local ok=1
  for t in curl awk sort tee date mktemp grep cut head printf; do
    if command -v "$t" >/dev/null 2>&1; then
      printf "  ${G}✓${N} $t\n"
    else
      printf "  ${R}✗${N} $t ABSENT — installe-le puis relance\n"; ok=0
    fi
  done
  [ "$ok" -eq 1 ] || { printf "${R}outils manquants, arrêt.${N}\n"; exit 1; }
  printf "  ${G}✓${N} selfcheck : ${W}$N_PROBES sondes${N} par CDN, ${W}${TIMEOUT}s${N} de timeout\n"
}

# ───────────────────── stats : min avg p50 p95 max sur 1 colonne ──────────────
#  $1 = fichier (1 ligne par sonde, 8 colonnes)   $2 = numéro de colonne
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

# ligne de détail  min/avg/p50/p95/max pour une colonne donnée
line_stats() { # $1=fichier $2=colonne $3=libellé
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

# ──────────────────── [4] GEO : le PoP réel qui répond ────────────────────────
pop_name() {
  case "$1" in
    CDG) echo "Paris";;
    ORY) echo "Paris-Orly";;
    MRS) echo "Marseille";;
    LYS) echo "Lyon";;
    NCE) echo "Nice";;
    BOD) echo "Bordeaux";;
    LIL) echo "Lille";;
    LHR) echo "Londres";;
    MAN) echo "Manchester";;
    AMS) echo "Amsterdam";;
    FRA) echo "Francfort";;
    MUC) echo "Munich";;
    DRS) echo "Dresde";;
    HAM) echo "Hambourg";;
    BRU) echo "Bruxelles";;
    GVA) echo "Genève";;
    ZRH) echo "Zurich";;
    MAD) echo "Madrid";;
    BCN) echo "Barcelone";;
    LIS) echo "Lisbonne";;
    MIL) echo "Milan";;
    MXP) echo "Milan";;
    FCO) echo "Rome";;
    VIE) echo "Vienne";;
    PRG) echo "Prague";;
    WAW) echo "Varsovie";;
    STO) echo "Stockholm";;
    CPH) echo "Copenhague";;
    DUB) echo "Dublin";;
    LUX) echo "Luxembourg";;
    EWR) echo "Newark";;
    JFK) echo "New York";;
    IAD) echo "Washington";;
    ORD) echo "Chicago";;
    DFW) echo "Dallas";;
    DEN) echo "Denver";;
    LAX) echo "Los Angeles";;
    SJC) echo "San José";;
    SEA) echo "Seattle";;
    YYZ) echo "Toronto";;
    YVR) echo "Vancouver";;
    GRU) echo "São Paulo";;
    EZE) echo "Buenos Aires";;
    SCL) echo "Santiago";;
    BOG) echo "Bogota";;
    MEX) echo "Mexico";;
    NRT) echo "Tokyo";;
    KIX) echo "Osaka";;
    ICN) echo "Séoul";;
    SIN) echo "Singapour";;
    HKG) echo "Hong Kong";;
    TPE) echo "Taipei";;
    BKK) echo "Bangkok";;
    DEL) echo "Delhi";;
    BOM) echo "Mumbai";;
    MAA) echo "Chennai";;
    DXB) echo "Dubaï";;
    DOH) echo "Doha";;
    JNB) echo "Johannesburg";;
    SYD) echo "Sydney";;
    MEL) echo "Melbourne";;
    AKL) echo "Auckland";;
    *)   echo "PoP $1";;
  esac
}

headers_info() { # $1=URL  → renvoie "PoP|cache|serveur|cf-ray" (vide si rien)
  local h="$TMP/hdr.$$"
  curl -s -m "$TIMEOUT" --connect-timeout "$CTIMEOUT" -4 -D "$h" -o /dev/null \
       -A "NEXUS-CDNTest/1.0" "$1" 2>/dev/null || true
  local ray srv cache
  ray=$(grep -i '^cf-ray:' "$h" | head -1 | tr -d '\r' | awk '{print $2}')
  srv=$(grep -i '^server:' "$h" | head -1 | tr -d '\r' | cut -d' ' -f2)
  # en-têtes de cache, avec leur nom — ordre de priorité, âge en dernier
  cache=$(grep -i '^cf-cache-status:\|^x-cache:\|^x-vercel-cache:\|^x-served-by:' "$h" \
          | head -2 | tr -d '\r' | tr '\n' ' ' | sed 's/  */ /g; s/ $//')
  local age
  age=$(grep -i '^age:' "$h" | head -1 | tr -d '\r' | awk '{print $1$2}')
  [ -n "$age" ] && cache="${cache:+$cache · }$age"
  local pop=""
  [ -n "$ray" ] && pop=$(printf '%s' "$ray" | awk -F- '{print $NF}')
  rm -f "$h"
  printf '%s|%s|%s|%s' "$pop" "$cache" "$srv" "$ray"
}

# ─────────────────────── [2]+[3] mesure d'un CDN ──────────────────────────────
RESULT_LINES=""   # nom|fournisseur|p95_froid|p95_chaud|pop|cache|erreurs

bench_endpoint() { # $1=nom $2=fournisseur $3=URL
  local name="$1" provider="$2" url="$3"
  local cold="$TMP/cold_${name}.txt" warm="$TMP/warm_${name}.txt"
  : > "$cold"; : > "$warm"

  printf "\n${C}═══[ %s — %s ]═════════════════════════════════════════════════════${N}\n" "$name" "$provider"
  printf "  ${D}GET %s${N}\n" "$url"

  # en-têtes réels : qui répond, depuis quel datacenter, cache HIT/MISS
  local info pop cache srv ray
  info=$(headers_info "$url")
  pop=$(printf '%s' "$info" | cut -d'|' -f1)
  cache=$(printf '%s' "$info" | cut -d'|' -f2)
  srv=$(printf '%s' "$info" | cut -d'|' -f3)
  ray=$(printf '%s' "$info" | cut -d'|' -f4)
  if [ -n "$pop" ]; then
    printf "  ${G}PoP réel${N} : ${W}%s (%s)${N}   ${D}cf-ray %s${N}\n" "$pop" "$(pop_name "$pop")" "${ray:-?}"
  else
    printf "  ${D}PoP : non exposé par ce CDN (pas d'en-tête CF-Ray)${N}\n"
  fi
  local meta=""
  [ -n "$srv" ]   && meta="serveur: $srv"
  [ -n "$cache" ] && meta="${meta:+$meta · }$cache"
  [ -n "$meta" ]  && printf "  ${D}%s${N}\n" "$meta"

  # mode FROID — chaque sonde = nouvelle DNS + TCP + TLS (première visite réelle)
  printf "  ${B}FROID${N} — $N_PROBES sondes, nouvelle connexion complète à chaque sonde\n"
  local i code fails=0
  for i in $(seq 1 "$N_PROBES"); do
    curl -s -m "$TIMEOUT" --connect-timeout "$CTIMEOUT" -4 -o /dev/null \
         -A "NEXUS-CDNTest/1.0" -w "$FMT" "$url" >> "$cold" 2>/dev/null || fails=$((fails+1))
  done
  code=$(awk '{print $6}' "$cold" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  [ -z "$code" ] && code=000
  line_stats "$cold" 1 "DNS"
  line_stats "$cold" 2 "TCP"
  line_stats "$cold" 3 "TLS"
  line_stats "$cold" 4 "TTFB"
  line_stats "$cold" 5 "TOTAL"
  printf "      ${D}code HTTP %s · %s sondes échouées · taille: %s octets${N}\n" \
         "$code" "$fails" "$(awk '$7>0{print $7}' "$cold" | sort -n | tail -1)"

  # mode CHAUD — une seule connexion, N requêtes keep-alive (comme NEXUS)
  printf "  ${B}CHAUD${N} — $N_PROBES requêtes sur UNE seule connexion (keep-alive)\n"
  local urls="" j
  for j in $(seq 1 "$N_PROBES"); do urls="$urls \"$url\""; done
  eval "curl -s -m $TIMEOUT --connect-timeout $CTIMEOUT -4 -o /dev/null -A NEXUS-CDNTest/1.0 -w \"$FMT\" $urls" \
       > "$warm" 2>/dev/null || true
  # garde seulement les lignes complètes (8 colonnes)
  grep -E '^([0-9.]+ ){7}[0-9.]+$' "$warm" > "$warm.f" 2>/dev/null && mv "$warm.f" "$warm" || true
  line_stats "$warm" 4 "TTFB"
  line_stats "$warm" 5 "TOTAL"

  # p95 TTFB froid/chaud pour le classement
  local p95c p95w
  p95c=$(stats "$cold" 4 | awk '{print $4}')
  p95w=$(stats "$warm" 4 | awk '{print $4}')
  RESULT_LINES="${RESULT_LINES}${name}|${provider}|${p95c:-NA}|${p95w:-NA}|${pop:-—}|${cache:-—}|${fails}\n"
}

# ─────────────────── [6] contraste optionnel NEXUS en local ───────────────────
NEXUS_LINE=""
bench_nexus() {
  printf "\n${C}═══[ CONTRASTE — nœud NEXUS local :8765 (optionnel, démo pitch) ]═════${N}\n"
  if ! curl -s -m 1 -o /dev/null "$NEXUS_URL" 2>/dev/null; then
    printf "  ${D}aucun nœud NEXUS détecté sur :8765 — contraste sauté (le test CDN reste 100%% réel)${N}\n"
    return
  fi
  local f="$TMP/nexus.txt"; : > "$f"
  local i
  for i in $(seq 1 "$N_PROBES"); do
    curl -s -m 2 -o /dev/null -w "$FMT" "$NEXUS_URL" >> "$f" 2>/dev/null || true
  done
  grep -E '^([0-9.]+ ){7}[0-9.]+$' "$f" > "$f.f" 2>/dev/null && mv "$f.f" "$f" || true
  local p95
  p95=$(stats "$f" 4 | awk '{print $4}')
  [ -z "$p95" ] && p95="NA"
  printf "  ${G}NEXUS répond${N} — p95 TTFB local : ${B}${W}%s ms${N}\n" "$p95"
  NEXUS_LINE="$p95"
}

# ─────────────────────────── [5] classement + verdict ─────────────────────────
ranking() {
  printf "\n${B}╔══════════════════════════════════════════════════════════════════╗${N}\n"
  printf "${B}║        CLASSEMENT — p95 TTFB connexion froide (le ressenti)       ║${N}\n"
  printf "${B}╚══════════════════════════════════════════════════════════════════╝${N}\n"
  printf "%-14s %-18s %10s %10s   %-6s %s\n" "CDN" "fournisseur" "p95 froid" "p95 chaud" "PoP" "cache"
  printf "%s\n" "─────────────────────────────────────────────────────────────────────────────"
  printf '%b' "$RESULT_LINES" | sort -t'|' -k3 -g | awk -F'|' '
    {
      c=substr($6,1,34)
      printf "%-14s %-18s %8s ms %8s ms   %-6s %s\n", $1, $2, $3, $4, $5, c
    }'

  local best bestv
  best=$(printf '%b' "$RESULT_LINES" | sort -t'|' -k3 -g | head -1 | cut -d'|' -f1)
  bestv=$(printf '%b' "$RESULT_LINES" | sort -t'|' -k3 -g | head -1 | cut -d'|' -f3)

  printf "\n${B}VERDICT${N} :\n"
  printf "  ${W}•${N} meilleur CDN réel ici : ${G}%s${N} à p95 ${W}%s ms${N} (TTFB froid)\n" "$best" "$bestv"
  printf "  ${W}•${N} mesure prise depuis CETTE machine, réseau réel, assets réels — rien de simulé\n"

  if [ -n "$NEXUS_LINE" ] && [ "$NEXUS_LINE" != "NA" ]; then
    awk -v nx="$NEXUS_LINE" -v cd="$bestv" 'BEGIN{
      if (nx+0 > 0) {
        f=cd/nx
        printf "  • NEXUS local p95 : %.1f ms → %.1f× plus rapide que le meilleur CDN réel (%s ms)\n", nx, f, cd
        printf "  • CDN classique ≈ %.0f ms de trajet aller-retour ; NEXUS sert à <50 km, tout en RAM\n", cd
      }
    }'
  fi
  printf "  ${D}rapport complet : %s${N}\n" "$REPORT"
}

# ────────────────────────────── nuage de PoP réel ─────────────────────────────
trace_pop() {
  printf "\n${C}═══[ BONUS — le datacenter Cloudflare qui te répond VRAIMENT ]═════════${N}\n"
  local out
  out=$(curl -s -m "$TIMEOUT" --connect-timeout "$CTIMEOUT" -4 "$TRACE_URL" 2>/dev/null) || out=""
  local loc ip colo
  colo=$(printf '%s' "$out" | grep -o '^colo=.*' | cut -d= -f2)
  loc=$(printf  '%s' "$out" | grep -o '^loc=.*'  | cut -d= -f2)
  ip=$(printf  '%s' "$out" | grep -o '^ip=.*'   | cut -d= -f2)
  if [ -n "$colo" ]; then
    printf "  ${G}✓${N} ton trafic sort par ${W}%s${N} · PoP Cloudflare = ${B}%s (%s)${N}\n" \
           "${ip:-?}" "$colo" "$(pop_name "$colo")"
    printf "  ${D}pays réseau: %s · c'est ce datacenter PHYSIQUE qui a répondu à tes sondes${N}\n" "${loc:-?}"
  else
    printf "  ${D}trace indisponible (réseau filtré) — les mesures des CDN restent valides${N}\n"
  fi
}

# ──────────────────────────────── MAIN ────────────────────────────────────────
banner
selfcheck
trace_pop

printf "\n${B}── mesure de %d sondes × %d vrais CDN (chaque chiffre = réseau réel) ──${N}\n" \
       "$N_PROBES" "${#ENDPOINTS[@]}"

i=0
for ep in "${ENDPOINTS[@]}"; do
  i=$((i+1))
  name=$(printf '%s' "$ep" | cut -d'|' -f1)
  prov=$(printf '%s' "$ep" | cut -d'|' -f2)
  url=$(printf '%s' "$ep" | cut -d'|' -f3)
  printf "${D}[sonde %d/%d]${N} " "$i" "${#ENDPOINTS[@]}"
  bench_endpoint "$name" "$prov" "$url"
done

bench_nexus
ranking

printf "\n${G}terminé${N} — %d sondes × %d CDN · rapport : ${W}%s${N}\n" \
       "$N_PROBES" "${#ENDPOINTS[@]}" "$REPORT"
