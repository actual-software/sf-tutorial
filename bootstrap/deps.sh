#!/usr/bin/env bash

# Install bd 1.0.3 and dolt 1.8.8 into ~/.local/bin
  set -euo pipefail
  
  BD_VERSION=1.0.3
  DOLT_VERSION=1.8.8
  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "$INSTALL_DIR"
  
  # Detect OS + arch (darwin/linux, amd64/arm64)
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) arch=amd64 ;;
    arm64|aarch64) arch=arm64 ;;
    *) echo "Unsupported arch: $arch" >&2; exit 1 ;;
  esac
  case "$os" in
    darwin|linux) ;;
    *) echo "Unsupported OS: $os" >&2; exit 1 ;;                                                                                          
  esac
  
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  cd "$tmp"

  # --- beads (bd) ---
  bd_asset="beads_${BD_VERSION}_${os}_${arch}.tar.gz"
  curl -fsSL -o "$bd_asset" \
    "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/${bd_asset}"
  curl -fsSL -o checksums.txt \
    "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/checksums.txt"
  shasum -a 256 -c <(grep " ${bd_asset}\$" checksums.txt)
  tar -xzf "$bd_asset"
  install -m 755 bd "${INSTALL_DIR}/bd"

  # --- dolt ---
  dolt_dir="dolt-${os}-${arch}"
  curl -fsSL -o dolt.tar.gz \
    "https://github.com/dolthub/dolt/releases/download/v${DOLT_VERSION}/${dolt_dir}.tar.gz"
  tar -xzf dolt.tar.gz
  install -m 755 "${dolt_dir}/bin/dolt" "${INSTALL_DIR}/dolt"

  # Verify
  "${INSTALL_DIR}/bd" --version
  "${INSTALL_DIR}/dolt" version | head -1

  echo "Installed to ${INSTALL_DIR}. Ensure it's on your PATH:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'