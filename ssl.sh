#!/usr/bin/env bash
# Usage: sudo ./ssl.sh <domain> [extra_san ...]
#
# Generates a self-signed CA + leaf cert under ./<domain>/ and trusts the CA.
# The leaf SANs always include <domain> and *.<domain>. Any extra args are
# added as additional DNS SANs on the same leaf.
#
# Re-running the script for the same domain cleanly removes the previously
# trusted CA (both via `trust anchor --remove` and by deleting the matching
# p11-kit anchor file) BEFORE issuing the new CA, so no duplicates pile up.
set -eu

domain="${1:?usage: ssl.sh <domain> [extra_san ...]}"
shift || true
extra_sans=("$@")
org="${domain}-ca"

# Resolve directory of this script so the cert tree always lives next to it
# regardless of cwd.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cert_dir="${script_dir}/${domain}"
mkdir -p "$cert_dir"

# ── Remove the previously-trusted CA, if there is one ──────────────────────
# Two paths because `trust anchor --remove` only matches the exact file passed
# in. If ca.crt was already overwritten (or never trusted via this script), we
# fall back to deleting any matching .p11-kit anchor in the system store.
if [ -f "${cert_dir}/ca.crt" ]; then
    sudo trust anchor --remove "${cert_dir}/ca.crt" 2>/dev/null || true
fi
sudo rm -f "/etc/ca-certificates/trust-source/${domain}-ca.p11-kit" \
           "/etc/ca-certificates/trust-source/${domain}-ca."*.p11-kit
sudo update-ca-trust 2>/dev/null || true

cd "$cert_dir"

# ── New CA (10 years — bug fix: openssl req -x509 defaults to 30 days) ─────
openssl genpkey -algorithm RSA -out ca.key
openssl req -x509 -key ca.key -out ca.crt -days 3650 \
    -subj "/CN=$org/O=$org"

# ── New leaf, signed by the CA above ───────────────────────────────────────
openssl genpkey -algorithm RSA -out "$domain".key
openssl req -new -key "$domain".key -out "$domain".csr \
    -subj "/CN=$domain/O=$org"

san_line="DNS:${domain}, DNS:*.${domain}"
for s in "${extra_sans[@]}"; do
    san_line+=", DNS:${s}"
done

openssl x509 -req -in "$domain".csr -days 825 -out "$domain".crt \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -extfile <(cat <<END
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
subjectAltName = ${san_line}
END
    )

sudo trust anchor ca.crt
sudo update-ca-trust 2>/dev/null || true

echo "✓ ${domain} — leaf valid until $(openssl x509 -in "$domain".crt -noout -enddate | cut -d= -f2)"
