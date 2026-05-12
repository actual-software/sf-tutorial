#!/usr/bin/env bash

# Install bd 1.0.3 and dolt 2.0.1 into ~/.local/bin
  set -euo pipefail
  
  BD_VERSION=1.0.3
  DOLT_VERSION=2.0.1
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

  # Pick an available SHA-256 checker: sha256sum on Linux, shasum on macOS (and Linux with Perl).
  if command -v sha256sum >/dev/null 2>&1; then
    SHA256_CHECK=(sha256sum -c)
  elif command -v shasum >/dev/null 2>&1; then
    SHA256_CHECK=(shasum -a 256 -c)
  else
    echo "Neither sha256sum nor shasum found; cannot verify checksums." >&2
    exit 1
  fi

  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  cd "$tmp"

  # --- beads (bd) ---
  bd_asset="beads_${BD_VERSION}_${os}_${arch}.tar.gz"
  curl -fsSL -o "$bd_asset" \
    "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/${bd_asset}"
  curl -fsSL -o checksums.txt \
    "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/checksums.txt"
  "${SHA256_CHECK[@]}" <(grep " ${bd_asset}\$" checksums.txt)
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