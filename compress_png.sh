#!/usr/bin/env bash
# Resize and compress PNGs on macOS CLI.
# - Uses built-in `sips` for resizing (no install needed).
# - Uses `pngquant` for high-impact lossy compression (optional, via Homebrew).
# - Uses `optipng` for lossless compression (optional, via Homebrew).
#
# Usage:
#   scripts/compress_png.sh input.png [--max-width N] [--out output.png] [--lossy QMIN-QMAX] [--lossless]
# Examples:
#   scripts/compress_png.sh photo.png --max-width 1280
#   scripts/compress_png.sh icon.png --lossless
#   scripts/compress_png.sh banner.png --max-width 1600 --lossy 60-80 --out banner-optimized.png
#
# Install optional tools:
#   brew install pngquant optipng

set -euo pipefail

usage() {
  echo "Usage: $0 input.png [--max-width N] [--out output.png] [--lossy QMIN-QMAX] [--lossless]"
  echo "  --max-width N      Resize (keeping aspect) so the longest side is N px (uses sips)."
  echo "  --out FILE         Write result to FILE (default: <input>-min.png)."
  echo "  --lossy RANGE      Use pngquant with quality RANGE (e.g. 65-80). Default: 65-80."
  echo "  --lossless         Use only lossless compression (optipng)."
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

in="$1"; shift || true
if [[ ! -f "$in" ]]; then
  echo "Error: input file not found: $in" >&2
  exit 2
fi

# Defaults
max_width=""
out=""
mode="lossy"
lossy_range="65-80"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-width)
      [[ $# -ge 2 ]] || usage
      max_width="$2"
      shift 2
      ;;
    --out)
      [[ $# -ge 2 ]] || usage
      out="$2"
      shift 2
      ;;
    --lossless)
      mode="lossless"
      shift
      ;;
    --lossy)
      [[ $# -ge 2 ]] || usage
      mode="lossy"
      lossy_range="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      echo "Unexpected arg: $1" >&2
      usage
      ;;
  esac
done

# Derive output name
base="${in%.*}"
ext="${in##*.}"
if [[ -z "${out}" ]]; then
  out="${base}-min.png"
fi

# Work file (may be resized temp)
work="$in"
tmp_resized=""
cleanup() {
  if [[ -n "$tmp_resized" && -f "$tmp_resized" ]]; then rm -f "$tmp_resized"; fi
}
trap cleanup EXIT

# Resize if requested (sips is built-in on macOS)
if [[ -n "$max_width" ]]; then
  if ! command -v sips >/dev/null 2>&1; then
    echo "Warning: sips not found; skipping resize." >&2
  else
    tmp_resized="$(mktemp -t pngresizeXXXXXX).png"
    # -Z constrains the longest side to max_width while keeping aspect.
    sips -s format png -Z "$max_width" "$work" --out "$tmp_resized" >/dev/null
    work="$tmp_resized"
  fi
fi

# Compression step
if [[ "$mode" == "lossy" ]]; then
  if command -v pngquant >/dev/null 2>&1; then
    # pngquant writes to output explicitly with --output; --skip-if-larger avoids worsening size.
    pngquant --quality="${lossy_range}" --strip --skip-if-larger --force --output "$out" -- "$work" || {
      echo "pngquant could not reduce size; falling back to lossless (optipng)..." >&2
      if command -v optipng >/dev/null 2>&1; then
        cp -f "$work" "$out"
        optipng -o7 -strip all -quiet "$out" >/dev/null || true
      else
        cp -f "$work" "$out"
      fi
    }
  else
    echo "pngquant not found; for best results: brew install pngquant" >&2
    # Try lossless as a fallback
    if command -v optipng >/dev/null 2>&1; then
      cp -f "$work" "$out"
      optipng -o7 -strip all -quiet "$out" >/dev/null || true
    else
      echo "optipng not found; install with: brew install optipng" >&2
      # Just deliver resized (if any)
      cp -f "$work" "$out"
    fi
  fi
else
  # Lossless only
  if command -v optipng >/dev/null 2>&1; then
    cp -f "$work" "$out"
    optipng -o7 -strip all -quiet "$out" >/dev/null || true
  else
    echo "optipng not found; install with: brew install optipng" >&2
    cp -f "$work" "$out"
  fi
fi

# Report sizes
orig_bytes=$(stat -f%z "$in" 2>/dev/null || stat -c%s "$in")
new_bytes=$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out")
printf "Done: %s -> %s (%.1f%% of original)\n" "$in" "$out" "$(awk -v n=$new_bytes -v o=$orig_bytes 'BEGIN{ if(o>0){print (n/o)*100}else{print 0}}')"
