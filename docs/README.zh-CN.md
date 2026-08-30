# Codex 用量菜单栏

这是一个轻量 macOS 菜单栏小工具，按参考图的形式展示你的 Codex 用量。

- 菜单栏标题显示 `Codex 97%` 这种周剩余用量格式
- 账号和套餐读取自 `~/.codex/auth.json`
- 剩余用量实验性地读取自 Codex 桌面端当前使用的 ChatGPT 后端接口；该接口不是公开、稳定的开发者 API，未来可能变化或停止工作
- 用量统计读取自 `~/.codex/state_5.sqlite`
- 下拉菜单显示 1 周剩余用量，以及今日、近 7 天、累计本机 token 用量和对话数量
- 支持刷新、打开 Codex、退出

## 启动

在当前目录运行：

```bash
./run-codex-usage-menu.sh
```

第一次启动会编译 `CodexUsageMenu.swift`，然后在 macOS 菜单栏显示官方接口返回的剩余用量。

## 修改顶部剩余用量

正常情况下点菜单里的「刷新」会自动读取官方接口并更新菜单栏标题。

如果接口临时失败，状态栏会显示 `Codex --%`，本机 token 统计仍可继续读取。

设置保存在 `~/Library/Application Support/CodexUsageMenu/settings.json`。常见字段：

- `weeklyRemainingPercent`: 1 周剩余百分比
- `weeklyReset`: 1 周重置日期
- `autoRefreshMinutes`: 自动刷新间隔

说明：顶部百分比优先来自 Codex 官方接口；本机能稳定读取的 token 统计仍会自动刷新并显示在下拉菜单里。
