# ADR-0001：強化 verify-before-commit hook，防 Claude Code `if` fail-open

## 狀態
已採納（Accepted）

## 日期
2026-06-17

## 背景
repo 在 `.claude/settings.json` 註冊了一個 `PreToolUse[Bash]` hook，會在 commit 前跑完整 iOS build + ChapterlyCore 測試（`scripts/verify.sh`，約 56 秒）。設計上只該在 `git commit` 時觸發，靠 hook command object 的 `if` 欄位 gate：

```json
"if": "Bash(git commit *)"
```

先前有一次回歸（commit `fa5bb64`）把 `if` 放成 `matcher` 的同層 sibling，那個位置 Claude Code 會忽略它，導致 verify.sh 在「每一個」Bash 指令都觸發。於是加了 `scripts/check-hooks.sh`（作為 verify.sh 的 Step 0）來守住 `if` 的位置。

2026-06-17 發現即使位置正確，hook 仍在「非 commit」的 Bash 上觸發。調查確認真正根因：

- Claude Code 的 `if` 是真實、有文件記載的欄位，用 permission-rule 語法，對「簡單」指令能正確跳過。
- 但它對「複雜複合指令」會 **fail open** —— `for…do…done` 迴圈、引號內的 `;`（例如 `python3 -c "import sys; ..."`）。已用一條「單一、非並行」且同時含這兩種結構的指令重現，它錯誤地觸發了 verify.sh。
- 在 hook context 裡，這個約 56 秒的執行接著被 timeout 砍掉，於是每次都往 agent context 注入一段假的 `verify.sh failed` tail —— 延遲與 token 的雙重浪費。
- verify.sh 本身從沒壞：直接跑 exit 0、會跑到 `=== Verify complete ===`。所謂「紅」純粹是誤觸 + timeout 砍掉造成的。

`check-hooks.sh` 只驗證 config 的「形狀」（`if` 字串與位置），抓不到 runtime 的 fail-open。設計意圖 ≠ 運行事實。

## 決策
保留 `if`，**並且**在 hook command 內加一道 internal stdin guard，採 defense-in-depth。command 在跑 verify.sh 前：

1. 讀 tool input —— `CMD=$(jq -r '.tool_input.command // empty')`，且
2. 只有當 `CMD` 含真正的 `git commit` 子指令才繼續
   （`grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+commit([[:space:]]|$)'`），否則 `exit 0`。

`check-hooks.sh` 也擴充為斷言這道 guard 存在（command 必須引用 `.tool_input.command` 且含 `git`），讓它無法默默回歸。

grep pattern 與全域 advisory `verify_before_commit.sh` 用的同一條，commit 偵測行為一致。

## 考慮過的替代方案

### 只靠 `if`（現狀）
- 否決：`if` 對複雜複合指令 fail open，這正是 bug。

### 拿掉 `if`，只靠 internal stdin guard
- 優點：單一事實來源；guard 本身就夠 robust。
- 缺點：失去 fast-path。有 `if` 時，Claude Code 對簡單的非 commit 指令會「完全跳過」hook（不 spawn process）；沒有 `if`，guard 的 `jq`+`grep` 會在每個 Bash 呼叫都 spawn。
- 否決：保留 `if` 當便宜的 fast-path；guard 只當 fail-open 的安全網。

### 改用原生 git `pre-commit` hook（`.git/hooks`）
- 優點：完全不依賴 Claude Code；任何 committer 都會觸發。
- 缺點：預設不進版控；可用 `--no-verify` 繞過；不與 `CLAUDE.md` 描述的 agent 診斷流程整合。
- 暫緩：超出本次修復範圍；若非 agent 的 commit 變多再重新評估。

### 縮短 verify.sh 或調低 timeout
- 否決：治標（慢的執行被砍）不治本（非 commit 誤觸）。真 commit 時 verify.sh 仍必須 build + test。

## 後果
- verify.sh 只在真正的 `git commit` 跑，不論 Claude Code 怎麼 parse `if`。fail-open 路徑上 guard 會在毫秒內 exit，而不是觸發約 56 秒的 build。
- 每個漏過 `if` 的 Bash 呼叫多一次 `jq`+`grep`（可忽略）。
- `check-hooks.sh` 現在只要 `if` gate 或 internal guard 任一缺失就會讓 build 失敗 —— 兩者都必須保留。
- hook config 在 session 啟動時載入：**此變更需重啟 Claude Code session 才生效。**
- 仍可能有 false positive：指令字面含 `git commit`（例如 `echo "git commit"`）會多跑一次 verify，但無害。可接受 —— 與既有 advisory hook 同樣的權衡。
- 若 Codex 端有對應的 pre-commit hook 鏡像了這個 gate（見 `AGENTS.md`），它可能有同樣的 fail-open，應加同樣的 guard。
