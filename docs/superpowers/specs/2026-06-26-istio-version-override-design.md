# Design: Inline `istio=` Version Override for Make Targets

**Issue:** #87
**Branch:** 87-istio-version-override
**Date:** 2026-06-26

---

## 問題背景

切換 Istio 版本需手動修改 `config/config.env` 的 5 個欄位（`istio_version`、`istio_label`、`kind_version`、`node_image`、`kubectl_version`），容易出錯，且未先 `make clean` 會讓 pretask 靜默沿用舊版 tarball。

## 目標 UX

```bash
make c1-sidecar istio=1.13.5
make c1c2-singlenet istio=1.24.0
```

- `istio=` 為一次性 override，**不修改 config.env**
- 未傳 `istio=` 時維持原行為
- 傳入不在 matrix 的版本 → 報錯並列出支援清單，停止執行
- 傳入版本與 config.env 目前值不同 → 自動先執行 clean

---

## 架構

```
make c1-sidecar istio=1.13.5
        │
        ▼
  [Makefile] 偵測到 istio= 變數
        │
        ├─ 不在 matrix → 印錯誤 + 支援清單 → exit 1
        │
        ├─ 版本與 config.env 現有 istio_version 不同 → make clean
        │
        ├─ 查 config/version-matrix.sh → 解析 kind/node/kubectl
        │
        ├─ 寫入 config/.override.env（暫存，gitignored）
        │
        ├─ bash scripts/main.sh
        │       ↓
        │   source config/config.env
        │       ↓（config.env 最後一行）
        │   source config/.override.env  ← 蓋掉版本相關變數
        │
        └─ 清除 config/.override.env（無論成功/失敗皆清除）
```

---

## 修改/新增檔案

| 檔案 | 動作 | 說明 |
|------|------|------|
| `config/version-matrix.sh` | 新增 | 版本對照表 |
| `scripts/apply_version_override.sh` | 新增 | 解析 matrix、寫 override、觸發 clean |
| `config/config.env` | 修改 1 行 | 最後加 source `.override.env` |
| `Makefile` | 修改 | 各 target 加 `istio=` 處理 |
| `.gitignore` | 修改 | 加入 `config/.override.env` |
| `README.md` | 修改 | vetted combinations 補 1.13.5 |

---

## `config/version-matrix.sh`

```bash
# 回傳格式：kind_version node_image kubectl_version
resolve_istio_versions() {
    case "$1" in
        1.13.5) echo "v0.14.0 kindest/node:v1.24.0 v1.24.17" ;;
        1.24.0) echo "v0.30.0 kindest/node:v1.31.12 v1.31.6"  ;;
        1.29.4) echo "v0.30.0 kindest/node:v1.34.0 v1.34.8"   ;;
        *)      return 1 ;;
    esac
}

supported_istio_versions() {
    echo "1.13.5  1.24.0  1.29.4"
}
```

`istio_label` 從 `istio_version` 計算（`.` → `-`），不進 matrix。

---

## `scripts/apply_version_override.sh`

邏輯：
1. 無論如何，**先刪除** `config/.override.env`（清除上次的殘留）
2. `$1` 空 → return 0（bare make 恢復 config.env 預設）
3. `source config/version-matrix.sh`；呼叫 `resolve_istio_versions "$1"`
4. 失敗 → 印錯誤 + `supported_istio_versions` → exit 1
5. 讀取 config.env 目前 `istio_version`；若不同 → `make -C "$abspath" clean`
6. 計算 `istio_label="${1//./-}"`
7. 寫入 `config/.override.env`：
   ```
   istio_version=1.13.5
   istio_label=1-13-5
   kind_version=v0.14.0
   node_image=kindest/node:v1.24.0
   kubectl_version=v1.24.17
   ```

---

## `config/config.env` 修改

在檔案最後加一行：

```bash
[ -f "$abspath/config/.override.env" ] && source "$abspath/config/.override.env"
```

---

## Makefile 修改

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

Makefile 不負責刪除 `.override.env`。cleanup 發生在「下一次 make 的 `apply_version_override.sh` 執行開頭」。

### c1c2-install-ewgw 的行為

```
make c1c2-install-ewgw istio=1.13.5
  └─ [prereq] c1c2-singlenet
       ├─ apply_version_override.sh "1.13.5"  → 清舊 override → 寫新 override
       └─ main.sh → source config.env → source .override.env → 使用 1.13.5 ✓
  └─ install_eastwestgateway.sh → source config.env → source .override.env → 使用 1.13.5 ✓
```

`.override.env` 留至下次 make 時被清除（gitignored）。

---

## 錯誤訊息格式

```
Error: unsupported Istio version '1.99.0'
Supported versions: 1.13.5  1.24.0  1.29.4
```

---

## 不在此 issue 範圍

- ambient mode 的 istio= 支援（目前無 ambient make target）
- 動態新增版本至 matrix（手動維護 version-matrix.sh）
