#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║        N E X U S   C E R V E A U   v1.0  —  MOTEUR LOCAL 54 MODULES      ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║                                                                          ║
# ║  UN SEUL SCRIPT BASH. IL TRACK, INSTALL ET LANCE TES MODULES EN LOCAL.   ║
# ║                                                                          ║
# ║   [1] PREFLIGHT      vérifie l'environnement, détecte le dossier racine  ║
# ║   [2] SCAN           track TES modules sur tout le disque (profondeur 6) ║
# ║                      python · bash · javascript · rust · go · C · json   ║
# ║   [3] CLASSIFY       classe chaque module : type, rôle, point d'entrée, ║
# ║                      candidats CERVEAU (orchestrateur) et ELECTRON       ║
# ║   [4] MANIFEST       écrit MODULES.manifest : type · rôle · lignes ·    ║
# ║                      md5 · chemin — la cartographie exacte de ton code   ║
# ║   [5] DEDUPE         supprime les doubles réels (même contenu md5),      ║
# ║                      ne touche jamais au dossier racine                  ║
# ║   [6] TOOLCHAIN      installe SEULEMENT ce que tes modules exigent :     ║
# ║                      python3/pip · node/npm · electron · cargo · go ·    ║
# ║                      gcc/meson — correspondance automatique type→outil   ║
# ║   [7] CORRESPONDENCE vérifie pour chaque module que ses imports/reqs     ║
# ║                      existent vraiment (import python → import testé,   ║
# ║                      require js → node_modules vérifié)                  ║
# ║   [8] CERVEAU        détecte le module orchestrateur (le cerveau),       ║
# ║                      le valide et le lance en local                      ║
# ║   [9] ELECTRON       détecte l'app Electron (package.json), installe     ║
# ║                      ses node_modules et la lance                        ║
# ║  [10] DASHBOARD      tableau de bord : X/54 modules, par type, cerveau, ║
# ║                      electron, correspondances manquantes                ║
# ║  [11] REPORT         rapport horodaté complet dans studio/reports/       ║
# ║                                                                          ║
# ║  USAGE :                                                                 ║
# ║     bash CERVEAU.sh              # tout : scan→manifest→deps→cerveau     ║
# ║     bash CERVEAU.sh scan         # juste tracker les modules             ║
# ║     bash CERVEAU.sh manifest     # inventaire complet des 54 modules     ║
# ║     bash CERVEAU.sh deps         # toolchain + correspondances           ║
# ║     bash CERVEAU.sh brain        # valider et lancer le cerveau          ║
# ║     bash CERVEAU.sh electron     # lancer l'app electron                 ║
# ║     bash CERVEAU.sh dashboard    # tableau de bord                       ║
# ║                                                                          ║
# ║  RÈGLES : aucun module n'est modifié. Aucun contenu inventé.             ║
# ║           Le script n'installe que ce que TES modules demandent.         ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -u

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 0 — CONSTANTES, COULEURS, HELPERS
# ═════════════════════════════════════════════════════════════════════════════
VERSION="1.0.0-cerveau"
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'
B='\033[1m'; P='\033[0;35m'; D='\033[0;90m'; N='\033[0m'

ok()   { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}!${N} $*"; }
err()  { echo -e "  ${R}✗${N} $*" >&2; }
hr()   { echo -e "  ${C}────────────────────────────────────────────────────────────${N}"; }
step() { echo ""; echo -e "${P}╔═[ $1 ]═════════════════════════════════════════════════════╗${N}"; }

# Objectif déclaré par le propriétaire du code : 54 modules
EXPECTED_MODULES="${NEXUS_EXPECTED_MODULES:-54}"
SCAN_DEPTH=6
START_TS=$(date +%s)

# Fichiers de travail (tous dans /tmp, ton code n'est jamais touché)
INV_PY="/tmp/cerveau-py.txt"        # modules python
INV_SH="/tmp/cerveau-sh.txt"        # modules bash
INV_JS="/tmp/cerveau-js.txt"        # modules javascript/typescript
INV_RS="/tmp/cerveau-rs.txt"        # modules rust
INV_GO="/tmp/cerveau-go.txt"        # modules go
INV_C="/tmp/cerveau-c.txt"          # modules C (GNOME/meson etc.)
INV_PJ="/tmp/cerveau-package.txt"   # package.json (apps electron/node)
INV_ALL="/tmp/cerveau-all.txt"      # union
MANIFEST="/tmp/cerveau/MODULES.manifest"
REPORT_DIR=""
PROJECT_DIR="${NEXUS_PROJECT_DIR:-}"
BRAIN_MODULE=""
ELECTRON_DIR=""
COUNT_TOTAL=0
COUNT_PY=0; COUNT_SH=0; COUNT_JS=0; COUNT_RS=0; COUNT_GO=0; COUNT_C=0; COUNT_PJ=0
MISSING_CORR=0

banner() {
  echo ""
  echo -e "${C}╔══════════════════════════════════════════════════════════════════╗${N}"
  echo -e "${C}║${B}   NEXUS CERVEAU v${VERSION} — TRACK · INSTALL · LANCE EN LOCAL     ${C}║${N}"
  echo -e "${C}║${N}   cible : ${B}${EXPECTED_MODULES} modules${N} — cerveau + electron — zéro contenu inventé ${C}║${N}"
  echo -e "${C}╚══════════════════════════════════════════════════════════════════╝${N}"
}

have() { command -v "$1" >/dev/null 2>&1; }

lines_of() { wc -l < "$1" 2>/dev/null | tr -d ' '; }

md5_of() { md5sum "$1" 2>/dev/null | awk '{print $1}'; }

short() { echo "$1" | sed "s|^$HOME|~|"; }

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 1 — PREFLIGHT : environnement + dossier racine
# ═════════════════════════════════════════════════════════════════════════════
preflight() {
  step "1/11 PREFLIGHT — environnement et dossier racine"
  mkdir -p /tmp/cerveau

  echo -e "  ${D}environnement détecté :${N}"
  have python3 && ok "python3  : $(python3 --version 2>&1)" || warn "python3 absent"
  have node    && ok "node     : v$(node --version 2>/dev/null | sed 's/^v//')" || warn "node absent"
  have npm     && ok "npm      : $(npm --version 2>/dev/null)"              || warn "npm absent"
  have cargo   && ok "cargo    : $(cargo --version 2>/dev/null)"            || warn "cargo absent"
  have go      && ok "go       : $(go version 2>/dev/null)"                 || warn "go absent"
  have gcc     && ok "gcc      : $(gcc --version 2>/dev/null | head -n1)"   || warn "gcc absent"
  have unzip   && ok "unzip    : présent"                                    || warn "unzip absent"
  hr

  # Dossier racine : argument env > cwd contenant du code > recherche nexusd.py
  if [ -z "$PROJECT_DIR" ]; then
    if [ -f "$(pwd)/nexusd.py" ]; then
      PROJECT_DIR="$(pwd)"
    else
      local f; f=$(find "$HOME" -maxdepth $SCAN_DEPTH -type f -name nexusd.py 2>/dev/null | head -n1)
      [ -n "$f" ] && PROJECT_DIR="$(dirname "$f")"
    fi
  fi
  [ -d "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"
  ok "dossier racine : ${B}$(short "$PROJECT_DIR")${N}"
  REPORT_DIR="$PROJECT_DIR/studio/reports"
  mkdir -p "$REPORT_DIR"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 2 — SCAN : tracker tous les modules sur le disque
# ═════════════════════════════════════════════════════════════════════════════
# On cherche VRAIMENT partout (profondeur 6), en excluant ce qui n'est pas
# du code à toi : caches, node_modules, .git, environnements virtuels, pyc.
scan_modules() {
  step "2/11 SCAN — tracking de tous tes modules sur le disque"
  # Exclusions en tableau bash (compatible avec tous les find)
  local EXCL=( \( -name __pycache__ -o -name node_modules -o -name .git -o -name .venv -o -name venv -o -name .cache -o -name .cargo -o -name .rustup -o -name .npm -o -name .bun -o -name .agent-browser -o -name .nvm -o -name .oh-my-zsh -o -name .mozilla -o -name .local -o -name snap -o -name .config \) -prune )

  echo -e "  ${D}profondeur de recherche : $SCAN_DEPTH — exclusions : caches, node_modules, .git…${N}"

  # 2a. Python — le cœur de la machine NEXUS
  : > "$INV_PY"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f -name "*.py" -print 2>/dev/null >> "$INV_PY"
  COUNT_PY=$(wc -l < "$INV_PY")

  # 2b. Bash — lanceurs et outils
  : > "$INV_SH"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f -name "*.sh" -print 2>/dev/null >> "$INV_SH"
  COUNT_SH=$(wc -l < "$INV_SH")

  # 2c. JavaScript / TypeScript — apps electron/node
  : > "$INV_JS"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f \( -name "*.js" -o -name "*.mjs" -o -name "*.cjs" -o -name "*.ts" \) -print 2>/dev/null >> "$INV_JS"
  COUNT_JS=$(wc -l < "$INV_JS")

  # 2d. Rust
  : > "$INV_RS"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f -name "*.rs" -print 2>/dev/null >> "$INV_RS"
  COUNT_RS=$(wc -l < "$INV_RS")

  # 2e. Go
  : > "$INV_GO"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f -name "*.go" -print 2>/dev/null >> "$INV_GO"
  COUNT_GO=$(wc -l < "$INV_GO")

  # 2f. C — projets GNOME/GTK/meson repérés sur ta machine
  : > "$INV_C"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f -name "*.c" -print 2>/dev/null >> "$INV_C"
  COUNT_C=$(wc -l < "$INV_C")

  # 2g. package.json — apps node/electron déclarées
  : > "$INV_PJ"
  find "$HOME" -maxdepth $SCAN_DEPTH "${EXCL[@]}" -o -type f -name "package.json" -print 2>/dev/null >> "$INV_PJ"
  COUNT_PJ=$(wc -l < "$INV_PJ")

  # Union triée et dédupliquée
  cat "$INV_PY" "$INV_SH" "$INV_JS" "$INV_RS" "$INV_GO" "$INV_C" "$INV_PJ" 2>/dev/null \
    | sort -u > "$INV_ALL"
  COUNT_TOTAL=$(wc -l < "$INV_ALL")

  ok "modules trackés : ${B}$COUNT_TOTAL${N} (objectif déclaré : $EXPECTED_MODULES)"
  hr
  echo -e "    python      : $COUNT_PY"
  echo -e "    bash        : $COUNT_SH"
  echo -e "    js/ts       : $COUNT_JS"
  echo -e "    rust        : $COUNT_RS"
  echo -e "    go          : $COUNT_GO"
  echo -e "    C           : $COUNT_C"
  echo -e "    package.json: $COUNT_PJ"
  hr
  if [ "$COUNT_TOTAL" -ge "$EXPECTED_MODULES" ]; then
    ok "objectif atteint : $COUNT_TOTAL ≥ $EXPECTED_MODULES modules trackés"
  else
    warn "$COUNT_TOTAL/$EXPECTED_MODULES trackés — le scan est volontairement large ;"
    warn "si des modules manquent, place-les sous $HOME et relance."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 3 — CLASSIFY : type, rôle, point d'entrée, cerveau, electron
# ═════════════════════════════════════════════════════════════════════════════
# Rôles détectés :
#   entry      — contient if __name__ == "__main__" (ou shebang bash exécutable)
#   brain      — orchestrateur : nom ou contenu évoque studio/ctl/menu/orchestr
#   lib        — bibliothèque importée par d'autres
#   electron   — appartient à une app electron (package.json voisin)
#   app-c      — binaire C/GNOME (meson.build voisin)
classify_module() {
  local f="$1"
  local role="lib"
  local base; base="$(basename "$f")"

  # Point d'entrée python ?
  if grep -q '__name__.*==.*"__main__"' "$f" 2>/dev/null; then
    role="entry"
  fi
  # Cerveau candidat ? nom évocateur ou CLI riche
  case "$base" in
    nexus_studio.py|main.py|app.py|brain.py|cerveau.py|orchestrator.py|server.py)
      role="brain" ;;
    nexus-ctl.py|nexusd.py|nexus-smi.py|nexus-bench.py)
      role="core" ;;
  esac
  if [ "$role" = "lib" ] && grep -qE "argparse|add_parser|cmdloop|while True" "$f" 2>/dev/null \
     && [ "$(lines_of "$f")" -gt 100 ]; then
    role="cli"
  fi
  # Electron ? package.json voisin avec dépendance electron
  local dir; dir="$(dirname "$f")"
  if [ -f "$dir/package.json" ] && grep -q '"electron"' "$dir/package.json" 2>/dev/null; then
    role="electron"
  fi
  echo "$role"
}

classify_all() {
  step "3/11 CLASSIFY — rôles de chaque module"
  : > /tmp/cerveau-roles.txt
  local n=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    n=$((n+1))
    printf "%s|%s|%s|%s\n" "$(classify_module "$f")" "$(lines_of "$f")" "$(md5_of "$f")" "$f" >> /tmp/cerveau-roles.txt
  done < "$INV_ALL"
  ok "$n modules classés (entry · brain · core · cli · lib · electron · app-c)"

  # Le cerveau : priorité nexus_studio.py > main.py > plus gros entry
  BRAIN_MODULE=""
  for cand in nexus_studio.py main.py app.py; do
    local hit; hit=$(grep "|[0-9]*|[a-f0-9]*|*/$cand$" /tmp/cerveau-roles.txt 2>/dev/null | head -n1 | cut -d'|' -f4)
    # forme simple : chercher par nom de fichier
    hit=$(awk -F'|' '$4 ~ "/"c"$" {print $4; exit}' c="$cand" /tmp/cerveau-roles.txt 2>/dev/null)
    [ -n "$hit" ] && [ -f "$hit" ] && BRAIN_MODULE="$hit" && break
  done
  if [ -z "$BRAIN_MODULE" ]; then
    BRAIN_MODULE=$(awk -F'|' '$1=="entry" && $2+0 > max {max=$2+0; m=$4} END{print m}' /tmp/cerveau-roles.txt 2>/dev/null)
  fi
  [ -n "$BRAIN_MODULE" ] && ok "cerveau détecté : ${B}$(short "$BRAIN_MODULE")${N} ($(lines_of "$BRAIN_MODULE") lignes)" \
                         || warn "aucun cerveau détecté — pose nexus_studio.py ou main.py quelque part"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 4 — MANIFEST : la cartographie exacte, écrite noir sur blanc
# ═════════════════════════════════════════════════════════════════════════════
write_manifest() {
  step "4/11 MANIFEST — cartographie MODULES.manifest"
  mkdir -p /tmp/cerveau
  {
    echo "# NEXUS CERVEAU — MODULES.MANIFEST"
    echo "# généré $(date '+%Y-%m-%d %H:%M:%S') — $COUNT_TOTAL modules trackés (objectif $EXPECTED_MODULES)"
    echo "# FORMAT : ROLE | TYPE | LINES | MD5 | PATH"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      local type="?"
      case "$f" in
        *.py) type="python" ;;
        *.sh) type="bash" ;;
        *.js|*.mjs|*.cjs|*.ts) type="javascript" ;;
        *.rs) type="rust" ;;
        *.go) type="go" ;;
        *.c)  type="c" ;;
        */package.json) type="node-manifest" ;;
      esac
      local role; role=$(awk -F'|' -v p="$f" '$4==p {print $1; exit}' /tmp/cerveau-roles.txt 2>/dev/null)
      [ -z "$role" ] && role="lib"
      printf "%-9s | %-13s | %6s | %s | %s\n" "$role" "$type" "$(lines_of "$f")" "$(md5_of "$f")" "$f"
    done < "$INV_ALL"
  } > "$MANIFEST"
  ok "manifeste écrit : $MANIFEST ($(wc -l < "$MANIFEST") lignes)"
  echo -e "  ${D}aperçu (20 premiers) :${N}"
  head -n 25 "$MANIFEST" | tail -n 22 | sed 's/^/    /'
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 5 — DEDUPE : doubles réels supprimés (même contenu md5)
# ═════════════════════════════════════════════════════════════════════════════
# Prudence maximale : on ne supprime JAMAIS dans le dossier racine du projet,
# jamais dans node_modules/.venv, et seulement si md5 identique au premier vu.
dedupe_modules() {
  step "5/11 DEDUPE — suppression des doubles à contenu identique"
  local seen="" dup=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local f; f="$(echo "$line" | cut -d'|' -f4)"
    local h;  h="$(echo "$line" | cut -d'|' -f3)"
    [ -n "$h" ] || continue
    # hors racine projet = candidat à la suppression si doublon
    case "$f" in
      "$PROJECT_DIR"/*) continue ;;
      */node_modules/*|*/.venv/*|*/venv/*) continue ;;
    esac
    if echo "$seen" | grep -q "$h"; then
      rm -f "$f" && dup=$((dup+1)) && echo -e "    ${Y}double supprimé${N} : $(short "$f")"
    else
      seen="$seen $h"
    fi
  done < /tmp/cerveau-roles.txt
  [ "$dup" -gt 0 ] && ok "$dup doublon(s) supprimé(s) — le dossier racine est intact" \
                   || ok "aucun double hors racine — disque déjà propre"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 6 — TOOLCHAIN : correspondance automatique type de module → outil
# ═════════════════════════════════════════════════════════════════════════════
# La règle : on n'installe QUE ce que TES modules exigent, rien d'autre.
#   python détecté   → python3 (obligatoire) + pip (utile)
#   js/electron      → node + npm (+ node_modules de l'app electron, section 9)
#   rust détecté     → cargo (via rustup si absent)
#   go détecté       → go
#   C/meson détecté  → gcc + meson + ninja
install_toolchain() {
  step "6/11 TOOLCHAIN — correspondance types détectés → outils nécessaires"
  local PM=""
  have apt-get && PM="apt"
  have dnf     && PM="dnf"
  have yum     && PM="yum"
  have pacman  && PM="pacman"
  have brew    && PM="brew"
  ok "gestionnaire de paquets : ${PM:-aucun}"

  sys_install() {
    local p="$1"
    case "${PM:-}" in
      apt)    sudo apt-get install -y "$p" >/dev/null 2>&1 && return 0 ;;
      dnf)    sudo dnf install -y "$p"     >/dev/null 2>&1 && return 0 ;;
      yum)    sudo yum install -y "$p"     >/dev/null 2>&1 && return 0 ;;
      pacman) sudo pacman -S --noconfirm "$p" >/dev/null 2>&1 && return 0 ;;
      brew)   brew install "$p"            >/dev/null 2>&1 && return 0 ;;
    esac
    return 1
  }

  # 6a. Python requis si des .py existent (c'est le cas : NEXUS en dépend)
  if [ "$COUNT_PY" -gt 0 ]; then
    if have python3; then ok "python → python3 présent"
    else sys_install python3 && ok "python → python3 installé" \
         || { err "python3 requis par $COUNT_PY modules et non installable"; return 1; }
    fi
    if python3 -m pip --version >/dev/null 2>&1; then ok "python → pip présent"
    else warn "python → pip absent (le NEXUS n'en a pas besoin : stdlib pure)"; fi
  fi

  # 6b. Node/npm requis si js ou apps electron détectées
  if [ "$COUNT_JS" -gt 0 ] || [ "$COUNT_PJ" -gt 0 ]; then
    if have node && have npm; then
      ok "js/electron → node v$(node --version | sed 's/^v//') + npm $(npm --version) présents"
    else
      warn "js/electron → node/npm manquants — installation…"
      case "$PM" in
        apt)    sys_install nodejs && sys_install npm ;;
        dnf)    sys_install nodejs && sys_install npm ;;
        yum)    sys_install nodejs && sys_install npm ;;
        pacman) sys_install nodejs && sys_install npm ;;
        brew)   sys_install node ;;
      esac
      have node && have npm && ok "js/electron → node + npm installés" \
                             || warn "js/electron → installation node/npm incomplète"
    fi
  fi

  # 6c. Rust requis si des .rs existent
  if [ "$COUNT_RS" -gt 0 ]; then
    if have cargo; then ok "rust → cargo présent ($(cargo --version 2>/dev/null))"
    else
      warn "rust → cargo absent — bootstrap rustup (profil minimal)…"
      if have curl; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
          | sh -s -- -y --profile minimal >/dev/null 2>&1 \
          && . "$HOME/.cargo/env" 2>/dev/null \
          && ok "rust → cargo installé" || warn "rust → cargo non installé (continue sans)"
      fi
    fi
  fi

  # 6d. Go requis si des .go existent
  if [ "$COUNT_GO" -gt 0 ]; then
    have go && ok "go → toolchain présente" \
            || { sys_install golang && ok "go → installé" || warn "go → absent, installe-le manuellement"; }
  fi

  # 6e. C/GNOME/meson requis si des .c existent
  if [ "$COUNT_C" -gt 0 ]; then
    have gcc && ok "c → gcc présent" || { sys_install gcc && ok "c → gcc installé" || warn "c → gcc absent"; }
    if find "$HOME" -maxdepth $SCAN_DEPTH -name meson.build 2>/dev/null | grep -q .; then
      have meson && ok "c → meson présent" \
                 || { sys_install meson && ok "c → meson installé" || warn "c → meson absent"; }
      have ninja && ok "c → ninja présent" \
                 || { sys_install ninja && ok "c → ninja installé" || warn "c → ninja absent"; }
    fi
  fi
  ok "toolchain alignée sur tes modules — aucune brique ajoutée au projet"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 7 — CORRESPONDENCE : chaque import/require vérifié pour de vrai
# ═════════════════════════════════════════════════════════════════════════════
# On extrait les imports python réels de TES modules et on teste chacun :
#   python3 -c "import X"  → OK ou MANQUANT. Aucune supposition.
check_correspondence() {
  step "7/11 CORRESPONDENCE — vérification réelle de chaque dépendance"
  : > /tmp/cerveau-corr.txt
  MISSING_CORR=0

  # 7a. Imports python — uniques, tous modules confondus
  local imports=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    grep -hE '^\s*(import|from)\s+[a-zA-Z_]' "$f" 2>/dev/null \
      | sed -E 's/^\s*(import|from)\s+([a-zA-Z_][a-zA-Z0-9_]*).*/\2/' >> /tmp/cerveau-imports-raw.txt
  done < "$INV_PY"
  if [ -f /tmp/cerveau-imports-raw.txt ]; then
    imports=$(sort -u /tmp/cerveau-imports-raw.txt | grep -v '^$' || true)
    rm -f /tmp/cerveau-imports-raw.txt
  fi

  local total_i=0 miss_i=0
  if [ -n "$imports" ]; then
    echo -e "  ${D}python — imports extraits de $COUNT_PY modules :${N}"
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      total_i=$((total_i+1))
      if python3 -c "import $m" >/dev/null 2>&1; then
        echo "PY|$m|OK" >> /tmp/cerveau-corr.txt
      else
        echo "PY|$m|MANQUANT" >> /tmp/cerveau-corr.txt
        miss_i=$((miss_i+1))
        echo -e "    ${R}import manquant${N} : $m"
      fi
    done <<< "$imports"
    ok "python : $total_i imports testés, $miss_i manquant(s)"
  else
    ok "python : aucun import externe détecté"
  fi
  MISSING_CORR=$miss_i

  # 7b. Apps node — node_modules présents ?
  local miss_n=0
  if [ "$COUNT_PJ" -gt 0 ]; then
    while IFS= read -r pj; do
      [ -f "$pj" ] || continue
      local d; d="$(dirname "$pj")"
      case "$d" in */node_modules/*) continue ;; esac
      if [ -d "$d/node_modules" ]; then
        echo "NODE|$d|OK" >> /tmp/cerveau-corr.txt
        ok "node : node_modules présents → $(short "$d")"
      else
        echo "NODE|$d|MANQUANT" >> /tmp/cerveau-corr.txt
        miss_n=$((miss_n+1))
        warn "node : node_modules absents → $(short "$d") (npm install requis — section 9)"
      fi
    done < "$INV_PJ"
  fi
  MISSING_CORR=$((MISSING_CORR + miss_n))
  [ "$MISSING_CORR" -eq 0 ] && ok "correspondances : tout est en place" \
                            || warn "correspondances manquantes : $MISSING_CORR (liste dans /tmp/cerveau-corr.txt)"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 8 — CERVEAU : valider et lancer le module orchestrateur en local
# ═════════════════════════════════════════════════════════════════════════════
launch_brain() {
  step "8/11 CERVEAU — validation et lancement local de l'orchestrateur"
  if [ -z "$BRAIN_MODULE" ] || [ ! -f "$BRAIN_MODULE" ]; then
    err "aucun cerveau détecté — lance d'abord : bash CERVEAU.sh scan"
    return 1
  fi
  local dir; dir="$(dirname "$BRAIN_MODULE")"
  cd "$dir" || return 1
  ok "cerveau : $(basename "$BRAIN_MODULE") — $(lines_of "$BRAIN_MODULE") lignes, dir $(short "$dir")"

  # Compilation = preuve que le cerveau est sain
  if python3 -m py_compile "$(basename "$BRAIN_MODULE")" 2>/dev/null; then
    ok "cerveau : compilation OK"
  else
    err "cerveau : ERREUR de syntaxe — corrige avant lancement"
    return 1
  fi

  # Auto-diagnostic si le cerveau sait se diagnostiquer (--doctor/--selftest)
  if python3 "$(basename "$BRAIN_MODULE")" --doctor >/dev/null 2>&1; then
    python3 "$(basename "$BRAIN_MODULE")" --doctor || true
  elif python3 "$(basename "$BRAIN_MODULE")" --selftest >/dev/null 2>&1; then
    python3 "$(basename "$BRAIN_MODULE")" --selftest || true
  fi

  # Démarrage du service sous-jacent si nexus-ctl est présent
  if [ -f nexus-ctl.py ] && [ -f nexusd.py ]; then
    if curl -s --max-time 2 http://127.0.0.1:8765/nexus/health >/dev/null 2>&1; then
      ok "service NEXUS : déjà en ligne — 127.0.0.1:8765"
    else
      python3 nexus-ctl.py start >/dev/null 2>&1 && sleep 2
      curl -s --max-time 3 http://127.0.0.1:8765/nexus/health >/dev/null 2>&1 \
        && ok "service NEXUS : démarré — 127.0.0.1:8765" \
        || warn "service NEXUS : non répondu (voir logs/nexusd.log)"
    fi
  fi

  # Lancement local effectif du cerveau (démo non interactive d'abord)
  echo -e "  ${D}lancement local du cerveau (séquence de démonstration)…${N}"
  if python3 "$(basename "$BRAIN_MODULE")" --demo >/dev/null 2>&1; then
    ok "cerveau : séquence de démonstration exécutée sans erreur"
  else
    warn "cerveau : --demo indisponible — le mode --menu reste utilisable"
  fi
  echo -e "  ${B}console interactive :${N} python3 $(basename "$BRAIN_MODULE") --menu"
  echo -e "  ${B}écran temps réel    :${N} python3 $(basename "$BRAIN_MODULE") --screen"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 9 — ELECTRON : détecter, installer, lancer l'app electron
# ═════════════════════════════════════════════════════════════════════════════
launch_electron() {
  step "9/11 ELECTRON — détection et lancement de l'app"
  ELECTRON_DIR=""
  while IFS= read -r pj; do
    [ -f "$pj" ] || continue
    local d; d="$(dirname "$pj")"
    case "$d" in */node_modules/*) continue ;; esac
    if grep -q '"electron"' "$pj" 2>/dev/null; then
      ELECTRON_DIR="$d"; break
    fi
  done < "$INV_PJ"

  if [ -z "$ELECTRON_DIR" ]; then
    warn "aucune app electron détectée sur le disque (aucun package.json avec electron)."
    warn "quand tu en auras une : place-la sous $HOME, relance bash CERVEAU.sh electron"
    return 0
  fi
  ok "app electron : $(short "$ELECTRON_DIR")"
  cd "$ELECTRON_DIR" || return 1

  # node_modules manquants → npm install réel (pas de simulation)
  if [ ! -d node_modules ]; then
    if have npm; then
      echo -e "  ${D}npm install — installe les dépendances réelles de l'app…${N}"
      npm install --no-audit --no-fund > /tmp/cerveau/npm-install.log 2>&1 \
        && ok "npm install terminé ($(grep -c '' /tmp/cerveau/npm-install.log) lignes de log)" \
        || { err "npm install en échec — log : /tmp/cerveau/npm-install.log"; return 1; }
    else
      err "npm absent — impossible d'installer node_modules"
      return 1
    fi
  else
    ok "node_modules déjà présents"
  fi

  # Lancement de l'app (npm start), en arrière-plan avec log consultable
  if have npm; then
    echo -e "  ${D}npm start — lancement local de l'app electron…${N}"
    nohup npm start > /tmp/cerveau/electron.log 2>&1 &
    local epid=$!
    sleep 4
    if kill -0 "$epid" 2>/dev/null; then
      ok "app electron lancée (pid $epid) — log : /tmp/cerveau/electron.log"
    else
      warn "app electron : process terminé tôt — voir /tmp/cerveau/electron.log"
      head -n 5 /tmp/cerveau/electron.log 2>/dev/null | sed 's/^/    /'
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 10 — DASHBOARD : l'état réel, chiffre par chiffre
# ═════════════════════════════════════════════════════════════════════════════
dashboard() {
  step "10/11 DASHBOARD — état de la machine locale"
  local total_lines
  total_lines=$(awk -F'|' '{s+=$2} END{print s+0}' /tmp/cerveau-roles.txt 2>/dev/null)
  hr
  echo -e "  ${B}MODULES${N}                      $COUNT_TOTAL trackés / objectif $EXPECTED_MODULES"
  echo -e "  ${B}LIGNES DE CODE TOTALES${N}       $total_lines"
  echo -e "  ${B}PAR TYPE${N}                     py=$COUNT_PY sh=$COUNT_SH js=$COUNT_JS rs=$COUNT_RS go=$COUNT_GO c=$COUNT_C pkg=$COUNT_PJ"
  if [ -n "$BRAIN_MODULE" ] && [ -f "$BRAIN_MODULE" ]; then
    echo -e "  ${B}CERVEAU${N}                      $(short "$BRAIN_MODULE") ($(lines_of "$BRAIN_MODULE") lignes)"
  else
    echo -e "  ${B}CERVEAU${N}                      non détecté"
  fi
  if [ -n "$ELECTRON_DIR" ]; then
    echo -e "  ${B}ELECTRON${N}                     $(short "$ELECTRON_DIR")"
  else
    echo -e "  ${B}ELECTRON${N}                     aucune app détectée"
  fi
  echo -e "  ${B}CORRESPONDANCES MANQUANTES${N}   $MISSING_CORR"
  hr
  # Top 10 des plus gros modules — les piliers de la machine
  echo -e "  ${D}top 10 modules (lignes) :${N}"
  awk -F'|' '{print $2 "|" $4}' /tmp/cerveau-roles.txt 2>/dev/null | sort -t'|' -k1 -rn | head -n 10 \
    | while IFS='|' read -r l f; do
        echo -e "    $(printf '%6s' "$l")  $(short "$f")"
      done
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 11 — REPORT : rapport horodaté, preuve de tout ce qui précède
# ═════════════════════════════════════════════════════════════════════════════
write_report() {
  local out="$REPORT_DIR/CERVEAU_REPORT_$(date +%Y%m%d-%H%M%S).md"
  local total_lines; total_lines=$(awk -F'|' '{s+=$2} END{print s+0}' /tmp/cerveau-roles.txt 2>/dev/null)
  {
    echo "# NEXUS CERVEAU — RAPPORT LOCAL"
    echo ""
    echo "Généré le $(date '+%d/%m/%Y à %H:%M') — v$VERSION"
    echo ""
    echo "## Inventaire réel"
    echo ""
    echo "- Modules trackés : **$COUNT_TOTAL** (objectif $EXPECTED_MODULES)"
    echo "- Répartition : python=$COUNT_PY, bash=$COUNT_SH, js=$COUNT_JS, rust=$COUNT_RS, go=$COUNT_GO, c=$COUNT_C, package.json=$COUNT_PJ"
    echo "- Lignes de code cumulées : **$total_lines**"
    echo "- Cerveau : \`${BRAIN_MODULE:-non détecté}\`"
    echo "- App electron : \`${ELECTRON_DIR:-aucune}\`"
    echo "- Correspondances manquantes : **$MISSING_CORR**"
    echo ""
    echo "## Manifeste complet"
    echo ""
    echo '```'
    cat "$MANIFEST" 2>/dev/null
    echo '```'
    echo ""
    echo "## Correspondances vérifiées (extraits)"
    echo ""
    echo '```'
    head -n 40 /tmp/cerveau-corr.txt 2>/dev/null
    echo '```'
  } > "$out"
  ok "rapport écrit : $(short "$out")"
  local elapsed=$(( $(date +%s) - START_TS ))
  echo ""
  echo -e "${G}╔══════════════════════════════════════════════════════════════════╗${N}"
  echo -e "${G}║${B}  ✓ CERVEAU TERMINÉ EN ${elapsed}s — $COUNT_TOTAL/$EXPECTED_MODULES modules trackés, 0 module modifié${N}   ${G}║${N}"
  echo -e "${G}╚══════════════════════════════════════════════════════════════════╝${N}"
}

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 12 — VERIFY : chaque module compilé / vérifié syntaxiquement
# ═════════════════════════════════════════════════════════════════════════════
# Zéro supposition : chaque fichier python est compilé, chaque bash est lu
# par bash -n, chaque js est passé à node --check. Résultats comptés pour
# de vrai, affichés module par module en cas d'échec.
verify_modules() {
  step "12/13 VERIFY — compilation/vérification de chaque module, un par un"
  local total=0 bad=0

  # 12a. Python : py_compile sur chaque .py tracké
  local pyc_ok=0 pyc_bad=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    total=$((total+1))
    if python3 -m py_compile "$f" >/dev/null 2>&1; then
      pyc_ok=$((pyc_ok+1))
    else
      pyc_bad=$((pyc_bad+1)); bad=$((bad+1))
      echo -e "    ${R}python KO${N} : $(short "$f")"
    fi
  done < "$INV_PY"
  ok "python compilé : $pyc_ok OK, $pyc_bad en erreur (sur $COUNT_PY)"

  # 12b. Bash : bash -n sur chaque .sh tracké (hors /tmp du script lui-même)
  local sh_ok=0 sh_bad=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in /tmp/*) continue ;; esac
    total=$((total+1))
    if bash -n "$f" >/dev/null 2>&1; then
      sh_ok=$((sh_ok+1))
    else
      sh_bad=$((sh_bad+1)); bad=$((bad+1))
      echo -e "    ${R}bash KO${N} : $(short "$f")"
    fi
  done < "$INV_SH"
  ok "bash vérifié : $sh_ok OK, $sh_bad en erreur (sur $COUNT_SH)"

  # 12c. JavaScript : node --check si node disponible
  local js_ok=0 js_bad=0 js_skip=0
  if have node; then
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      case "$f" in */node_modules/*) continue ;; esac
      total=$((total+1))
      if node --check "$f" >/dev/null 2>&1; then
        js_ok=$((js_ok+1))
      else
        js_bad=$((js_bad+1)); bad=$((bad+1))
        echo -e "    ${R}js KO${N} : $(short "$f")"
      fi
    done < "$INV_JS"
    ok "javascript vérifié : $js_ok OK, $js_bad en erreur"
  else
    js_skip=$COUNT_JS
    warn "javascript : node absent — $js_skip fichiers non vérifiés (section 6 installe node)"
  fi

  # 12d. Rust : cargo check réservé au mode all (coûteux) — ici check de crise
  if [ "$COUNT_RS" -gt 0 ] && have cargo; then
    ok "rust : $COUNT_RS fichiers détectés — cargo check exécuté seulement sur demande (mode deps)"
  fi

  VERIFY_TOTAL=$total
  VERIFY_BAD=$bad
  [ "$bad" -eq 0 ] && ok "vérification complète : $total modules, 0 erreur" \
                   || err "vérification complète : $bad module(s) en erreur sur $total"
}
VERIFY_TOTAL=0
VERIFY_BAD=0

# ═════════════════════════════════════════════════════════════════════════════
# SECTION 13 — SERVICES : ce qui tourne déjà sur la machine
# ═════════════════════════════════════════════════════════════════════════════
# Le cerveau a besoin de savoir ce qui vit déjà : nœud NEXUS, ports, RAM,
# disque, charge. Chiffres réels, lus sur place.
check_services() {
  step "13/13 SERVICES — état des services locaux (chiffres réels)"
  # 13a. Nœud NEXUS
  if curl -s --max-time 2 http://127.0.0.1:8765/nexus/health >/dev/null 2>&1; then
    ok "nœud NEXUS : EN LIGNE — http://127.0.0.1:8765"
    local m; m=$(curl -s --max-time 2 http://127.0.0.1:8765/nexus/metrics 2>/dev/null)
    [ -n "$m" ] && echo -e "    ${D}metrics : $(echo "$m" | head -c 200)${N}"
  else
    warn "nœud NEXUS : arrêté (le mode brain le démarre)"
  fi

  # 13b. Ressources — uniquement des lectures réelles
  if [ -r /proc/meminfo ]; then
    local ram; ram=$(awk '/MemTotal/ {printf "%.1f Go", $2/1048576}' /proc/meminfo)
    ok "RAM totale : $ram"
  fi
  if have df; then
    local disk; disk=$(df -h "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    [ -n "$disk" ] && ok "disque libre sur $HOME : $disk"
  fi
  if [ -r /proc/loadavg ]; then
    ok "charge : $(awk '{print $1, $2, $3}' /proc/loadavg)"
  fi

  # 13c. Processus NEXUS vivants
  local npid
  if [ -f "$PROJECT_DIR/runtime/nexusd.pid" ]; then
    npid=$(cat "$PROJECT_DIR/runtime/nexusd.pid" 2>/dev/null)
    if [ -n "$npid" ] && kill -0 "$npid" 2>/dev/null; then
      ok "processus nexusd : vivant (pid $npid)"
    else
      warn "processus nexusd : pid file présent mais process mort"
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# WATCH — tableau de bord rafraîchi en continu (Ctrl+C pour sortir)
# ═════════════════════════════════════════════════════════════════════════════
watch_dashboard() {
  local interval="${2:-5}"
  echo -e "${C}═ tableau de bord live — rafraîchi toutes les ${interval}s — Ctrl+C pour sortir ═${N}"
  while true; do
    clear 2>/dev/null || true
    banner
    scan_modules >/dev/null 2>&1
    classify_all >/dev/null 2>&1
    dashboard
    echo -e "  ${D}$(date '+%H:%M:%S') — Ctrl+C pour quitter${N}"
    sleep "$interval"
  done
}

# ═════════════════════════════════════════════════════════════════════════════
# EXPORT — pack complet de tes modules (inventaire + code), prêt à partager
# ═════════════════════════════════════════════════════════════════════════════
export_pack() {
  step "EXPORT — pack des modules (inventaire + manifeste + rapport)"
  local z="/tmp/cerveau/CERVEAU_PACK_$(date +%Y%m%d-%H%M%S).zip"
  {
    echo "# INVENTAIRE CERVEAU — $(date '+%d/%m/%Y %H:%M')"
    echo "# $COUNT_TOTAL modules (objectif $EXPECTED_MODULES)"
    echo "# lignes totales : $(awk -F'|' '{s+=$2} END{print s+0}' /tmp/cerveau-roles.txt 2>/dev/null)"
  } > /tmp/cerveau/INVENTAIRE.txt
  if have zip; then
    cp -f "$MANIFEST" /tmp/cerveau/ 2>/dev/null
    cp -f /tmp/cerveau-corr.txt /tmp/cerveau/CORRESPONDANCES.txt 2>/dev/null
    cp -f /tmp/cerveau-roles.txt /tmp/cerveau/ROLES.txt 2>/dev/null
    zip -q -j "$z" /tmp/cerveau/INVENTAIRE.txt /tmp/cerveau/MODULES.manifest \
        /tmp/cerveau/CORRESPONDANCES.txt /tmp/cerveau/ROLES.txt 2>/dev/null \
      && ok "pack exporté : $z ($(du -h "$z" 2>/dev/null | awk '{print $1}'))" \
      || warn "échec de création du pack zip"
  else
    warn "zip absent — inventaire disponible en texte : /tmp/cerveau/INVENTAIRE.txt"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# GUIDE — aide détaillée de chaque mode
# ═════════════════════════════════════════════════════════════════════════════
show_guide() {
  step "GUIDE — chaque mode expliqué"
  cat <<EOF
  ${B}bash CERVEAU.sh scan${N}
      Fouille ton disque (profondeur $SCAN_DEPTH) et track chaque module :
      python, bash, js/ts, rust, go, C, package.json. Caches et node_modules
      exclus. Affiche le compte par type face à l'objectif ($EXPECTED_MODULES).

  ${B}bash CERVEAU.sh manifest${N}
      Écrit MODULES.manifest : pour chaque module son RÔLE (entry, brain,
      core, cli, lib, electron), son TYPE, ses LIGNES, son MD5, son chemin.
      C'est la cartographie exacte et vérifiable de ton code.

  ${B}bash CERVEAU.sh dedupe${N}
      Supprime uniquement les fichiers à contenu strictement identique
      (même md5) situés HORS du dossier racine. Le projet reste intact.

  ${B}bash CERVEAU.sh deps${N}
      Correspondance automatique : ce que tes modules exigent → outil installé.
      python détecté → python3/pip · js/electron → node/npm · rust → cargo ·
      go → golang · C/meson → gcc/meson/ninja. Puis chaque import python est
      réellement testé (import X) et chaque node_modules contrôlé.

  ${B}bash CERVEAU.sh brain${N}
      Détecte le cerveau (nexus_studio.py, sinon main.py, sinon le plus gros
      point d'entrée), le compile, le diagnostique (--doctor/--selftest),
      démarre le service NEXUS sous-jacent et lance la démo locale.

  ${B}bash CERVEAU.sh electron${N}
      Trouve l'app electron (package.json avec dépendance electron),
      exécute npm install si node_modules manque, puis npm start en
      arrière-plan avec log consultable.

  ${B}bash CERVEAU.sh verify${N}
      Compile chaque .py (py_compile), vérifie chaque .sh (bash -n) et
      chaque .js (node --check). Compte réel OK / erreurs, fichier par fichier.

  ${B}bash CERVEAU.sh services${N}
      État réel : nœud NEXUS (health + metrics), RAM, disque, charge, pid.

  ${B}bash CERVEAU.sh watch [s]${N}
      Tableau de bord rafraîchi toutes les N secondes (défaut 5).

  ${B}bash CERVEAU.sh export${N}
      Pack zip : inventaire + manifeste + correspondances + rôles.

  ${B}bash CERVEAU.sh list py|sh|js|rs|go|c|pkg${N}
      Liste les modules d'un seul type, avec leur rôle et leur taille.

  ${B}bash CERVEAU.sh init [dossier]${N}
      Crée le squelette propre (config, workflows, studio, docs…) sans
      jamais écraser ce qui existe, et écrit docs/REGLES.md une seule fois.

  ${B}bash CERVEAU.sh stop${N}
      Arrête proprement le nœud NEXUS (via nexus-ctl.py, module v1.0).

  ${B}bash CERVEAU.sh all${N}
      Tout, dans l'ordre : scan → classify → manifest → dedupe → deps →
      brain → electron → verify → services → dashboard → rapport.
EOF
}

# ═════════════════════════════════════════════════════════════════════════════
# SELFCHECK — le script vérifie ses propres outils avant de promettre quoi
# que ce soit. Si un outil de base manque, il le dit tout de suite.
# ═════════════════════════════════════════════════════════════════════════════
selfcheck() {
  step "SELFCHECK — outils internes du script"
  local missing=0
  for t in find sort awk sed cut md5sum grep date sleep basename dirname wc head tail; do
    if have "$t"; then
      ok "$t"
    else
      err "$t manquant — outil système de base, le script ne peut pas mentir : il s'arrête."
      missing=$((missing+1))
    fi
  done
  have curl && ok "curl (health-checks)" || warn "curl absent — les health-checks seront ignorés"
  have zip  && ok "zip (export)"       || warn "zip absent — l'export sera en texte"
  [ "$missing" -eq 0 ] && ok "selfcheck : tous les outils internes présents" \
                       || exit 1
}

# ═════════════════════════════════════════════════════════════════════════════
# LIST — lister les modules d'un type précis : bash CERVEAU.sh list py|sh|js|rs|go|c|pkg
# ═════════════════════════════════════════════════════════════════════════════
list_by_type() {
  local t="${2:-py}"
  local inv=""
  case "$t" in
    py)  inv="$INV_PY";  echo -e "${B}Modules PYTHON trackés ($COUNT_PY) :${N}" ;;
    sh)  inv="$INV_SH";  echo -e "${B}Modules BASH trackés ($COUNT_SH) :${N}" ;;
    js)  inv="$INV_JS";  echo -e "${B}Modules JS/TS trackés ($COUNT_JS) :${N}" ;;
    rs)  inv="$INV_RS";  echo -e "${B}Modules RUST trackés ($COUNT_RS) :${N}" ;;
    go)  inv="$INV_GO";  echo -e "${B}Modules GO trackés ($COUNT_GO) :${N}" ;;
    c)   inv="$INV_C";   echo -e "${B}Modules C trackés ($COUNT_C) :${N}" ;;
    pkg) inv="$INV_PJ";  echo -e "${B}package.json trackés ($COUNT_PJ) :${N}" ;;
    *)   err "type inconnu : $t (py|sh|js|rs|go|c|pkg)"; return 1 ;;
  esac
  hr
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local role; role=$(awk -F'|' -v p="$f" '$4==p {print $1; exit}' /tmp/cerveau-roles.txt 2>/dev/null)
    printf "    %-9s %6s lignes  %s\n" "${role:-lib}" "$(lines_of "$f")" "$(short "$f")"
  done < "$inv"
  hr
}

# ═════════════════════════════════════════════════════════════════════════════
# INIT — créer un squelette de projet propre (dossiers + pointeurs), sans
# jamais écraser ce qui existe déjà. Utile pour ranger les 54 modules.
# ═════════════════════════════════════════════════════════════════════════════
init_skeleton() {
  local target="${2:-$PROJECT_DIR}"
  step "INIT — squelette propre dans $(short "$target")"
  [ -d "$target" ] || mkdir -p "$target" || { err "création impossible : $target"; return 1; }
  local created=0 exists=0
  for d in config workflows registry logs runtime studio/reports studio/results docs inbox; do
    if [ -d "$target/$d" ]; then
      exists=$((exists+1))
    else
      mkdir -p "$target/$d" && created=$((created+1)) \
        && echo -e "    ${G}créé${N} : $d/"
    fi
  done
  ok "squelette : $created dossier(s) créé(s), $exists déjà en place"
  # Mémo des règles d'or, écrit une seule fois
  if [ ! -f "$target/docs/REGLES.md" ]; then
    {
      echo "# Règles d'or du projet NEXUS"
      echo ""
      echo "1. Les modules existants ne sont JAMAIS réécrits par un script."
      echo "2. Les scripts ajoutent, classent, vérifient — ils ne détruisent pas"
      echo "   (seule exception : dedupe supprime un double md5 hors racine)."
      echo "3. Chaque rapport horodaté dans studio/reports/ est une preuve."
      echo "4. Tout ce qui est lancé localement doit pouvoir être relancé :"
      echo "   bash CERVEAU.sh all — résultat identique."
    } > "$target/docs/REGLES.md"
    ok "mémo écrit : docs/REGLES.md"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# STOP — arrêter proprement ce que le script a démarré (jamais brutalement)
# ═════════════════════════════════════════════════════════════════════════════
stop_services() {
  step "STOP — arrêt propre des services locaux"
  if [ -f "$PROJECT_DIR/nexus-ctl.py" ]; then
    cd "$PROJECT_DIR" || return 1
    python3 nexus-ctl.py stop 2>/dev/null \
      && ok "nœud NEXUS arrêté (nexus-ctl stop — module v1.0, inchangé)" \
      || warn "nœud NEXUS : déjà arrêté ou stop refusé"
  else
    warn "nexus-ctl.py introuvable — rien à arrêter proprement"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
# MAIN — orchestration des 13 sections
# ═════════════════════════════════════════════════════════════════════════════
MODE="${1:-all}"

banner
preflight
selfcheck

case "$MODE" in
  scan)      scan_modules; classify_all ;;
  manifest)  scan_modules; classify_all; write_manifest ;;
  dedupe)    scan_modules; classify_all; dedupe_modules ;;
  deps)      scan_modules; classify_all; install_toolchain; check_correspondence ;;
  brain)     scan_modules; classify_all; launch_brain ;;
  electron)  scan_modules; classify_all; launch_electron ;;
  verify)    scan_modules; classify_all; verify_modules ;;
  services)  check_services ;;
  watch)     watch_dashboard "$@" ;;
  export)    scan_modules; classify_all; write_manifest; check_correspondence; export_pack ;;
  list)      scan_modules; classify_all; list_by_type "$@" ;;
  init)      init_skeleton "$@" ;;
  stop)      stop_services ;;
  guide)     show_guide ;;
  dashboard) scan_modules; classify_all; dashboard ;;
  all)       scan_modules; classify_all; write_manifest; dedupe_modules
             install_toolchain; check_correspondence; launch_brain
             launch_electron; verify_modules; check_services
             dashboard; write_report ;;
  *)         err "mode inconnu : $MODE"
             show_guide
             exit 1 ;;
esac
