#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# NEXUS EDGE PLATFORM — Démo complète en une commande
# Démarre le nœud, préchauffe le cache, prouve la latence, affiche le moniteur
# Usage : bash run_demo.sh
# ═══════════════════════════════════════════════════════════════════════════
cd "$(dirname "$0")" || exit 1

echo ""
echo -e "\033[0;36m═══════════════════════════════════════════════════════════════\033[0m"
echo -e "\033[0;36m  NEXUS EDGE PLATFORM — DÉMO COMPLÈTE\033[0m"
echo -e "\033[0;36m═══════════════════════════════════════════════════════════════\033[0m"

echo -e "\n\033[1;33m[1/4] Démarrage du nœud Edge (nexusd)…\033[0m"
python3 nexus-ctl.py start || exit 1

echo -e "\n\033[1;33m[2/4] Préchauffage du cache (warm-up)…\033[0m"
python3 nexus-ctl.py warm /npm/jquery@3.7.1/dist/jquery.min.js

echo -e "\n\033[1;33m[3/4] Preuve de latence (Edge vs Origine)…\033[0m"
python3 nexus-ctl.py bench --samples 30 || true

echo -e "\n\033[1;33m[4/4] Moniteur NEXUS-SMI (instantané)…\033[0m"
python3 nexus-smi.py

echo ""
echo -e "\033[0;36m  Pour le monitoring continu : python3 nexus-smi.py --watch 2\033[0m"
echo -e "\033[0;36m  Pour arrêter le nœud      : python3 nexus-ctl.py stop\033[0m"
echo -e "\033[0;36m═══════════════════════════════════════════════════════════════\033[0m"
