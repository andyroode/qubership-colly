# Dev build versioning (fork CI)

Single source of truth: `.github/scripts/calculate-image-tag.sh`

## Rules

| Item | Rule |
|------|------|
| Characters | Lowercase `a-z`, digits, **hyphens** only in new tags |
| Branch → prefix | `feature/foo-bar` → `feature-foo-bar` (`/`, `_` → `-`) |
| Dev image tag (branch) | `{prefix}-v{N}` (e.g. `test-test-docker-tags-v5`) |
| Dev image tag (`main`) | `latest` in Helm values; images also tagged `main` |
| Helm chart version | `0.0.0-{image-tag}` (e.g. `0.0.0-test-test-docker-tags-v5`, `0.0.0-latest`) |
| Increment | Per branch prefix in GHCR; legacy `*_vN` tags still count |
| Release | SemVer `X.Y.Z` via **Create Release** workflow (not this scheme) |

## Pull commands

```bash
# Images (all three services share the same tag)
docker pull ghcr.io/<owner>/envgene-inventory-service:<image-tag>

# Chart (helm only — not docker pull)
helm pull oci://ghcr.io/<owner>/colly-stack/qubership-colly --version <chart-version>
```

## Deploy Colly

- `chart-version`: from build summary, or `latest` (newest `0.0.0-*` in GHCR)
- `image-tag`: leave empty if chart already has the correct image tag
