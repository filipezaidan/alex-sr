#!/bin/bash
set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo " CENARIO 01 - SEGURANCA DE PERIMETRO"
echo "========================================"

echo "[1] Regras do firewall"
kathara exec -d "$LAB_DIR" fw \
  "iptables -L -n -v --line-numbers"

echo "[2] LAN -> DMZ"
kathara exec -d "$LAB_DIR" pc1 \
  "ping -c 2 10.0.2.10"

echo "[3] LAN -> Internet"
kathara exec -d "$LAB_DIR" pc1 \
  "ping -c 2 8.8.8.8"

echo "[4] LAN -> Internet (HTTP)"
kathara exec -d "$LAB_DIR" pc1 \
  "curl -s --max-time 5 https://example.com | head -n 3"
echo "[5] Internet -> Web"
kathara exec -d "$LAB_DIR" web \
  "nohup python3 -m http.server 80 >/tmp/http.log 2>&1 </dev/null &"

sleep 1

kathara exec -d "$LAB_DIR" r0 \
  "curl -sI --max-time 5 http://10.0.2.10 | head -n 1"

echo "[6] Internet -> LAN (bloqueado)"
! kathara exec -d "$LAB_DIR" r0 \
  "ping -c 2 -W 1 10.0.1.10"

echo "[7] DMZ -> LAN (bloqueado)"
! kathara exec -d "$LAB_DIR" web \
  "ping -c 2 -W 1 10.0.1.10"


echo "========================================"
echo " CENARIO 01 CONCLUIDO"
echo "========================================"