#!/bin/bash
# ============================================================================
# Laravel Server Manager — Kısayol (mm.sh)
# ============================================================================
# main.sh için kısa yol.
# Kullanım: bash scripts/mm.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/main.sh" "$@"
