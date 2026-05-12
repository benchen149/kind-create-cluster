# Claude Code — Project Conventions

## 專案簡介

`kind-create-cluster`：使用 kind 建立本地 Kubernetes 單/多叢集環境，整合 Istio service mesh（sidecar / ambient mode）。

---

## 開發流程

所有功能開發皆走 **GitHub Flow**：

```
issue → feature branch → commit → PR → merge to 1-feat-develop → sync PR → merge to main
```

使用 `/github-flow` slash command 自動引導整個流程。

### Branch 策略

| Branch | 用途 |
|--------|------|
| `main` | 穩定版本，只接受來自 `1-feat-develop` 的 PR merge |
| `1-feat-develop` | 主要開發 branch，feature branch 從此切出、PR 也 merge 回此 |
| `{issue-number}-{slug}` | Feature branch，merge 後自動刪除 |

**絕對不可刪除 `main` 與 `1-feat-develop`。**

---

## 環境設定

新環境第一次執行 `/setup-github-ssh` 完成設定：
- SSH key 產生（必須設定 passphrase）
- GitHub known_hosts fingerprint 驗證
- `gh` CLI 登入（Fine-grained Token，限定單一 repo）
- git config user.email / user.name

### GitHub Token（gh CLI）

- 使用 Fine-grained Personal Access Token，限定此 repo
- 最小權限：Contents / Issues / Pull requests Read & Write、Metadata Read-only
- 有效期：建議 90 天
- 儲存位置：`~/.config/gh/hosts.yml`（明文，不可納入 git）

---

## 版本資訊

| Component | Version | Kubernetes |
|-----------|---------|------------|
| kind | v0.30.0 | v1.34.0 |
| Istio | 1.29.2 | 1.31–1.35 |
| Kiali | v1.49.0 | — |

版本設定檔：`config/config.env`

---

## 常用 Make 指令

| 指令 | 說明 |
|------|------|
| `make c1-sidecar` | 單叢集 + sidecar mode Istio |
| `make c1c2-singlenet` | 雙叢集 single network |
| `make c1c2-install-ewgw` | 雙叢集 + east-west gateway |
| `make clean` | 刪除所有 kind cluster 並清除快取 |

---

## Claude Slash Commands

| Command | 說明 |
|---------|------|
| `/setup-github-ssh` | 新環境一次性設定：SSH key、GitHub known_hosts、gh CLI 登入 |
| `/github-flow` | 完整開發流程（Mode 1：issue → PR → merge；Mode 2：關閉 PR / Issue） |

---

## Issue / PR 標題準則

- **一律使用英文**
- 格式：`<type>: <short description>`
- 範例：`feat: add xxx`、`fix: xxx not working`、`chore: update xxx`

---

## 安全規範

- SSH key passphrase 必須設定，不可留空
- known_hosts 加入前必須對比 GitHub 官方 fingerprint
- `gh` CLI token 不可提交至任何 repo 或 dotfiles
- `~/.ssh/id_ed25519` 不可複製到他處或提交至任何 repo
- Feature branch merge 後自動刪除，`main`、`1-feat-develop` 永遠保留
