#!/usr/bin/env bash
# Usage: sudo ./renew_all.sh
#
# Auto-discovers every dev SSL cert this machine actually uses and renews it,
# then reloads nginx. A folder is considered "in use" if (a) it contains a
# ca.crt, AND (b) at least one *.conf in this directory references a cert
# inside it. Orphan folders are skipped — you'll see them listed at the end.
set -eu

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

renewed=()
skipped=()

for d in */; do
    name="${d%/}"
    [ -f "${d}ca.crt" ] || continue

    # Is this folder referenced by any nginx config in this directory?
    if grep -qE "/${name}/[^ ]*\.(crt|key)" *.conf 2>/dev/null; then
        echo "── renewing ${name} ──"
        sudo ./ssl.sh "${name}"
        renewed+=("${name}")
    else
        skipped+=("${name}")
    fi
done

echo
echo "── reloading nginx ──"
sudo nginx -t && sudo systemctl reload nginx

echo
echo "✓ renewed: ${renewed[*]:-none}"
if [ ${#skipped[@]} -gt 0 ]; then
    echo "⚠ skipped (no nginx config refers to them): ${skipped[*]}"
    echo "  remove with: rm -rf ${skipped[*]/#/$script_dir/}"
fi
