#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
nasm -f bin -o "${ROOT}/MROMD.COM" "${ROOT}/mameromd.asm"
echo "Built ${ROOT}/MROMD.COM"
