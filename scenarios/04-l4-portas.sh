#!/bin/bash
set -e

echo "[1] Subindo HTTP 6881 e 8080"
kathara exec -d "$LAB_DIR" web \
  "python3 -m http.server 6881 >/tmp/6881.log 2>&1 &"

kathara exec -d "$LAB_DIR" web \
  "python3 -m http.server 8080 >/tmp/8080.log 2>&1 &"

echo "[2] Antes: ambas respondem"
kathara exec -d "$LAB_DIR" pc1 \
  "curl -sI --max-time 3 http://10.0.2.10:6881 | head -1"

kathara exec -d "$LAB_DIR" pc1 \
  "curl -sI --max-time 3 http://10.0.2.10:8080 | head -1"

echo "[3] Bloqueando 6881-6889"
kathara exec -d "$LAB_DIR" fw \
  "iptables -I FORWARD 1 -p tcp --dport 6881:6889 -j DROP"

echo "[4] Depois"
kathara exec -d "$LAB_DIR" pc1 \
  "curl -sI --max-time 3 http://10.0.2.10:6881" || true

kathara exec -d "$LAB_DIR" pc1 \
  "curl -sI --max-time 3 http://10.0.2.10:8080 | head -1"