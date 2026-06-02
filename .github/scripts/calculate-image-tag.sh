#!/usr/bin/env bash
# Dev Docker / Helm tag calculator. Standard: .github/dev-versioning.md
# Outputs: value (image tag), tags (comma-separated for docker-action), chart_version
set -euo pipefail

normalize_ref() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's|/|-|g' | sed 's|_|-|g' | sed 's|[^a-z0-9.-]|-|g' | sed 's|-*$||' | sed 's|-\+|-|g'
}

# Legacy GHCR tags used underscores; only used to preserve v{N} increment.
normalize_ref_legacy() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's|/|_|g' | sed 's|[^a-z0-9_.-]|_|g' | sed 's|_*$||'
}

normalize_extra_tag() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | xargs | sed 's|_|-|g'
}

helm_chart_version_from_image_tag() {
  echo "0.0.0-${1}"
}

write_step_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  local ref_name="$1"
  {
    echo "### Dev artifact versions"
    echo ""
    echo "| | Tag |"
    echo "|--|-----|"
    echo "| Docker (all components) | \`${image_tag}\` |"
    if [ "${ref_name}" = "main" ]; then
      echo "| Docker (additional push) | \`main\` |"
    fi
    echo "| Helm chart (OCI) | \`${chart_version}\` |"
    echo ""
    echo "Convention: image \`{branch}-v{N}\` (hyphens), chart \`0.0.0-{image-tag}\`. See [.github/dev-versioning.md](.github/dev-versioning.md)."
    if [ "${ref_name}" != "main" ]; then
      echo ""
      echo "Docker push tags: \`${tags}\`"
    fi
  } >> "${GITHUB_STEP_SUMMARY}"
}

ref_name="${REF_NAME:?}"
ref_type="${REF_TYPE:?}"
owner="${GITHUB_REPOSITORY_OWNER,,}"

if [ "${ref_name}" = "main" ]; then
  image_tag="latest"
  tags="latest, main"
else
  if [ "${ref_type}" = "tag" ]; then
    prefix=$(normalize_ref "${ref_name#v}")
    legacy_prefix=$(normalize_ref_legacy "${ref_name#v}")
  else
    prefix=$(normalize_ref "${ref_name}")
    legacy_prefix=$(normalize_ref_legacy "${ref_name}")
  fi

  max_prefix_len=120
  if [ "${#prefix}" -gt "${max_prefix_len}" ]; then
    prefix="${prefix:0:${max_prefix_len}}"
    prefix="${prefix%%-}"
    legacy_prefix="${legacy_prefix:0:${max_prefix_len}}"
    legacy_prefix="${legacy_prefix%%_}"
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
        ver=""
        case "${tag}" in
          "${prefix}"-v*)
            ver="${tag#${prefix}-v}"
            ;;
          "${legacy_prefix}"_v*)
            ver="${tag#${legacy_prefix}_v}"
            ;;
        esac
        if [[ -n "${ver}" && "${ver}" =~ ^[0-9]+$ ]] && [ "${ver}" -gt "${max_ver}" ]; then
          max_ver="${ver}"
        fi
      done <<< "${existing_tags}"
    fi
  fi

  next_ver=$((max_ver + 1))
  image_tag="${prefix}-v${next_ver}"
  tags="${image_tag}"
fi

chart_version="$(helm_chart_version_from_image_tag "${image_tag}")"

if [ -n "${EXTRA_TAGS:-}" ]; then
  IFS=',' read -ra extra <<< "${EXTRA_TAGS}"
  for extra_tag in "${extra[@]}"; do
    extra_tag="$(normalize_extra_tag "${extra_tag}")"
    [ -n "${extra_tag}" ] && tags="${tags}, ${extra_tag}"
  done
fi

{
  echo "value=${image_tag}"
  echo "tags=${tags}"
  echo "chart_version=${chart_version}"
} >> "${GITHUB_OUTPUT:?}"

write_step_summary "${ref_name}"
