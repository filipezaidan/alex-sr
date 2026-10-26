#!/bin/bash
# start.sh — Builda as imagens custom (proxy-squid e rp-nginx) e reinicia o lab.
# Uso: bash start.sh

set -e

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
IMG_DIR="$LAB_DIR/images"

echo
echo "=========================================="
echo "   BUILD + RESTART DO LABORATÓRIO"
echo "=========================================="

# ── 1. Build das imagens custom ──────────────────────────────────

echo
echo "[1/3] Buildando imagem kathara/proxy-squid ..."
docker build -t kathara/proxy-squid "$IMG_DIR/proxy"

echo
echo "[1/3] Buildando imagem kathara/rp-nginx ..."
docker build -t kathara/rp-nginx "$IMG_DIR/rp"

echo
echo "[OK] Imagens prontas."

# ── 2. Limpar laboratório anterior ───────────────────────────────

echo
echo "[2/3] Limpando laboratório anterior ..."
kathara lclean -d "$LAB_DIR" 2>/dev/null || true

echo "[OK] Laboratório limpo."

# ── 3. Subir laboratório ─────────────────────────────────────────

echo
echo "[3/3] Iniciando laboratório ..."
kathara lstart -d "$LAB_DIR"

echo
echo "=========================================="
echo "   LABORATÓRIO PRONTO"
echo "=========================================="
echo
echo "  Use: kathara connect <nó>   (ex: kathara connect pc1)"
echo
