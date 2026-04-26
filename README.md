# Stay Awake for Agent

一个为 Loom 等 Agent 工作流准备的 macOS 防休眠工具。它同时提供常规窗口和菜单栏模式，让长任务期间的电脑保持在线，同时把时间计划和电量保护做得更直观。

## 已实现

- 默认使用“无限”模式
- 常用定时阶梯选项：15 分钟、30 分钟、1 小时、2 小时、3 小时、6 小时
- 自定义时长输入，支持分钟 / 小时
- 截止日期模式，可直接选具体日期和时间
- 实时倒计时
- 低电量保护，可配置阈值，默认 20%
- 开机自启
- 常规窗口模式
- 菜单栏快速入口
- 实验性盒盖模式
- 已配置应用图标与 `.icns` 打包资源

## 交互方式

- 第一次启动时，会直接出现主窗口，方便理解和配置
- 运行中也会保留菜单栏入口，方便快速开关或重新打开主窗口

## 技术方案

### 稳定能力

应用通过 `IOPMAssertionCreateWithName` 创建 `NoIdleSleep` 断言，阻止系统因空闲而自动休眠。这部分属于 macOS 官方公开的电源管理能力，适合做常规防休眠。

### 电量保护

应用会周期性读取当前内置电池状态；如果启用了低电量保护，并且当前处于电池供电且电量低于阈值，会自动结束防休眠会话。

### 实验性盒盖模式

盒盖后继续运行并维持音乐播放，不属于稳定公开 API 能力。当前项目采用一个更现实的折中方案：

- 常规防休眠：使用官方电源断言
- 盒盖防休眠：通过 `pmset -a disablesleep 1` 请求系统关闭盒盖睡眠
- 恢复默认行为：会话结束后执行 `pmset -a disablesleep 0`

由于 `pmset disablesleep` 需要管理员权限，而且它本身并不是 `pmset(1)` 手册中公开记录的正式设置项，所以这里明确标记为“实验性”。

## 为什么盒盖模式只能做成实验性

调研结论大致是：

1. Apple 官方公开的防休眠接口无法覆盖“合盖导致的睡眠”
2. `caffeinate` 的 `-s` 选项官方手册明确写明只在接交流电时有效
3. Apple 官方闭盖使用说明依赖“接电 + 外接显示器 + 外接键鼠”这一类 closed-display 使用场景
4. GitHub 上现成项目普遍依赖以下两类手段：
   - 私有 IOKit SPI
   - `pmset disablesleep`

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
./dist/Stay Awake for Agent.app
```

## 运行

```bash
open "./dist/Stay Awake for Agent.app"
```

首次启用“实验性盒盖模式”时，系统会弹出管理员授权。

首次启用“开机自启”时，如果系统要求批准，可点击应用内的“打开登录项设置”完成授权。
