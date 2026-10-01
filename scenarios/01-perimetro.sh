#!/bin/bash
set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo " CENARIO 01 - SEGURANCA DE PERIMETRO"
echo "========================================"

echo
echo "[1] Regras do firewall"
kathara exec -d "$LAB_DIR" fw \
  "iptables -L -n -v --line-numbers"

echo
echo "[2] LAN -> DMZ"
kathara exec -d "$LAB_DIR" pc1 \
  "ping -c 2 10.0.2.10"

echo
echo "[3] LAN -> Internet"
kathara exec -d "$LAB_DIR" pc1 \
  "ping -c 2 8.8.8.8"

echo
echo "[4] LAN -> Internet (HTTPS)"
kathara exec -d "$LAB_DIR" pc1 \
  "curl -sS --max-time 5 -o /dev/null -w 'HTTP %{http_code}\n' https://example.com"

echo
echo "[5] Internet -> Web (HTTP)"
kathara exec -d "$LAB_DIR" r0 \
  "curl -sS --max-time 5 -o /dev/null -w 'HTTP %{http_code}\n' http://10.0.2.10"

echo
echo "[6] Internet -> LAN (bloqueado)"

if kathara exec -d "$LAB_DIR" r0 \
  "ping -c 2 -W 1 10.0.1.10"; then
    echo "[ERRO] Internet -> LAN deveria estar bloqueado."
    exit 1
else
    echo "[OK] Internet -> LAN bloqueado."
fi

echo
echo "[7] DMZ -> LAN (bloqueado)"

if kathara exec -d "$LAB_DIR" web \
  "ping -c 2 -W 1 10.0.1.10"; then
    echo "[ERRO] DMZ -> LAN deveria estar bloqueado."
    exit 1
else
    echo "[OK] DMZ -> LAN bloqueado."
fi

echo
echo "========================================"
echo " CENARIO 01 CONCLUIDO"
echo "========================================"