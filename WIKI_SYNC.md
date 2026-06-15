# WIKI_SYNC

> 來源 project: Chapterly
> 產出日期: 2026-06-13（session 6 更新）
> 同步目標: knowledge-wiki/wiki-pages/専案管理/

使用方式：在 knowledge-wiki session 中執行「専案管理 update」，將以下內容分別寫入對應路徑。

---

## errors/（踩過的坑）

**error_swift-observable-didset-self-assignment-recursion.md 建議內容：**

```markdown
## 症狀
Swift `@Observable` class 的 property 使用 `didSet { property = clamp(property) }` 這種 plain Swift class 常見寫法時，UI 操作會造成 app 凍結或 stack overflow。

## 根因
Observation macro 會把 stored property 改寫成 computed accessor。`didSet` 內再次指派同一 property 會重入 setter，形成 setter -> didSet -> setter 的無限遞迴。這和 plain class 的安全 idiom 行為不同。

## 修法
把可觀察 state 拆成 private tracked storage + public computed property。computed setter 只對 `newValue` clamp 一次並寫入 backing storage，不要在 observer 裡自我賦值。

## 預防措施
- 在 `@Observable` type 中避免 `didSet`/`willSet` 內 assign 同一 property。
- 需要 clamp/normalize 時用 explicit computed setter over private storage。
- 對 Swift macro 改寫後的語意保持警覺，不要直接套 plain class idiom。

## 出現過的專案
- Chapterly（2026-06-13）：`ReaderPreferences.fontSize` / `lineSpacing` 造成 reader prefs panel 與 Settings Stepper 凍結；修復 commit `95ffd71`。
```

**error_fb-idb-python314.md 建議內容：**

```markdown
## 症狀
執行任何 `idb` CLI 指令立刻崩潰：
RuntimeError: There is no current event loop in thread 'MainThread'
（Traceback 指向 fb-idb 內部 asyncio.get_event_loop()）

## 根因
fb-idb 1.1.7 在 Python 3.14 下呼叫 `asyncio.get_event_loop()`；
Python 3.14 移除了隱式 event loop 建立，改為強制拋出 RuntimeError。

## 修法
pipx uninstall fb-idb
pipx install fb-idb --python python3.12

Python 3.12 會發出 DeprecationWarning，但正常執行。
（確認版本：idb-companion 1.1.8 + fb-idb 1.1.7 on Python 3.12.13）

## 預防措施
- fb-idb 目前是 maintenance mode；新 Python 版本容易再次相容性破壞
- 安裝時明確 `--python python3.12`（或最後一個確認相容的版本）
- 若 Python 升級後 idb 壞掉：先查此條目，再用 driver A（computer-use MCP）作為備援

## 出現過的專案
- Chapterly（2026-06-13）
```

---

## patterns/（可複用模式）

本次無新增。

---

## adr/（架構決策）

本次無新增。
