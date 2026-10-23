#!/bin/bash
set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo
echo "[1] Subindo HTTP 6881 e 8080"

kathara exec -d "$LAB_DIR" web \
  "sh -c 'python3 -m http.server 6881 >/tmp/http-6881.log 2>&1 &'"

kathara exec -d "$LAB_DIR" web \
  "sh -c 'python3 -m http.server 8080 >/tmp/http-8080.log 2>&1 &'"

sleep 1

echo
echo "[2] Antes: ambas respondem"

kathara exec -d "$LAB_DIR" pc1 \
  "curl -sS --max-time 3 -o /dev/null -w '6881 -> HTTP %{http_code}\n' http://10.0.2.10:6881"

kathara exec -d "$LAB_DIR" pc1 \
  "curl -sS --max-time 3 -o /dev/null -w '8080 -> HTTP %{http_code}\n' http://10.0.2.10:8080"

echo
echo "[3] Bloqueando portas 6881-6889"

kathara exec -d "$LAB_DIR" fw \
  "iptables -I FORWARD 1 -p tcp --dport 6881:6889 -j DROP"

echo
echo "[4] Depois do bloqueio"

if kathara exec -d "$LAB_DIR" pc1 \
  "curl -sS --max-time 3 -o /dev/null http://10.0.2.10:6881"; then
    echo "[ERRO] Porta 6881 deveria estar bloqueada."
    exit 1
else
    echo "[OK] 6881 bloqueada."
fi

kathara exec -d "$LAB_DIR" pc1 \
  "curl -sS --max-time 3 -o /dev/null -w '8080 -> HTTP %{http_code}\n' http://10.0.2.10:8080"

echo
echo "========================================"
echo " CENARIO 04 CONCLUIDO"
echo "========================================"