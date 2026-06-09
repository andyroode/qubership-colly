#!/usr/bin/env bash
# Computes Docker/Helm image tag(s) for CI. Writes value= and tags= to GITHUB_OUTPUT.
set -euo pipefail

normalize_ref() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's|/|-|g' \
    | sed 's|_|-|g' \
    | sed 's|[^a-z0-9.-]|-|g' \
    | sed 's|-\+|-|g' \
    | sed 's|^-||' \
    | sed 's|-$||'
}

ref_name="${REF_NAME:?}"
ref_type="${REF_TYPE:?}"

if [ "${ref_name}" = "main" ]; then
  image_tag="latest"
  tags="latest, main"
else
  if [ "${ref_type}" = "tag" ]; then
    image_tag=$(normalize_ref "${ref_name#v}")
  else
    image_tag=$(normalize_ref "${ref_name}")
  fi

  max_len=120
  if [ "${#image_tag}" -gt "${max_len}" ]; then
    image_tag="${image_tag:0:${max_len}}"
    image_tag="${image_tag%%-}"
  fi

  tags="${image_tag}"
fi

if [ -n "${EXTRA_TAGS:-}" ]; then
  IFS=',' read -ra extra <<< "${EXTRA_TAGS}"
  for extra_tag in "${extra[@]}"; do
    extra_tag="$(echo "${extra_tag}" | xargs)"
    [ -n "${extra_tag}" ] && tags="${tags}, ${extra_tag}"
  done
fi

{
  echo "value=${image_tag}"
  echo "tags=${tags}"
} >> "${GITHUB_OUTPUT:?}"
