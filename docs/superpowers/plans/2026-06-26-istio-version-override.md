# Inline `istio=` Version Override Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow `make c1-sidecar istio=1.13.5` to automatically select the correct kind/K8s/kubectl versions without editing `config/config.env`.

**Architecture:** A new `config/version-matrix.sh` holds the vetted version mapping. A new `scripts/apply_version_override.sh` reads the matrix, validates the requested version, then writes a temporary `config/.override.env`. `config/config.env` sources this override file in-place (after base vars, before derived paths) so all child scripts inherit it transparently. Makefile targets call the override script before `main.sh`.

**Tech Stack:** Bash, GNU Make, kind, kubectl

## Global Constraints

- `config/.override.env` must be gitignored — never committed
- Override source line in `config/config.env` must appear after line 15 (`kubectl_version=`) and before line 20 (`filtered_version_kiali=...`), so derived paths like `FOLDER_PATH_istio` are computed with the overridden `istio_version`
- `apply_version_override.sh` must always delete stale `.override.env` at startup (even when called with no args), so bare `make` commands reliably restore defaults
- `make -C "$abspath" clean` is called automatically when override version ≠ current `config.env` `istio_version`
- Version matrix entries: `1.13.5 → v0.14.0 / kindest/node:v1.24.0 / v1.24.17`, `1.24.0 → v0.30.0 / kindest/node:v1.31.12 / v1.31.6`, `1.29.4 → v0.30.0 / kindest/node:v1.34.0 / v1.34.8`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `config/version-matrix.sh` | Lookup table: istio_version → kind/node/kubectl |
| Create | `scripts/apply_version_override.sh` | Validate, resolve, write `.override.env`, auto-clean |
| Modify | `config/config.env` line 15→16 | Insert one `source .override.env` line |
| Modify | `Makefile` | Add `@bash scripts/apply_version_override.sh "$(istio)"` to `c1-sidecar` and `c1c2-singlenet` |
| Modify | `.gitignore` | Add `config/.override.env` |
| Modify | `README.md` line 51–52 | Add `1.13.5` row to vetted combinations table |

---

### Task 1: Version matrix

**Files:**
- Create: `config/version-matrix.sh`

**Interfaces:**
- Produces:
  - `resolve_istio_versions(version: string) → "kind_version node_image kubectl_version"` (space-separated, stdout) or returns 1
  - `supported_istio_versions() → "1.13.5  1.24.0  1.29.4"` (stdout)

- [ ] **Step 1: Create `config/version-matrix.sh`**

```bash
#!/usr/bin/env bash
# Returns space-separated: kind_version node_image kubectl_version
# Exits 1 for unknown versions.

resolve_istio_versions() {
    case "$1" in
        1.13.5) echo "v0.14.0 kindest/node:v1.24.0 v1.24.17"  ;;
        1.24.0) echo "v0.30.0 kindest/node:v1.31.12 v1.31.6"   ;;
        1.29.4) echo "v0.30.0 kindest/node:v1.34.0 v1.34.8"    ;;
        *)      return 1 ;;
    esac
}

supported_istio_versions() {
    echo "1.13.5  1.24.0  1.29.4"
}
```

- [ ] **Step 2: 驗證 matrix 函數正確性**

```bash
source config/version-matrix.sh

# 已知版本應回傳正確欄位
result=$(resolve_istio_versions 1.13.5)
echo "$result"
# 預期輸出：v0.14.0 kindest/node:v1.24.0 v1.24.17

result=$(resolve_istio_versions 1.29.4)
echo "$result"
# 預期輸出：v0.30.0 kindest/node:v1.34.0 v1.34.8

# 未知版本應回傳 exit 1
resolve_istio_versions 9.99.9; echo "exit=$?"
# 預期輸出：exit=1

# 支援清單
supported_istio_versions
# 預期輸出：1.13.5  1.24.0  1.29.4
```

- [ ] **Step 3: Commit**

```bash
git add config/version-matrix.sh
git commit -m "feat: add version matrix for istio → kind/k8s/kubectl mapping"
```

---

### Task 2: Override resolver script

**Files:**
- Create: `scripts/apply_version_override.sh`

**Interfaces:**
- Consumes:
  - `resolve_istio_versions()` from `config/version-matrix.sh`
  - `supported_istio_versions()` from `config/version-matrix.sh`
  - `$1` — istio version string (may be empty)
- Produces: `config/.override.env` (written when `$1` non-empty, deleted when empty or on script start)

- [ ] **Step 1: Create `scripts/apply_version_override.sh`**

```bash
#!/usr/bin/env bash
set -e

abspath=$(cd "$(dirname "$0")/.."; pwd)
OVERRIDE_FILE="$abspath/config/.override.env"

# Always wipe stale override first (next bare `make` restores defaults)
rm -f "$OVERRIDE_FILE"

# No override requested
[[ -z "$1" ]] && exit 0

source "$abspath/config/version-matrix.sh"

resolved=$(resolve_istio_versions "$1") || {
    echo "Error: unsupported Istio version '$1'"
    echo "Supported versions: $(supported_istio_versions)"
    exit 1
}

read -r kind_ver node_img kubectl_ver <<< "$resolved"
istio_label="${1//./-}"

# Auto-clean when switching away from the current default
current_istio=$(sed -n 's/^istio_version=\([^[:space:]#]*\).*/\1/p' \
    "$abspath/config/config.env" | head -1)
if [[ -n "$current_istio" && "$current_istio" != "$1" ]]; then
    echo "Istio version changed ($current_istio → $1), running make clean …"
    make -C "$abspath" clean
fi

cat > "$OVERRIDE_FILE" <<EOF
istio_version=$1
export istio_label=$istio_label
kind_version=$kind_ver
node_image="$node_img"
kubectl_version=$kubectl_ver
EOF

echo "Version override: Istio $1 / kind $kind_ver / K8s ${node_img##*:} / kubectl $kubectl_ver"
```

- [ ] **Step 2: 驗證 — 無參數時刪除 override**

先建一個假的 `.override.env`，確認腳本清除後正常 exit 0：

```bash
echo "test" > config/.override.env
bash scripts/apply_version_override.sh
echo "exit=$?"
ls config/.override.env 2>/dev/null && echo "FAIL: file should be gone" || echo "PASS: file deleted"
# 預期：exit=0，PASS: file deleted
```

- [ ] **Step 3: 驗證 — 已知版本寫入正確 override**

```bash
bash scripts/apply_version_override.sh 1.13.5
echo "exit=$?"
cat config/.override.env
```

預期輸出：
```
Version override: Istio 1.13.5 / kind v0.14.0 / K8s v1.24.0 / kubectl v1.24.17
exit=0
istio_version=1.13.5
export istio_label=1-13-5
kind_version=v0.14.0
node_image="kindest/node:v1.24.0"
kubectl_version=v1.24.17
```

- [ ] **Step 4: 驗證 — 未知版本報錯**

```bash
bash scripts/apply_version_override.sh 9.99.9
echo "exit=$?"
ls config/.override.env 2>/dev/null && echo "file exists" || echo "file absent"
```

預期輸出（stderr/stdout 混合）：
```
Error: unsupported Istio version '9.99.9'
Supported versions: 1.13.5  1.24.0  1.29.4
exit=1
file absent
```

- [ ] **Step 5: 清除測試產物並 commit**

```bash
rm -f config/.override.env
chmod +x scripts/apply_version_override.sh
git add scripts/apply_version_override.sh
git commit -m "feat: add apply_version_override.sh to resolve and apply istio version"
```

---

### Task 3: Patch `config/config.env`

**Files:**
- Modify: `config/config.env` (insert 1 line between line 15 and line 17)

**Interfaces:**
- Consumes: `config/.override.env` (optionally present)
- Produces: all scripts that source `config/config.env` now inherit the override transparently

- [ ] **Step 1: 在 `kubectl_version=` 與 `cluster_mode=` 之間插入 override source**

在 `config/config.env` 的這段：

```
kubectl_version=v1.34.8 # 建議對齊 ...
                                          ← 在此空行插入
cluster_mode=multi
```

插入後變成：

```
kubectl_version=v1.34.8 # 建議對齊 ...

[ -f "$abspath/config/.override.env" ] && source "$abspath/config/.override.env"

cluster_mode=multi
```

- [ ] **Step 2: 驗證 override 被 config.env 繼承，且衍生路徑正確**

```bash
# 先寫一個測試用 override
cat > config/.override.env <<'EOF'
istio_version=1.13.5
export istio_label=1-13-5
kind_version=v0.14.0
node_image="kindest/node:v1.24.0"
kubectl_version=v1.24.17
EOF

# Source config.env 並檢查變數
abspath=$(pwd)
source config/config.env
echo "istio_version=$istio_version"
echo "kind_version=$kind_version"
echo "FOLDER_PATH_istio=$FOLDER_PATH_istio"
echo "FILE_PATH_istio=$FILE_PATH_istio"
```

預期輸出：
```
istio_version=1.13.5
kind_version=v0.14.0
FOLDER_PATH_istio=/tmp/download/istio-1.13.5
FILE_PATH_istio=<abspath>/tools/istio/operator/cluster-legacy.yaml
```

（`cluster-legacy.yaml` 因為 1.13 < 1.29）

- [ ] **Step 3: 驗證無 override 時 config.env 行為不變**

```bash
rm -f config/.override.env
abspath=$(pwd)
source config/config.env
echo "istio_version=$istio_version"
echo "FOLDER_PATH_istio=$FOLDER_PATH_istio"
```

預期輸出：
```
istio_version=1.29.4
FOLDER_PATH_istio=/tmp/download/istio-1.29.4
```

- [ ] **Step 4: 清除測試產物並 commit**

```bash
rm -f config/.override.env
git add config/config.env
git commit -m "feat: source .override.env in config.env before derived paths"
```

---

### Task 4: Patch Makefile

**Files:**
- Modify: `Makefile`

**Interfaces:**
- Consumes: `scripts/apply_version_override.sh`
- Produces: `make c1-sidecar istio=X` and `make c1c2-singlenet istio=X` work end-to-end

- [ ] **Step 1: 修改 `c1-sidecar` 與 `c1c2-singlenet` 加入 override 呼叫**

目前：
```makefile
c1-sidecar:
	@sed -i 's/^cluster_mode=.*/cluster_mode=single/' config/config.env
	bash scripts/main.sh

c1c2-singlenet:
	@sed -i 's/^cluster_mode=.*/cluster_mode=multi/' config/config.env
	bash scripts/main.sh
```

改為：
```makefile
c1-sidecar:
	@sed -i 's/^cluster_mode=.*/cluster_mode=single/' config/config.env
	@bash scripts/apply_version_override.sh "$(istio)"
	bash scripts/main.sh

c1c2-singlenet:
	@sed -i 's/^cluster_mode=.*/cluster_mode=multi/' config/config.env
	@bash scripts/apply_version_override.sh "$(istio)"
	bash scripts/main.sh
```

- [ ] **Step 2: 驗證 dry-run 顯示正確命令序列**

```bash
make -n c1-sidecar istio=1.13.5
```

預期輸出（順序）：
```
sed -i 's/^cluster_mode=.*/cluster_mode=single/' config/config.env
bash scripts/apply_version_override.sh "1.13.5"
bash scripts/main.sh
```

```bash
make -n c1-sidecar
```

預期輸出：
```
sed -i 's/^cluster_mode=.*/cluster_mode=single/' config/config.env
bash scripts/apply_version_override.sh ""
bash scripts/main.sh
```

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "feat: pass istio= override to make targets via apply_version_override.sh"
```

---

### Task 5: gitignore + README

**Files:**
- Modify: `.gitignore`
- Modify: `README.md` (line 51–52)

- [ ] **Step 1: 加入 `.gitignore` 條目**

在 `.gitignore` 尾端加入：
```
config/.override.env
```

驗證：
```bash
echo "test" > config/.override.env
git status
# config/.override.env 不應出現在 untracked files
git status | grep override && echo "FAIL" || echo "PASS: correctly ignored"
rm config/.override.env
```

- [ ] **Step 2: README 補 1.13.5 vetted combination**

在 `README.md` 的版本對照表：

目前（line 51–52）：
```markdown
   | v0.30.0 | 1.29.4 | 1-29-4 | `kindest/node:v1.34.0` | 1.31 – 1.35 | v1.34.8 |
   | v0.30.0 | 1.24.0 | 1-24-0 | `kindest/node:v1.31.12` | 1.28 – 1.31 | v1.31.x |
```

改為（新增最後一行）：
```markdown
   | v0.30.0 | 1.29.4 | 1-29-4 | `kindest/node:v1.34.0`  | 1.31 – 1.35 | v1.34.8  |
   | v0.30.0 | 1.24.0 | 1-24-0 | `kindest/node:v1.31.12` | 1.28 – 1.31 | v1.31.6  |
   | v0.14.0 | 1.13.5 | 1-13-5 | `kindest/node:v1.24.0`  | 1.20 – 1.24 | v1.24.17 |
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore README.md
git commit -m "chore: gitignore .override.env and add 1.13.5 to README version matrix"
```
