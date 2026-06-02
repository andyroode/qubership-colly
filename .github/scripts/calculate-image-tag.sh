#!/usr/bin/env bash
# Computes Docker image tag(s) and dev Helm chart version for CI.
# Writes value=, tags=, chart_version= to GITHUB_OUTPUT.
set -euo pipefail

normalize_ref() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's|/|_|g' | sed 's|[^a-z0-9_.-]|_|g' | sed 's|_*$||'
}

ref_name="${REF_NAME:?}"
ref_type="${REF_TYPE:?}"
owner="${GITHUB_REPOSITORY_OWNER,,}"

if [ "${ref_name}" = "main" ]; then
  image_tag="latest"
  tags="latest, main"
  chart_version="main"
else
  if [ "${ref_type}" = "tag" ]; then
    prefix=$(normalize_ref "${ref_name#v}")
  else
    prefix=$(normalize_ref "${ref_name}")
  fi

  max_prefix_len=120
  if [ "${#prefix}" -gt "${max_prefix_len}" ]; then
    prefix="${prefix:0:${max_prefix_len}}"
    prefix="${prefix%%_}"
  fi

  sample_image="envgene-inventory-service"
  repo_path="${owner}/${sample_image}"
  max_ver=0

  if [ -n "${GH_TOKEN:-}" ]; then
    ghcr_token="$(curl -fsSL -u "${GITHUB_ACTOR}:${GH_TOKEN}" \
      "https://ghcr.io/token?scope=repository:${repo_path}:pull" 2>/dev/null | jq -r '.token // empty' || true)"
    if [ -n "${ghcr_token}" ]; then
      existing_tags="$(curl -fsSL -H "Authorization: Bearer ${ghcr_token}" \
        "https://ghcr.io/v2/${repo_path}/tags/list" 2>/dev/null | jq -r '.tags[]? // empty' || true)"
      while IFS= read -r tag; do
        [ -z "${tag}" ] && continue
        case "${tag}" in
          "${prefix}"_v*)
            ver="${tag#${prefix}_v}"
            if [[ "${ver}" =~ ^[0-9]+$ ]] && [ "${ver}" -gt "${max_ver}" ]; then
              max_ver="${ver}"
            fi
            ;;
        esac
      done <<< "${existing_tags}"
    fi
  fi

  next_ver=$((max_ver + 1))
  image_tag="${prefix}_v${next_ver}"
  tags="${image_tag}"
  chart_version="${image_tag}"
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
  echo "chart_version=${chart_version}"
} >> "${GITHUB_OUTPUT:?}"
