#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
════════════════════════════════════════════════════════════════════════════
 NEXUS-CTL v1.0 — Plan de contrôle (mini-orchestrateur de nœuds Edge)

 Commandes :
   start   [--config config/nexus.json]   Démarre un nœud + l'enregistre
   stop    [nom|all]                      Arrête un nœud (shutdown propre)
   list                                   Statut de tous les nœuds du registre
   warm    <chemin>                       Préchauffe un chemin sur le nœud par défaut
   bench   [--samples N] [--path P]       Preuve de latence Edge vs Origine

 Exemples :
   python3 nexus-ctl.py start
   python3 nexus-ctl.py list
   python3 nexus-ctl.py warm /npm/jquery@3.7.1/dist/jquery.min.js
   python3 nexus-ctl.py bench --samples 30
   python3 nexus-ctl.py stop node-local-01
════════════════════════════════════════════════════════════════════════════
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request

VERSION = "nexus-ctl/1.0.0"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
REGISTRY = os.path.join(BASE_DIR, "registry", "nodes.json")
CONFIG = os.path.join(BASE_DIR, "config", "nexus.json")

GREEN = "\033[0;32m"; RED = "\033[0;31m"; YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"; BOLD = "\033[1m"; DIM = "\033[2m"; NC = "\033[0m"


def load_registry():
    if not os.path.exists(REGISTRY):
        return []
    try:
        with open(REGISTRY, "r", encoding="utf-8") as f:
            return json.load(f).get("nodes", [])
    except (OSError, ValueError):
        return []


def save_registry(nodes):
    os.makedirs(os.path.dirname(REGISTRY), exist_ok=True)
    tmp = REGISTRY + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"nodes": nodes}, f, indent=2)
    os.replace(tmp, REGISTRY)


def read_node_config(path=CONFIG):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def node_url_from_config(cfg):
    n = cfg["node"]
    return "http://%s:%d" % (n["host"], n["port"])


def wait_health(url, timeout=6.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url.rstrip("/") + "/nexus/health", timeout=1.0) as r:
                if r.status == 200:
                    return True
        except Exception:  # noqa: BLE001
            time.sleep(0.2)
    return False


def cmd_start(args):
    cfg = read_node_config(args.config)
    url = node_url_from_config(cfg)
    name = cfg["node"]["name"]

    # Déjà en ligne ?
    if wait_health(url, timeout=0.6):
        print("%s⚠ Un nœud répond déjà sur %s — rien à faire.%s" % (YELLOW, url, NC))
        return 0

    log_path = os.path.join(BASE_DIR, "logs", "nexusd-boot.log")
    logf = open(log_path, "ab")
    proc = subprocess.Popen(
        [sys.executable, os.path.join(BASE_DIR, "nexusd.py"), "--config", args.config],
        stdout=logf, stderr=subprocess.STDOUT, start_new_session=True, cwd=BASE_DIR,
    )
    if not wait_health(url):
        print("%s❌ Le nœud n'a pas répondu — regarde %s%s" % (RED, log_path, NC))
        return 1

    nodes = [n for n in load_registry() if n["url"] != url]
    nodes.append({"name": name, "url": url, "region": cfg["node"].get("region", "local"),
                  "pid": proc.pid, "started": time.strftime("%Y-%m-%d %H:%M:%S")})
    save_registry(nodes)
    print("%s✅ Nœud « %s » en ligne sur %s (pid %d)%s" % (GREEN, name, url, proc.pid, NC))
    print("   registre : %s" % os.path.relpath(REGISTRY, BASE_DIR))
    print("   essai    : curl %s/nexus/health" % url)
    return 0


def cmd_stop(args):
    nodes = load_registry()
    if not nodes:
        print("Registre vide — rien à arrêter.")
        return 0
    targets = nodes
    if args.name and args.name not in ("all",):
        targets = [n for n in nodes if n["name"] == args.name]
        if not targets:
            print("%s❌ Nœud « %s » introuvable dans le registre.%s" % (RED, args.name, NC))
            return 1
    remaining = list(nodes)
    for n in targets:
        try:
            urllib.request.urlopen(n["url"].rstrip("/") + "/nexus/shutdown", timeout=2.0)
            print("%s✅ %s : shutdown envoyé%s" % (GREEN, n["name"], NC))
            remaining = [r for r in remaining if r["url"] != n["url"]]
        except Exception as exc:  # noqa: BLE001
            print("%s⚠ %s : pas de réponse (%s)%s" % (YELLOW, n["name"], exc, NC))
    save_registry(remaining)
    return 0


def cmd_list(_args):
    nodes = load_registry()
    if not nodes:
        print("Registre vide — démarre un nœud : %spython3 nexus-ctl.py start%s" % (BOLD, NC))
        return 0
    print("  %-18s %-26s %-16s %-10s %s" % ("NŒUD", "URL", "RÉGION", "STATUT", "P99"))
    for n in nodes:
        try:
            with urllib.request.urlopen(n["url"].rstrip("/") + "/nexus/metrics", timeout=1.5) as r:
                m = json.loads(r.read().decode())
            p99 = m["latency_ms"]["p99"]
            v = "%s✅ %.2fms%s" % (GREEN, p99, NC) if p99 <= 2.0 else "%s⚠ %.2fms%s" % (YELLOW, p99, NC)
            print("  %-18s %-26s %-16s %s✅ EN LIGNE%s  %s" %
                  (n["name"], n["url"], n.get("region", "—"), GREEN, NC, v))
        except Exception:  # noqa: BLE001
            print("  %-18s %-26s %-16s %s❌ HORS LIGNE%s  —" %
                  (n["name"], n["url"], n.get("region", "—"), RED, NC))
    return 0


def cmd_warm(args):
    nodes = load_registry()
    if not nodes:
        print("Aucun nœud — lance : python3 nexus-ctl.py start")
        return 1
    url = nodes[0]["url"].rstrip("/")
    for i in range(2):
        t0 = time.perf_counter()
        with urllib.request.urlopen(url + args.path, timeout=8.0) as r:
            body = r.read()
            state = r.headers.get("X-Nexus-Cache", "?")
            ms = (time.perf_counter() - t0) * 1000.0
        print("  essai %d : %-5s %6.2fms  (%d octets)" % (i + 1, state, ms, len(body)))
    print("%s✅ Cache chaud sur %s%s" % (GREEN, args.path, NC))
    return 0


def cmd_bench(args):
    cmd = [sys.executable, os.path.join(BASE_DIR, "nexus-bench.py"),
           "--samples", str(args.samples), "--path", args.path]
    if args.edge:
        cmd += ["--edge", args.edge]
    if args.origin:
        cmd += ["--origin", args.origin]
    return subprocess.call(cmd)


def main():
    ap = argparse.ArgumentParser(description="NEXUS-CTL — contrôle des nœuds Edge")
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("start", help="démarre un nœud + l'enregistre")
    p.add_argument("--config", default=CONFIG)
    p.set_defaults(fn=cmd_start)

    p = sub.add_parser("stop", help="arrête un nœud (ou all)")
    p.add_argument("name", nargs="?", default="all")
    p.set_defaults(fn=cmd_stop)

    p = sub.add_parser("list", help="statut des nœuds")
    p.set_defaults(fn=cmd_list)

    p = sub.add_parser("warm", help="préchauffe un chemin")
    p.add_argument("path")
    p.set_defaults(fn=cmd_warm)

    p = sub.add_parser("bench", help="bench Edge vs Origine")
    p.add_argument("--samples", type=int, default=30)
    p.add_argument("--path", default="/npm/jquery@3.7.1/dist/jquery.min.js")
    p.add_argument("--edge", default=None)
    p.add_argument("--origin", default=None)
    p.set_defaults(fn=cmd_bench)

    args = ap.parse_args()
    if not getattr(args, "fn", None):
        ap.print_help()
        return 0
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
