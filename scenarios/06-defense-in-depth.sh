#!/bin/bash
set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== CENARIO 06 - DEFENSE IN DEPTH ==="

echo "[1] web -> pc1"
kathara exec -d "$LAB_DIR" web \
  "ping -c 2 -W 1 10.0.1.10" || true

echo "[2] web -> pc2"
kathara exec -d "$LAB_DIR" web \
  "ping -c 2 -W 1 10.0.1.11" || true

echo "[3] Firewall"
kathara exec -d "$LAB_DIR" fw \
  "iptables -L FORWARD -n -v --line-numbers"

echo "DMZ -> LAN bloqueado."
echo "A segmentacao + policy DROP + stateful filtering protegem a LAN."

echo "=== CENARIO 06 CONCLUIDO ==="