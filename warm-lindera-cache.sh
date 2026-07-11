#!/bin/bash

set -euo pipefail

LINDERA_CACHE="${LINDERA_CACHE:-/opt/lindera-cache}"
LINDERA_GIT_REV="${LINDERA_GIT_REV:-25d36a02558ff1a523d2439345d03a28eb9beb3a}"
LINDERA_VERSION="0.43.1"

echo "Warming Lindera dictionary cache"
echo "  cache: $LINDERA_CACHE"
echo "  rev:   $LINDERA_GIT_REV"

workdir=$(mktemp -d)
cleanup() {
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$LINDERA_CACHE"

cat > "$workdir/Cargo.toml" <<EOF
[package]
name = "warm-lindera-cache"
version = "0.1.0"
edition = "2021"

[dependencies]
lindera = { git = "https://github.com/breezewish/lindera", rev = "$LINDERA_GIT_REV", default-features = false, features = ["unidic", "ko-dic", "compress"] }
EOF

mkdir -p "$workdir/src"
cat > "$workdir/src/lib.rs" <<'EOF'
pub fn warm_lindera_cache() {}
EOF

(
    cd "$workdir"
    echo "Running cargo check to build Lindera dictionaries..."
    LINDERA_CACHE="$LINDERA_CACHE" cargo check
)

for dictionary in lindera-unidic lindera-ko-dic; do
    dictionary_dir="$LINDERA_CACHE/$LINDERA_VERSION/$dictionary"
    if [[ ! -d "$dictionary_dir" ]]; then
        echo "Missing warmed Lindera dictionary cache: $dictionary_dir" >&2
        exit 1
    fi
    echo "Verified Lindera cache: $dictionary_dir"
done

printf '%s\n' "$LINDERA_GIT_REV" > "$LINDERA_CACHE/$LINDERA_VERSION/.lindera-git-rev"
echo "Recorded Lindera cache revision marker"

find "$LINDERA_CACHE" -type d -exec chmod 0755 {} +
find "$LINDERA_CACHE" -type f -exec chmod 0644 {} +
echo "Lindera dictionary cache is ready"
