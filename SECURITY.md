# Security

Security tooling, scanning policy, and how to report vulnerabilities.

---

## Reporting a Vulnerability

If you find a security issue, please **do not open a public issue**. Instead:

- Open a private security advisory on GitHub: <https://github.com/sharvinzlife/govee-tv-led-backlight-bluetooth-proxy/security/advisories/new>
- Include reproduction steps, affected file paths, and version/commit SHA

We aim to acknowledge within 5 business days.

---

## Defense Layers

This repo enforces three layers of security checks before code lands:

1. **Pre-commit hooks** — block bad commits at developer's machine
2. **GitHub Actions** — re-run all scans on every push and pull request
3. **Weekly schedule** — re-scan against fresh CVE databases (Mondays 14:00 UTC)

If any layer fails, the code does not ship.

---

## Tools In Use

| Tool | Purpose | Where it runs |
| --- | --- | --- |
| [`detect-secrets`](https://github.com/Yelp/detect-secrets) | Block new committed secrets, baseline-aware | pre-commit + CI |
| [`gitleaks`](https://github.com/gitleaks/gitleaks) | Secret detection across full git history | pre-commit + CI |
| [`trivy`](https://github.com/aquasecurity/trivy) | Filesystem CVE + misconfiguration scan | CI only |
| [`shellcheck`](https://github.com/koalaman/shellcheck) | Bash script lint | pre-commit + CI |
| [`ruff`](https://github.com/astral-sh/ruff) | Python lint + format | pre-commit + CI |
| [`skylos`](https://pypi.org/project/skylos/) | Multi-language dead-code detection (advisory) | CI only |
| [`yamllint`](https://github.com/adrienverge/yamllint) | YAML quality | pre-commit + CI |
| [`markdownlint`](https://github.com/igorshubovych/markdownlint-cli) | Markdown quality | pre-commit + CI |
| [`pre-commit-hooks`](https://github.com/pre-commit/pre-commit-hooks) | Generic safety (private keys, large files, merge markers) | pre-commit + CI |

---

## Local Setup

```bash
# Install pre-commit (one-time, machine-wide)
brew install pre-commit            # macOS
# OR
pipx install pre-commit            # cross-platform
# OR
pip install --user pre-commit

# Install the git hooks for this repo (one-time per clone)
pre-commit install

# Optional — verify everything passes right now
pre-commit run --all-files
```

After `pre-commit install`, every `git commit` is gated on the same hooks CI runs. A failed hook auto-formats fixable issues — re-stage and re-commit.

---

## How To Update Hook Versions

```bash
pre-commit autoupdate
pre-commit run --all-files
git add .pre-commit-config.yaml
git commit -m "chore: bump pre-commit hooks"
```

---

## Baselines

Two baseline files document **known-allowed** findings to prevent re-alerting:

- [`.secrets.baseline`](.secrets.baseline) — managed by `detect-secrets`
- (gitleaks runs without a baseline; allowlist is in [`.gitleaks.toml`](.gitleaks.toml))

When a new finding is genuine but accepted (e.g. a fixed encoding alphabet that looks high-entropy), update the baseline:

```bash
detect-secrets scan --baseline .secrets.baseline
detect-secrets audit .secrets.baseline
```

For one-off allowlisting in code, use the inline pragma:

```python
alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # pragma: allowlist secret
```

---

## What Is Excluded From Scans

These paths are excluded by design — adding new exclusions requires a comment explaining why:

| Path | Reason |
| --- | --- |
| `custom_components/govee_ble_lights/jsons/` | Vendored upstream effect catalogs — huge JSON, high-entropy by nature |
| `assets/` | Static images |
| `.venv/`, `venv/`, `__pycache__/`, `node_modules/`, `dist/`, `build/` | Build artifacts |
| Lockfiles (`*.lock`, `*.sum`, `package-lock.json`, `pnpm-lock.yaml`) | Hashes, not secrets |

---

## What Will Block A Commit

A commit will fail when any of these are detected:

- Trailing whitespace, missing newline at EOF
- Invalid YAML or JSON
- Files larger than 1.5 MB
- Merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
- Private keys (PEM, RSA, OpenSSH, etc.)
- Executables without shebangs (or shebang scripts that aren't executable)
- Mixed line endings
- New high-entropy strings not in `.secrets.baseline`
- Any pattern matching gitleaks's default ruleset
- Bash warnings from `shellcheck`
- Python lint errors from `ruff`
- YAML errors from `yamllint`
- Markdown errors from `markdownlint`

---

## Bypass Policy

There is no `--no-verify` policy. If a hook fails:

1. **Read the failure carefully** — most are auto-fixable
2. **Re-stage** any auto-formatted files
3. **Commit again**

If you genuinely need to bypass for a one-off (rare), open a PR explaining why and re-enable on merge.
