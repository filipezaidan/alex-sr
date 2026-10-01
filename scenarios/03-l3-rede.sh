#!/bin/bash
set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== CENARIO 03 - L3: ICMP E IP ==="

echo
echo "[1] Antes: LAN -> DMZ"
kathara exec -d "$LAB_DIR" pc1 "ping -c 2 10.0.2.10"

echo
echo "[2] Bloqueando ICMP"
kathara exec -d "$LAB_DIR" fw \
  "iptables -I FORWARD 1 -i eth0 -o eth1 -p icmp -j DROP"

echo
echo "[3] Depois: LAN -> DMZ"
kathara exec -d "$LAB_DIR" pc1 "ping -c 2 -W 1 10.0.2.10" || true

echo
echo "[4] Removendo regra ICMP"
kathara exec -d "$LAB_DIR" fw \
  "iptables -D FORWARD -i eth0 -o eth1 -p icmp -j DROP"

echo
echo "[5] Antes: LAN -> 8.8.8.8"
kathara exec -d "$LAB_DIR" pc1 "ping -c 2 8.8.8.8"

echo
echo "[6] Bloqueando 8.8.8.8"
kathara exec -d "$LAB_DIR" fw \
  "iptables -I FORWARD 1 -i eth0 -d 8.8.8.8 -j DROP"

echo
echo "[7] Depois"
kathara exec -d "$LAB_DIR" pc1 "ping -c 2 -W 1 8.8.8.8" || true

echo
echo "[8] DMZ continua acessível"
kathara exec -d "$LAB_DIR" pc1 "ping -c 2 10.0.2.10"

echo "=== CENARIO 03 CONCLUIDO ==="