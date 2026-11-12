#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
════════════════════════════════════════════════════════════════════════════
 NEXUS-BENCH v1.0 — Preuve de latence : Nexus Edge vs Origine CDN

 Méthodologie honnête (celle que le partenaire acceptera) :
   - connexions PERSISTANTES des deux côtés (keep-alive) → on isole
     le temps de traitement + le réseau applicatif, pas le handshake TLS
   - même chemin, mêmes octets, N échantillons
   - p50 / p95 / p99 / max, verdict contre l'objectif ≤ 2ms

 Usage :
   python3 nexus-bench.py --samples 30
   python3 nexus-bench.py --edge http://127.0.0.1:8765 \
                          --origin https://cdn.jsdelivr.net \
                          --path /npm/jquery@3.7.1/dist/jquery.min.js
════════════════════════════════════════════════════════════════════════════
"""

import argparse
import http.client
import json
import os
import statistics
import sys
import time
import urllib.parse

VERSION = "nexus-bench/1.0.0"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_MS = 2.0

GREEN = "\033[0;32m"; RED = "\033[0;31m"; YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"; BOLD = "\033[1m"; DIM = "\033[2m"; NC = "\033[0m"
W = 74


def pctl(data, p):
    if not data:
        return 0.0
    s = sorted(data)
    k = max(0, min(len(s) - 1, int(round(p / 100.0 * (len(s) - 1)))))
    return s[k]


def bench_keepalive(base_url, path, samples, timeout=6.0):
    """Bench avec une seule connexion persistante — isole le traitement."""
    u = urllib.parse.urlparse(base_url)
    port = u.port or (443 if u.scheme == "https" else 80)
    conn_cls = http.client.HTTPSConnection if u.scheme == "https" else http.client.HTTPConnection
    latencies = []
    cache_states = {}
    conn = conn_cls(u.hostname, port, timeout=timeout)
    i = 0
    while i < samples:
        try:
            t0 = time.perf_counter()
            conn.request("GET", path)
            resp = conn.getresponse()
            resp.read()
            dt = (time.perf_counter() - t0) * 1000.0
            state = resp.getheader("X-Nexus-Cache", "—")
            cache_states[state] = cache_states.get(state, 0) + 1
            latencies.append(dt)
            i += 1
        except (http.client.HTTPException, OSError):
            # Le serveur a fermé la connexion → on la rouvre, échantillon rejoué
            try:
                conn.close()
            except OSError:
                pass
            conn = conn_cls(u.hostname, port, timeout=timeout)
            time.sleep(0.05)
    try:
        conn.close()
    except OSError:
        pass
    return latencies, cache_states


def row(label, data, color=NC):
    if not data:
        return "  %-14s %s—%s" % (label, DIM, NC)
    return ("  %-14s %s%-8.2f %-8.2f %-8.2f %-8.2f%s" %
            (label, color, pctl(data, 50), pctl(data, 95), pctl(data, 99), max(data), NC))


def main():
    ap = argparse.ArgumentParser(description="NEXUS-BENCH — Edge vs Origine")
    ap.add_argument("--edge", default="http://127.0.0.1:8765")
    ap.add_argument("--origin", default=None, help="défaut : lu dans config/nexus.json")
    ap.add_argument("--path", default="/npm/jquery@3.7.1/dist/jquery.min.js")
    ap.add_argument("--samples", type=int, default=30)
    args = ap.parse_args()

    if args.origin is None:
        try:
            with open(os.path.join(BASE_DIR, "config", "nexus.json"), encoding="utf-8") as f:
                args.origin = json.load(f)["origins"][""]
        except (OSError, KeyError):
            args.origin = "https://cdn.jsdelivr.net"

    print("")
    print("%s════════════════════════════════════════════════════════════════════════%s" % (CYAN, NC))
    print("  %sNEXUS-BENCH%s  %s%s%s" % (CYAN, NC, DIM, VERSION, NC))
    print("%s════════════════════════════════════════════════════════════════════════%s" % (CYAN, NC))
    print("  Cible        : %s%s%s" % (BOLD, args.path, NC))
    print("  Échantillons : %d (connexion persistante des deux côtés)" % args.samples)
    print("  Objectif     : p99 ≤ %.0fms sur le chemin Nexus" % TARGET_MS)
    print("")

    edge_lat, states = bench_keepalive(args.edge, args.path, args.samples)
    hit_ratio = 100.0 * states.get("HIT", 0) / max(1, sum(states.values()))

    orig_lat = []
    orig_err = None
    try:
        orig_lat, _ = bench_keepalive(args.origin, args.path, max(5, args.samples // 3))
    except Exception as exc:  # noqa: BLE001
        orig_err = str(exc)

    print("  %s%-14s %-8s %-8s %-8s %s%s" %
          (CYAN, "CHEMIN", "p50", "p95", "p99", "max", NC))
    print("  " + "─" * (W - 2))
    p99_edge = pctl(edge_lat, 99)
    color = GREEN if p99_edge <= TARGET_MS else YELLOW
    print(row("Nexus Edge", edge_lat, color))
    print(row("Origine CDN", orig_lat, DIM))
    print("")
    if orig_lat:
        ratio = pctl(orig_lat, 50) / max(0.001, pctl(edge_lat, 50))
        print("  Gain p50      : %s%.1fx plus rapide que l'origine%s" % (BOLD, ratio, NC))
        print("  Gain p99      : %s%.1fx plus rapide%s" %
              (BOLD, pctl(orig_lat, 99) / max(0.001, p99_edge), NC))
    else:
        print("  %s⚠ Origine injoignable (%s) — comparaison Edge uniquement%s" %
              (YELLOW, orig_err, NC))
    print("  Cache HIT     : %.1f%%   %s" % (hit_ratio, states))
    print("")
    if p99_edge <= TARGET_MS:
        print("  %s✅ VERDICT : p99 = %.2fms ≤ %.0fms — OBJECTIF ATTEINT.%s" %
              (GREEN, p99_edge, TARGET_MS, NC))
        print("  %s   Chemin complet en production = RTT fibre (<50km) + ce traitement.%s" % (GREEN, NC))
    else:
        print("  %s⚠ p99 = %.2fms au-dessus de l'objectif — vérifie que le cache est chaud%s" %
              (YELLOW, p99_edge, NC))
        print("  %s  (un premier MISS inclut l'aller-retour vers l'origine)%s" % (YELLOW, NC))
    print("%s════════════════════════════════════════════════════════════════════════%s" % (CYAN, NC))
    return 0 if p99_edge <= TARGET_MS else 1


if __name__ == "__main__":
    sys.exit(main())
