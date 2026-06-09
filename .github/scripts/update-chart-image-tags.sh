#!/usr/bin/env bash
# Updates image: lines in Helm values.yaml on the runner filesystem (for git commit).
set -euo pipefail

owner="$(echo "${GITHUB_REPOSITORY_OWNER}" | tr '[:upper:]' '[:lower:]')"
tag="${IMAGE_TAG:?}"
values_file="${VALUES_FILE:-charts/qubership-colly/values.yaml}"

python3 - "${owner}" "${tag}" "${values_file}" <<'PY'
import re
import sys

owner, tag, path = sys.argv[1:4]
services = [
    "envgene-inventory-service",
    "environment-operational-service",
    "ui-service",
]

text = open(path, encoding="utf-8").read()
for svc in services:
    pattern = rf"(image:\s*ghcr\.io/)[^/]+/{re.escape(svc)}:[^\s]*"
    replacement = rf"\g<1>{owner}/{svc}:{tag}"
    text, count = re.subn(pattern, replacement, text)
    if count:
        print(f"Updated {svc} -> ghcr.io/{owner}/{svc}:{tag}")

open(path, "w", encoding="utf-8").write(text)
PY

echo "Synced image tags in ${values_file}"
