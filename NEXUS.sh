#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
#   N E X U S . s h  —  LE SEUL ET UNIQUE SCRIPT. IL FAIT TOUT.
# ═════════════════════════════════════════════════════════════════════════════
#
#   bash NEXUS.sh            → TOUT, dans l'ordre : installe · déploie ·
#                              nettoie les doubles · classe · lance le Studio
#   bash NEXUS.sh clean      → seulement nettoyer (doubles, cache, temporaires)
#   bash NEXUS.sh class      → seulement classer les fichiers
#   bash NEXUS.sh demo       → seulement lancer la démo
#
#   RÈGLES D'OR (gravées) :
#     • Les 4 modules v1.0 (nexusd.py, nexus-ctl.py, nexus-smi.py,
#       nexus-bench.py) ne sont JAMAIS modifiés ni déplacés.
#     • Aucune nouvelle brique : on n'installe que des OUTILS système.
#     • Le script peut être relancé autant de fois : résultat identique
#       (idempotent), jamais de doublon créé par lui-même.
# ═════════════════════════════════════════════════════════════════════════════
set -u

# ── Couleurs ─────────────────────────────────────────────────────────────────
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[1m'; P='\033[0;35m'; D='\033[0;90m'; N='\033[0m'
ok()   { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}!${N} $*"; }
err()  { echo -e "  ${R}✗${N} $*" >&2; }
hr()   { echo -e "${C}────────────────────────────────────────────────────────────${N}"; }

PROJECT_DIR="${NEXUS_PROJECT_DIR:-$(pwd)}"
PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
ARCHIVE_NAME="nexus-edge-studio-v1.1.zip"
V1_MODULES=(nexusd.py nexus-ctl.py nexus-smi.py nexus-bench.py)
MODE="${1:-all}"

# ═════════════════════════════════════════════════════════════════════════════
#  ÉTAPE 1 — INSTALLER  (outils système, jamais de brique dans le projet)
# ═════════════════════════════════════════════════════════════════════════════
install_tools() {
  echo -e "${P}[1/5] INSTALLER — outils système${N}"; hr
  # Gestionnaire de paquets
  local PM_INSTALL=""
  if   command -v apt-get >/dev/null 2>&1; then PM_INSTALL="sudo apt-get install -y"
  elif command -v dnf     >/dev/null 2>&1; then PM_INSTALL="sudo dnf install -y"
  elif command -v yum     >/dev/null 2>&1; then PM_INSTALL="sudo yum install -y"
  elif command -v pacman  >/dev/null 2>&1; then PM_INSTALL="sudo pacman -S --noconfirm"
  elif command -v brew    >/dev/null 2>&1; then PM_INSTALL="brew install"
  fi
  # python3 — obligatoire
  if command -v python3 >/dev/null 2>&1; then
    ok "python3 : $(python3 --version 2>&1)"
  else
    [ -n "$PM_INSTALL" ] && $PM_INSTALL python3 >/dev/null 2>&1 && ok "python3 installé" \
      || { err "python3 introuvable et aucun gestionnaire — installe-le puis relance."; exit 1; }
  fi
  # unzip / zip / curl — utiles
  for t in unzip zip curl; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t : présent"
    elif [ -n "$PM_INSTALL" ]; then $PM_INSTALL "$t" >/dev/null 2>&1 && ok "$t installé" || warn "$t non installé (peut être bloquant pour l'archive)."
    else warn "$t manquant — installe-le si besoin."; fi
  done
  # pip — utile, jamais requis
  if python3 -m pip --version >/dev/null 2>&1; then ok "pip : présent"
  else warn "pip absent — pas grave, le Studio n'utilise QUE la stdlib Python."; fi
  # cargo / npm — seulement si tu les demandes explicitement
  if [ "${NEXUS_BOOTSTRAP_CARGO:-0}" = "1" ]; then
    command -v cargo >/dev/null 2>&1 && ok "cargo : présent" || warn "cargo absent — installe rustup si besoin."
  fi
  if [ "${NEXUS_BOOTSTRAP_NPM:-0}" = "1" ]; then
    command -v npm >/dev/null 2>&1 && ok "npm : présent" || warn "npm absent — installe nodejs si besoin."
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  ÉTAPE 2 — DÉPLOYER  (trouver le projet, extraire l'archive, vérifier v1.0)
# ═════════════════════════════════════════════════════════════════════════════
deploy() {
  echo -e "${P}[2/5] DÉPLOYER — localiser, extraire, vérifier${N}"; hr

  # Auto-détection du dossier projet (cwd, ~/Projects/cdn, ~/nexus-edge, recherche)
  if [ ! -f "$PROJECT_DIR/nexusd.py" ]; then
    for c in "$HOME/Projects/cdn" "$HOME/nexus-edge" "$HOME/projects/cdn"; do
      [ -f "$c/nexusd.py" ] && PROJECT_DIR="$c" && break
    done
  fi
  if [ ! -f "$PROJECT_DIR/nexusd.py" ]; then
    local f; f=$(find "$HOME" -maxdepth 4 -type f -name nexusd.py 2>/dev/null | head -n1)
    [ -n "$f" ] && PROJECT_DIR="$(dirname "$f")"
  fi
  if [ ! -d "$PROJECT_DIR" ]; then
    read -rp "Chemin de ton projet NEXUS (ex: ~/Projects/cdn) : " PROJECT_DIR
    PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
  fi
  [ -d "$PROJECT_DIR" ] || { err "Dossier introuvable : $PROJECT_DIR"; exit 1; }
  cd "$PROJECT_DIR" || exit 1
  ok "Projet : $PROJECT_DIR"

  # Extraire l'archive si elle existe ET si le Studio manque
  if [ ! -f nexus_studio.py ] && [ -f "$ARCHIVE_NAME" ]; then
    unzip -o -q "$ARCHIVE_NAME" -d . && ok "Archive extraite : $ARCHIVE_NAME"
  elif [ -f nexus_studio.py ]; then
    ok "Studio déjà en place (nexus_studio.py)"
  elif [ -f "$HOME/Téléchargements/$ARCHIVE_NAME" ]; then
    unzip -o -q "$HOME/Téléchargements/$ARCHIVE_NAME" -d . && ok "Archive extraite depuis Téléchargements"
  elif [ -f "$HOME/Downloads/$ARCHIVE_NAME" ]; then
    unzip -o -q "$HOME/Downloads/$ARCHIVE_NAME" -d . && ok "Archive extraite depuis Downloads"
  else
    err "Ni nexus_studio.py ni $ARCHIVE_NAME trouvés."
    exit 1
  fi

  # Vérifier les modules v1.0 — s'il en manque un, ON S'ARRÊTE (jamais les refaire)
  local miss=0
  for m in "${V1_MODULES[@]}"; do
    [ -f "$m" ] && ok "v1.0 : $m intact" || { err "v1.0 : $m MANQUANT"; miss=$((miss+1)); }
  done
  [ -f config/nexus.json ] && ok "v1.0 : config/nexus.json intact" || { err "config/nexus.json MANQUANT"; miss=$((miss+1)); }
  [ "$miss" -eq 0 ] || { err "Modules v1.0 incomplets — arrêt (règle d'or : on ne les reconstruit pas)."; exit 1; }
  [ -f run_studio_demo.sh ] && chmod +x run_studio_demo.sh 2>/dev/null
}

# ═════════════════════════════════════════════════════════════════════════════
#  ÉTAPE 3 — NETTOYER  (doubles, caches, temporaires, zip en trop)
# ═════════════════════════════════════════════════════════════════════════════
clean() {
  echo -e "${P}[3/5] NETTOYER — doubles · caches · temporaires${N}"; hr
  local removed=0

  # 3.1 Caches Python et temporaires
  find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null && ok "__pycache__ supprimés" || true
  find . -type f \( -name "*.pyc" -o -name "*.tmp" -o -name "*.swp" -o -name "*~" -o -name ".DS_Store" \) -delete 2>/dev/null

  # 3.2 Doubles PAR CONTENU (md5) — on garde le premier, on supprime les copies
  local seen=""; local dup=0
  while IFS= read -r f; do
    local h; h=$(md5sum "$f" 2>/dev/null | awk '{print $1}')
    if echo "$seen" | grep -q "^$h$"; then
      rm -f "$f"; dup=$((dup+1)); echo -e "    ${Y}double supprimé${N} : $f"
    else
      seen="${seen}${h}\n"
    fi
  done < <(find studio/reports -type f -size +0 2>/dev/null)
  [ "$dup" -gt 0 ] && ok "$dup doublon(s) de rapport supprimé(s)" || ok "studio/reports : aucun doublon"

  # 3.3 Doubles de workflows (contenu identique, noms différents)
  dup=0; seen=""
  while IFS= read -r f; do
    local h; h=$(md5sum "$f" 2>/dev/null | awk '{print $1}')
    if echo "$seen" | grep -q "^$h$"; then
      rm -f "$f"; dup=$((dup+1)); echo -e "    ${Y}double supprimé${N} : $f"
    else
      seen="${seen}${h}\n"
    fi
  done < <(find workflows -type f -name "*.json" 2>/dev/null)
  [ "$dup" -gt 0 ] && ok "$dup doublon(s) de workflow supprimé(s)" || ok "workflows : aucun doublon"

  # 3.4 Archives zip en double (on garde la dernière version)
  local zc; zc=$(ls -1 nexus-edge-studio-v*.zip 2>/dev/null | wc -l)
  if [ "$zc" -gt 1 ]; then
    ls -1t nexus-edge-studio-v*.zip | tail -n +2 | while read -r z; do rm -f "$z"; echo -e "    ${Y}ancienne archive supprimée${N} : $z"; done
    ok "Archives : seule la plus récente conservée"
  else
    ok "Archives : aucune redondance"
  fi
  ok "Nettoyage terminé."
}

# ═════════════════════════════════════════════════════════════════════════════
#  ÉTAPE 4 — CLASSER  (chaque chose à sa place, les v1.0 ne bougent JAMAIS)
# ═════════════════════════════════════════════════════════════════════════════
classify() {
  echo -e "${P}[4/5] CLASSER — une place pour chaque fichier${N}"; hr
  mkdir -p studio/reports studio/results logs docs
  # Ce qui ne doit JAMAIS bouger :
  #   nexusd.py nexus-ctl.py nexus-smi.py nexus-bench.py nexus_studio.py
  #   run_studio_demo.sh run_demo.sh config/ workflows/ registry/ runtime/
  # On classe uniquement les documents éparpillés à la racine.
  for f in README*.md *.txt NOTES.md CHANGELOG*; do
    [ -f "$f" ] || continue
    case "$f" in
      README.md|README-STUDIO.md) mv -f "$f" docs/ 2>/dev/null && echo -e "    docs/ ← $f" ;;
      *) mv -f "$f" docs/ 2>/dev/null && echo -e "    docs/ ← $f" ;;
    esac
  done
  # Les images/captures éventuelles → docs/
  find . -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -exec mv -f {} docs/ \; 2>/dev/null
  ok "Racine propre : modules v1.0 + Studio + dossiers, rien d'autre."
  echo -e "    ${D}racine : nexusd.py · nexus-ctl.py · nexus-smi.py · nexus-bench.py ·"
  echo -e "            nexus_studio.py · run_studio_demo.sh · config/ · workflows/"
  echo -e "            registry/ · runtime/ · logs/ · studio/ · docs/${N}"
}

# ═════════════════════════════════════════════════════════════════════════════
#  ÉTAPE 5 — LANCER  (le Studio, écran temps réel, 400 actions)
# ═════════════════════════════════════════════════════════════════════════════
launch() {
  echo -e "${P}[5/5] LANCER — NEXUS STUDIO v1.1${N}"; hr
  if [ -f run_studio_demo.sh ]; then
    bash run_studio_demo.sh
  else
    python3 nexus_studio.py --doctor && python3 nexus_studio.py --demo
  fi
}

# ═════════════════════════════════════════════════════════════════════════════
#  MAIN
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║${B}   NEXUS . sh — UN SEUL SCRIPT POUR TOUT${C}                        ║${N}"
echo -e "${C}║${N}   installer · déployer · nettoyer les doubles · classer · lancer${C} ║${N}"
echo -e "${C}╚════════════════════════════════════════════════════════════╝${N}"

case "$MODE" in
  clean)  cd "$PROJECT_DIR" 2>/dev/null; clean ;;
  class)  cd "$PROJECT_DIR" 2>/dev/null; classify ;;
  demo)   cd "$PROJECT_DIR" 2>/dev/null; launch ;;
  all)    install_tools; deploy; clean; classify; launch ;;
  *)      err "Mode inconnu : $MODE (utilise all | clean | class | demo)"; exit 1 ;;
esac
