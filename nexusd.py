#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
════════════════════════════════════════════════════════════════════════════
 NEXUS EDGE NODE — nexusd v1.0
 Nœud Edge Micro-Latence — objectif : 1-2ms sur le chemin Nexus.

 Ce n'est PAS une simulation : c'est un vrai serveur HTTP qui se déploie
 sur n'importe quelle machine proche des utilisateurs (datacenter FAI,
 VPS régional, micro-node). Placé à <50km de l'utilisateur, le chemin
 complet = fibre (~0.2ms) + traitement nexusd (<1ms) → 1-2ms.

 Pourquoi c'est rapide (ingénierie, pas magie) :
   1. Connexions persistantes HTTP/1.1 → zéro handshake TCP/TLS répété
   2. Cache chaud 100% RAM → zéro accès disque sur un HIT
   3. Warm-up au démarrage → cache déjà chaud avant les utilisateurs
   4. E/S asynchrones (asyncio) → 1 cœur sert des milliers de connexions
   5. Stale-if-error → qualité de service même si l'origine tombe

 Logique v1 intégrée (ton concept) :
   Priorisation → warm-up des assets critiques au boot
   Correction   → headers cache propres (Cache-Control, ETag, X-Nexus-*)
   Validation   → health-check + stale-if-error (jamais de 5xx si cache ok)

 Aucune dépendance externe — Python 3.8+ (stdlib uniquement).
════════════════════════════════════════════════════════════════════════════
"""

import argparse
import asyncio
import json
import os
import signal
import sys
import time
import urllib.request
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

VERSION = "nexusd/1.0.0"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG = os.path.join(BASE_DIR, "config", "nexus.json")

# ─── État global du nœud ────────────────────────────────────────────────────
NODE = {"name": "node-local-01", "region": "local", "host": "127.0.0.1", "port": 8765}
ORIGINS = {"": "https://cdn.jsdelivr.net"}
WARMUP_PATHS = []
MAX_ENTRIES = 5000
TTL_S = 300
MAX_BODY = 5 * 1024 * 1024
LOG_FILE = os.path.join(BASE_DIR, "logs", "nexusd.log")
STATE_FILE = os.path.join(BASE_DIR, "runtime", "state.json")
PID_FILE = os.path.join(BASE_DIR, "runtime", "nexusd.pid")
IDLE_TIMEOUT = 30.0

CACHE = {}                       # clé = chemin → entrée cache
EXEC = ThreadPoolExecutor(max_workers=4)
STOP = asyncio.Event()


class Metrics:
    """Compteurs + latences serveur (temps de traitement, hors réseau)."""

    def __init__(self, maxlen=20000):
        self.started = time.time()
        self.requests = 0
        self.hits = 0
        self.misses = 0
        self.stales = 0
        self.errors = 0
        self.bytes_served = 0
        self.evictions = 0
        self.origin_errors = 0
        self.last_origin_ok = 0.0
        self.lat = deque(maxlen=maxlen)

    def pctl(self, p):
        data = sorted(self.lat)
        if not data:
            return 0.0
        k = max(0, min(len(data) - 1, int(round(p / 100.0 * (len(data) - 1)))))
        return data[k]

    def snapshot(self):
        up = max(0.001, time.time() - self.started)
        return {
            "version": VERSION,
            "node": NODE["name"],
            "region": NODE["region"],
            "uptime_s": round(up, 1),
            "requests": self.requests,
            "rps": round(self.requests / up, 1),
            "hits": self.hits,
            "misses": self.misses,
            "stales": self.stales,
            "errors": self.errors,
            "hit_ratio_pct": round(self.hits / max(1, self.hits + self.misses + self.stales) * 100, 1),
            "bytes_served": self.bytes_served,
            "evictions": self.evictions,
            "origin_errors": self.origin_errors,
            "last_origin_ok_ago_s": round(time.time() - self.last_origin_ok, 1) if self.last_origin_ok else None,
            "cache_entries": len(CACHE),
            "latency_ms": {
                "p50": round(self.pctl(50), 3),
                "p95": round(self.pctl(95), 3),
                "p99": round(self.pctl(99), 3),
                "max": round(max(self.lat) if self.lat else 0.0, 3),
            },
        }


METRICS = Metrics()


def log(msg):
    line = "[%s] %s" % (datetime.now().strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


# ─── Origine ────────────────────────────────────────────────────────────────
def fetch_origin(url, timeout=5.0):
    """Récupère une ressource depuis l'origine (exécuté hors boucle asyncio)."""
    req = urllib.request.Request(
        url, headers={"User-Agent": VERSION, "Accept-Encoding": "identity"}
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read(MAX_BODY + 1)
            return {
                "status": r.status,
                "body": body[:MAX_BODY],
                "ctype": r.headers.get("Content-Type", "application/octet-stream"),
                "etag": r.headers.get("ETag"),
                "cc": r.headers.get("Cache-Control"),
            }
    except Exception as exc:  # noqa: BLE001
        return {"status": 0, "error": str(exc)}


def origin_for(target):
    """Long préfixe gagnant dans la table des origines."""
    best, best_len = None, -1
    for prefix, url in ORIGINS.items():
        if target.startswith(prefix) and len(prefix) > best_len:
            best, best_len = url, len(prefix)
    return best


async def resolve(target):
    """Priorisation → Correction → Validation. Retourne (status, ctype, body, état, entête)."""
    ent = CACHE.get(target)
    now = time.time()
    if ent is not None and (now - ent["stored"]) <= TTL_S:
        METRICS.hits += 1
        return 200, ent["ctype"], ent["body"], "HIT", ent

    loop = asyncio.get_event_loop()
    orig = origin_for(target)
    if orig:
        url = orig.rstrip("/") + target
        res = await loop.run_in_executor(EXEC, fetch_origin, url)
        if res["status"] == 200 and len(res["body"]) <= MAX_BODY:
            if ent is None and len(CACHE) >= MAX_ENTRIES:
                old_key = min(CACHE, key=lambda k: CACHE[k]["stored"])
                del CACHE[old_key]
                METRICS.evictions += 1
            CACHE[target] = {
                "body": res["body"],
                "ctype": res["ctype"],
                "etag": res.get("etag"),
                "cc": res.get("cc"),
                "stored": now,
            }
            METRICS.misses += 1
            METRICS.last_origin_ok = now
            new = CACHE[target]
            return 200, new["ctype"], new["body"], "MISS", new
        METRICS.origin_errors += 1
        log("⚠ origine KO pour %s (%s)" % (target, res.get("error", "http %s" % res["status"])))

    # Validation / qualité de service : stale-if-error
    if ent is not None:
        METRICS.stales += 1
        return 200, ent["ctype"], ent["body"], "STALE", ent

    METRICS.errors += 1
    body = json.dumps({"error": "origin_unavailable", "target": target}).encode()
    return 502, "application/json", body, "ERROR", None


# ─── Serveur HTTP/1.1 bas niveau ────────────────────────────────────────────
def build_headers(status, ctype, body_len, state, ent, keep_alive, latency_ms):
    lines = [
        "HTTP/1.1 %s" % status,
        "Server: %s" % VERSION,
        "Content-Type: %s" % ctype,
        "Content-Length: %d" % body_len,
        "X-Nexus-Node: %s" % NODE["name"],
        "X-Nexus-Cache: %s" % state,
        "X-Nexus-Latency: %.2fms" % latency_ms,
    ]
    if ent is not None and ent.get("etag"):
        lines.append("ETag: %s" % ent["etag"])
    if state == "HIT":
        lines.append("Cache-Control: public, max-age=%d" % TTL_S)
    elif state == "STALE":
        lines.append("Cache-Control: public, max-age=0, stale-if-error=86400")
    else:
        lines.append("Cache-Control: public, max-age=60")
    lines.append("Connection: %s" % ("keep-alive" if keep_alive else "close"))
    return ("\r\n".join(lines) + "\r\n\r\n").encode("latin-1")


async def handle_conn(reader, writer):
    peer = writer.get_extra_info("peername")
    peer_ip = peer[0] if peer else "?"
    try:
        while True:
            try:
                raw = await asyncio.wait_for(
                    reader.readuntil(b"\r\n\r\n"), timeout=IDLE_TIMEOUT
                )
            except (asyncio.TimeoutError, asyncio.IncompleteReadError, ConnectionError):
                break

            req_line = raw.split(b"\r\n", 1)[0].decode("latin-1")
            parts = req_line.split(" ")
            if len(parts) < 3:
                break
            method, target = parts[0], parts[1]
            version = parts[2] if len(parts) > 2 else "HTTP/1.0"

            # Corps éventuel (Content-Length) — lu et ignoré
            headers_l = raw.split(b"\r\n\r\n", 1)[1] if b"\r\n\r\n" in raw else b""
            cl = 0
            for hline in headers_l.split(b"\r\n"):
                if hline.lower().startswith(b"content-length:"):
                    try:
                        cl = int(hline.split(b":", 1)[1].strip())
                    except ValueError:
                        cl = 0
            if cl > 0:
                await reader.readexactly(cl)

            keep_alive = version == "HTTP/1.1"
            for hline in headers_l.split(b"\r\n"):
                hl = hline.lower()
                if hl.startswith(b"connection:"):
                    val = hline.split(b":", 1)[1].strip().lower()
                    if val == b"close":
                        keep_alive = False
                    elif val == b"keep-alive":
                        keep_alive = True

            # Endpoints de supervision NEXUS
            if target.startswith("/nexus/"):
                if target == "/nexus/health":
                    body = json.dumps({"status": "online", **METRICS.snapshot()}).encode()
                    head = build_headers("200 OK", "application/json", len(body),
                                         "HEALTH", None, keep_alive, 0.0)
                elif target == "/nexus/metrics":
                    body = json.dumps(METRICS.snapshot()).encode()
                    head = build_headers("200 OK", "application/json", len(body),
                                         "METRICS", None, keep_alive, 0.0)
                elif target == "/nexus/shutdown":
                    if peer_ip in ("127.0.0.1", "::1"):
                        body = json.dumps({"status": "stopping"}).encode()
                        head = build_headers("200 OK", "application/json", len(body),
                                             "SHUTDOWN", None, False, 0.0)
                        writer.write(head + body)
                        await writer.drain()
                        STOP.set()
                        return
                    body = json.dumps({"error": "forbidden"}).encode()
                    head = build_headers("403 Forbidden", "application/json",
                                         len(body), "ERROR", None, False, 0.0)
                else:
                    body = json.dumps({"error": "unknown_endpoint"}).encode()
                    head = build_headers("404 Not Found", "application/json",
                                         len(body), "ERROR", None, keep_alive, 0.0)
                writer.write(head + body if method != "HEAD" else head)
                await writer.drain()
                if not keep_alive:
                    break
                continue

            if method not in ("GET", "HEAD"):
                body = json.dumps({"error": "method_not_allowed"}).encode()
                head = build_headers("405 Method Not Allowed", "application/json",
                                     len(body), "ERROR", None, keep_alive, 0.0)
                writer.write(head + body)
                await writer.drain()
                if not keep_alive:
                    break
                continue

            t0 = time.perf_counter()
            status, ctype, body, state, ent = await resolve(target)
            latency_ms = (time.perf_counter() - t0) * 1000.0

            METRICS.requests += 1
            METRICS.lat.append(latency_ms)
            METRICS.bytes_served += len(body)

            status_text = {200: "200 OK", 404: "404 Not Found", 502: "502 Bad Gateway"}.get(
                status, "%d Status" % status
            )
            head = build_headers(status_text, ctype, len(body), state, ent, keep_alive, latency_ms)
            writer.write(head + (b"" if method == "HEAD" else body))
            await writer.drain()
            if not keep_alive:
                break
    except (ConnectionError, BrokenPipeError):
        pass
    finally:
        try:
            writer.close()
        except Exception:  # noqa: BLE001
            pass


# ─── Tâches de fond ─────────────────────────────────────────────────────────
async def warmup_task():
    """PRIORISATION : préchauffe les assets critiques dès le boot."""
    if not WARMUP_PATHS:
        return
    log("warm-up : %d chemin(s) critique(s)…" % len(WARMUP_PATHS))
    for path in WARMUP_PATHS:
        t0 = time.perf_counter()
        _s, _c, body, state, _e = await resolve(path)
        ms = (time.perf_counter() - t0) * 1000.0
        log("warm-up %s → %s (%.0fms, %d octets)" % (path, state, ms, len(body)))
    log("cache chaud : %d entrée(s) prête(s)" % len(CACHE))


async def state_dump_task():
    """Écrit l'état pour outils externes (nexus-smi peut aussi lire ce fichier)."""
    while not STOP.is_set():
        try:
            os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(METRICS.snapshot(), f, indent=2)
        except OSError:
            pass
        try:
            await asyncio.wait_for(STOP.wait(), timeout=5.0)
        except asyncio.TimeoutError:
            pass


# ─── Démarrage ──────────────────────────────────────────────────────────────
def load_config(path):
    global NODE, ORIGINS, WARMUP_PATHS, MAX_ENTRIES, TTL_S, MAX_BODY
    global LOG_FILE, STATE_FILE, PID_FILE
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    node = cfg.get("node", {})
    NODE.update({k: node.get(k, NODE[k]) for k in NODE})
    ORIGINS = cfg.get("origins", ORIGINS)
    WARMUP_PATHS = cfg.get("warmup", [])
    cache = cfg.get("cache", {})
    MAX_ENTRIES = int(cache.get("max_entries", MAX_ENTRIES))
    TTL_S = int(cache.get("ttl_s", TTL_S))
    MAX_BODY = int(cache.get("max_body_bytes", MAX_BODY))
    LOG_FILE = os.path.join(BASE_DIR, cfg.get("log_file", "logs/nexusd.log"))
    STATE_FILE = os.path.join(BASE_DIR, cfg.get("state_file", "runtime/state.json"))
    PID_FILE = os.path.join(BASE_DIR, cfg.get("pid_file", "runtime/nexusd.pid"))


async def main(config_path):
    load_config(config_path)
    for d in ("logs", "runtime", "registry"):
        os.makedirs(os.path.join(BASE_DIR, d), exist_ok=True)
    with open(PID_FILE, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    loop = asyncio.get_event_loop()
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, STOP.set)
    except NotImplementedError:
        pass  # Windows

    srv = await asyncio.start_server(handle_conn, NODE["host"], NODE["port"])
    log("═══════════════════════════════════════════════════════════")
    log("  %s — nœud « %s » (région : %s)" % (VERSION, NODE["name"], NODE["region"]))
    log("  écoute : http://%s:%d" % (NODE["host"], NODE["port"]))
    log("  origine : %s" % (", ".join("%s→%s" % (k or "/*", v) for k, v in ORIGINS.items())))
    log("  cache : %d entrées max, TTL %ds — objectif latence ≤ 2ms" % (MAX_ENTRIES, TTL_S))
    log("═══════════════════════════════════════════════════════════")

    bg = [
        asyncio.create_task(warmup_task()),
        asyncio.create_task(state_dump_task()),
    ]
    stop_task = asyncio.create_task(STOP.wait())
    async with srv:
        serve = asyncio.create_task(srv.serve_forever())
        # On attend UNIQUEMENT l'arrêt demandé (signal ou /nexus/shutdown) —
        # pas la fin des tâches de fond, qui tournent en continu.
        await stop_task
        serve.cancel()
        for t in bg:
            t.cancel()
        try:
            await serve
        except asyncio.CancelledError:
            pass
    log("arrêt propre — cache abandonné (%d entrées)" % len(CACHE))
    try:
        os.remove(PID_FILE)
    except OSError:
        pass


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="NEXUS Edge Node daemon")
    ap.add_argument("--config", default=DEFAULT_CONFIG, help="fichier config JSON")
    args = ap.parse_args()
    try:
        asyncio.run(main(args.config))
    except KeyboardInterrupt:
        pass
