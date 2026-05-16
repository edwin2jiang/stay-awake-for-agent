# Stay Awake for Agent

[English](README.md) | [中文](README.zh-CN.md)

Stay Awake for Agent 是一个为长时间 Agent 工作流准备的 macOS 菜单栏工具。它可以在自动化任务、上传、录屏、远程处理或长时间生成任务期间保持 Mac 唤醒，并提供时间计划、低电量保护、开机自启和实验性盒盖模式。

默认防休眠能力使用 Apple 公开的 IOKit 电源断言 API。盒盖模式被标记为实验性，因为 macOS 没有提供稳定公开的 API 来阻止“合盖触发的睡眠”。

## 功能

- 常规窗口和菜单栏快速入口
- 默认使用无限模式
- 常用时长：15 分钟、30 分钟、1 小时、2 小时、3 小时、6 小时
- 自定义分钟或小时
- 截止日期模式
- 实时倒计时
- 低电量保护，可配置阈值
- 开机自启
- 实验性盒盖模式
- 应用图标和发布打包脚本

## 下载

普通用户建议直接从 GitHub Releases 下载预构建版本：

1. 打开项目的 **Releases** 页面。
2. 下载 `Stay-Awake-for-Agent-macOS-<version>.zip`。
3. 解压文件。
4. 把 `Stay Awake for Agent.app` 移到 `/Applications`。
5. 第一次从 Finder 打开，让 macOS 显示必要的安全提示。

如果 macOS 提示“无法验证开发者”，进入 **系统设置 > 隐私与安全性**，找到 Stay Awake for Agent 对应的安全提示，然后选择 **仍要打开**。未签名的本地构建出现这个提示是正常现象。

## 首次使用

启动后：

1. 使用主 **防休眠** 开关开始或停止会话。
2. 如果不想无限运行，先选择一个时间计划。
3. 笔记本使用电池时建议开启 **低电量保护**。
4. 只有需要登录后自动启动时才开启 **开机自启**。
5. 只有理解下面的系统级影响后才开启 **实验性盒盖模式**。

应用运行时会保留在 macOS 菜单栏中。

## 权限与 macOS 安全设置

### 常规防休眠

常规防休眠不需要管理员权限。应用通过 `IOPMAssertionCreateWithName` 创建 `NoIdleSleep` 电源断言，并在会话停止或应用退出时释放它。

### 实验性盒盖模式

MacBook 合盖通常会触发睡眠。Apple 公开的电源断言 API 不能稳定覆盖这条路径，所以本项目使用：

```bash
pmset -a disablesleep 1
```

macOS 会要求管理员授权。会话停止时，应用会用下面的命令恢复默认行为：

```bash
pmset -a disablesleep 0
```

如果你的 Mac 曾经卡在“合盖不睡眠”的状态，可以手动执行：

```bash
sudo pmset -a disablesleep 0
```

你也可以用下面命令检查当前状态：

```bash
pmset -g
pmset -g assertions
```

## 从源码构建

要求：

- macOS 13 或更高版本
- Xcode Command Line Tools
- Swift Package Manager

构建 app bundle：

```bash
swift build
./Scripts/build-app.sh
```

构建完成后，应用位于：

```bash
./dist/Stay Awake for Agent.app
```

运行：

```bash
open "./dist/Stay Awake for Agent.app"
```

开发时推荐使用：

```bash
./Scripts/restart-app.sh
```

## 创建发布包

为 GitHub Releases 构建 zip 包：

```bash
./Scripts/package-release.sh
```

输出文件位于 `dist/release/`，包括：

- `Stay-Awake-for-Agent-macOS-<version>.zip`
- `Stay-Awake-for-Agent-macOS-<version>.zip.sha256`

把这两个文件上传到 GitHub Release。发布说明可以使用 [RELEASE.md](RELEASE.md) 里的模板。

## 技术说明

稳定防休眠模式使用 `IOPMAssertionCreateWithName` 创建 `NoIdleSleep` 断言，阻止系统因为空闲自动睡眠。

实验性盒盖模式使用 `pmset disablesleep`。这个设置不是 `pmset(1)` 手册里正式公开记录的稳定选项，所以应用把它当成可恢复的会话级覆盖：会话结束、关闭实验开关、应用退出时都会尝试恢复。

## 参考资料

- Apple `caffeinate(8)` 手册
- Apple IOKit 电源断言文档
- Apple Support 闭盖显示模式说明
- [Amphetamine Enhancer](https://github.com/x74353/Amphetamine-Enhancer)
- [Amphetamine 额外说明](https://github.com/x74353/Amphetamine)
- [Fermata](https://github.com/iccir/Fermata)
- [NoSleep issue #52](https://github.com/integralpro/nosleep/issues/52)

## License

MIT
