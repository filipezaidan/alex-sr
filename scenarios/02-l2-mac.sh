#!/bin/bash
set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== CENARIO 02 - BLOQUEIO POR MAC ==="

MAC=$(kathara exec -d "$LAB_DIR" pc2 \
  "cat /sys/class/net/eth0/address" | tr -d '[:space:]')

echo "[1] MAC do pc2: $MAC"

echo "[2] Antes do bloqueio"
kathara exec -d "$LAB_DIR" pc2 "ping -c 2 10.0.2.10"

echo "[3] Aplicando bloqueio"
kathara exec -d "$LAB_DIR" fw \
  "iptables -I FORWARD 1 -m mac --mac-source $MAC -j DROP"

echo "[4] Depois do bloqueio"
kathara exec -d "$LAB_DIR" pc2 "ping -c 2 -W 1 10.0.2.10" || true

echo "[5] pc1 continua funcionando"
kathara exec -d "$LAB_DIR" pc1 "ping -c 2 10.0.2.10"

echo "[6] Regras"
kathara exec -d "$LAB_DIR" fw \
  "iptables -L FORWARD -n -v --line-numbers"

echo "=== CENARIO 02 CONCLUIDO ==="