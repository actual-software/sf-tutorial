#!/usr/bin/env bash

# Install the pinned versions of bd, dolt and gc into ~/.local/bin.
#
# The constants below are the single source of truth for all three pins.
# preflight.sh and bootstrap.sh read them from here rather than restating them,
# so changing a version means editing exactly one line. bd and dolt come from
# release tarballs; gc is built from source at a pinned commit, so it carries a
# commit and a repo alongside its version.
  set -euo pipefail

  BD_VERSION=1.1.0
  DOLT_VERSION=2.2.2
  GC_VERSION=1.4.0
  GC_COMMIT=a7297c511d637a3609947386f3389d76ddb2f23b
  # Upstream, not the actual-software fork: that fork sits hundreds of commits
  # behind with no commits of its own.
  GC_REPO=gastownhall/gascity
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

  # --- gascity (gc) ---
  # gc has no release tarball to fetch, so it is built from source at the
  # pinned commit. Budget a few minutes the first time.
  #
  # Prefer the copy this script installs when deciding whether a build is
  # needed, so the answer does not depend on where an older gc sits in PATH.
  gc_bin=""
  if [ -x "${INSTALL_DIR}/gc" ]; then
    gc_bin="${INSTALL_DIR}/gc"
  elif command -v gc >/dev/null 2>&1; then
    gc_bin="$(command -v gc)"
  fi

  gc_at_pin=false
  if [ -n "$gc_bin" ]; then
    installed_gc_commit=$("$gc_bin" version --long 2>/dev/null \
      | sed -n 's/.*commit: \([0-9a-f][0-9a-f]*\).*/\1/p' || true)
    # `gc version --long` abbreviates the commit, so a match reads as "the
    # installed value is a prefix of the pin". A gc built any other way reports
    # `commit: unknown`, which matches nothing and earns a rebuild.
    if [ -n "$installed_gc_commit" ] \
       && [ "${GC_COMMIT#"$installed_gc_commit"}" != "$GC_COMMIT" ]; then
      gc_at_pin=true
    fi
  fi

  if [ "$gc_at_pin" = true ]; then
    echo "gc ${GC_VERSION} already built from the pinned commit ${GC_COMMIT:0:9}; skipping the build."
  else
    if ! command -v go >/dev/null 2>&1; then
      echo "gc is built from source and needs Go on PATH, which is missing." >&2
      echo "Install Go from https://go.dev/dl/, then re-run this script." >&2
      exit 1
    fi
    echo "Building gc ${GC_VERSION} from ${GC_REPO} at ${GC_COMMIT:0:9}. This takes a few minutes."
    # Clone with history: the Makefile reads the version string off the
    # checked-out tag, so a tagless clone would build as "dev".
    git clone --quiet "https://github.com/${GC_REPO}.git" gascity
    # `make install` builds ./cmd/gc into $(go env GOPATH)/bin and symlinks it
    # into ~/.local/bin, alongside bd and dolt.
    ( cd gascity && git checkout --quiet "$GC_COMMIT" && make install )
    if [ -x "${INSTALL_DIR}/gc" ]; then
      gc_bin="${INSTALL_DIR}/gc"
    elif command -v gc >/dev/null 2>&1; then
      gc_bin="$(command -v gc)"
    fi
  fi

  # Verify
  "${INSTALL_DIR}/bd" --version
  "${INSTALL_DIR}/dolt" version | head -1
  "${gc_bin:-${INSTALL_DIR}/gc}" version --long | head -1

  echo "Installed to ${INSTALL_DIR}. Ensure it's on your PATH:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'