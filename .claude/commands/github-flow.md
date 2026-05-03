# GitHub Flow 自動化

執行完整的 GitHub issue → branch → PR → merge 工作流程。

## 使用方式

```
/github-flow
```

執行後會依序引導你完成以下步驟。

## 執行流程

### Step 1：收集資訊
詢問使用者：
- **Issue 標題**（例如：`feat: add xxx`，**標題一律使用英文**）
- **Issue 描述**（問題背景、預計異動）
- **Branch slug**（例如：`add-xxx`，會自動加上 issue 編號變成 `{number}-add-xxx`）
- **目標 base branch**（預設 `1-feat-develop`）

### Step 2：開 GitHub Issue
使用 GitHub API 建立 issue，取得 issue 編號。

```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/benchen149/kind-create-cluster/issues \
  -d "{\"title\": \"$TITLE\", \"body\": \"$BODY\"}"
```

### Step 3：建立並切換 branch（自動執行，不需使用者確認）
取得 issue 編號後立即執行，無需等待使用者確認。

```bash
git checkout $BASE_BRANCH
git pull origin $BASE_BRANCH
git checkout -b {issue-number}-$SLUG
```

### Step 4：等待使用者完成改動
branch 建立完成後，提示使用者目前所在 branch 及需要修改的檔案，等待使用者完成程式碼修改後告知 Claude 繼續。

### Step 5：Commit & Push
```bash
git add <changed files>
git commit -m "feat/fix/chore: $TITLE

$DESCRIPTION

Closes #{issue-number}"
git push origin {issue-number}-$SLUG
```

### Step 6：開 Pull Request
使用 GitHub API 建立 PR，base 指向 `$BASE_BRANCH`。

### Step 7：確認是否 merge
詢問使用者是否直接 merge，若是則：
- merge PR（`merge_method: merge`）
- sync local base branch（`git pull origin $BASE_BRANCH`）
- 自動刪除 feature branch（local + remote），無需詢問使用者
- **絕對不可刪除** `1-feat-develop`、`main` 等長期 branch，只刪除格式為 `{issue-number}-$SLUG` 的 feature branch

```bash
git branch -d {issue-number}-$SLUG
git push origin --delete {issue-number}-$SLUG
```

## Issue 標題準則

- **一律使用英文**撰寫 issue 標題
- 格式：`<type>: <short description>`，例如 `feat: add xxx`、`fix: xxx not working`、`chore: update xxx`

## 注意事項

- `GITHUB_TOKEN` 需要有 Contents / Issues / Pull requests 的 Read and write 權限
- 若環境沒有 `GITHUB_TOKEN`，流程開始前會提示設定
- base branch 預設為 `1-feat-develop`，若要 merge 到 `main` 請在 Step 1 指定
- `1-feat-develop`、`main` 等長期 branch 不在自動刪除範圍內
