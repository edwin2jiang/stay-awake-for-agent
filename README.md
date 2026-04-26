# Agent Duty

一个轻量的 macOS 菜单栏防休眠工具，专门为 Loom 等 Agent 工作流准备，让电脑在长任务期间保持在线。

## 已实现

- 一键开启/关闭防休眠
- 定时模式
- 实时倒计时
- 无限模式
- 开机自启
- 实验性盒盖模式开关
- 正式应用图标与 `.icns` 打包资源

## 技术方案

### 稳定能力

应用通过 `IOPMAssertionCreateWithName` 创建 `NoIdleSleep` 断言，阻止系统因空闲而自动休眠。这部分能力属于 macOS 官方电源管理机制的一部分，适合做常规“防睡眠”。

### 实验性盒盖模式

盒盖后继续运行并维持音乐播放，不属于稳定公开 API 能力。当前项目采用一个更现实的折中方案：

- 常规防休眠：使用官方电源断言
- 盒盖防休眠：通过 `pmset -a disablesleep 1` 请求系统关闭盒盖睡眠
- 恢复默认行为：会话结束后执行 `pmset -a disablesleep 0`

由于 `pmset disablesleep` 需要管理员权限，而且它本身并不是 `pmset(1)` 手册中公开记录的正式设置项，所以这里明确标记为“实验性”。

## 为什么盒盖模式只能做成实验性

调研结果大致是：

1. Apple 官方公开的防休眠接口无法覆盖“合盖导致的睡眠”。
2. `caffeinate` 的 `-s` 选项官方手册明确写明只在接交流电时有效。
3. Apple 官方闭盖使用说明依赖“接电 + 外接显示器 + 外接键鼠”这一类闭盖工作场景。
4. GitHub 上现成项目普遍依赖以下两类手段：
   - 私有 IOKit SPI
   - `pmset disablesleep`
5. 这说明“做成软件”是可行的，但很难做到完全官方、完全无权限、完全无机型差异。

## 参考资料

- Apple `caffeinate(8)` 手册
- Apple IOKit 电源断言文档
- Apple Support: closed-display / 外接显示器相关说明
- [Amphetamine Enhancer](https://github.com/x74353/Amphetamine-Enhancer)
- [Amphetamine 额外说明](https://github.com/x74353/Amphetamine)
- [Fermata](https://github.com/iccir/Fermata)
- [NoSleep issue #52](https://github.com/integralpro/nosleep/issues/52)

## 构建

```bash
swift build
./Scripts/build-icon.sh
./Scripts/build-app.sh
```

构建完成后，应用位于：

```bash
./dist/AgentDuty.app
```

## 运行

```bash
open ./dist/AgentDuty.app
```

首次启用“实验性盒盖模式”时，系统会弹出管理员授权。

首次启用“开机自启”时，如果系统要求批准，可点击应用内的“打开登录项设置”完成授权。
