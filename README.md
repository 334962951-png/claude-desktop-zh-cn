# Claude Desktop 简体中文语言包

Claude Desktop Windows 版简体中文语言包项目。
当前已适配到 `Claude Desktop 1.11187.1.0`。

[更新日志](./CHANGELOG.md) | [发布说明](./RELEASE.md)

## 项目说明

这个项目为 Claude Desktop 的 Windows 安装包补充简体中文界面资源，并通过脚本自动完成：

- 写入 `zh-CN` 翻译文件
- 注册 `zh-CN` 语言
- 修复运行时语言覆盖顺序
- 将本地 `locale` 切换为 `zh-CN`
- 支持一键卸载并恢复英文

当前版本已验证：

- 主界面中文可用
- 设置菜单中文可用
- 设置页主要内容中文可用
- 兼容 Claude Desktop `1.11187.1.0`

## 截图

首页：

<img src="https://cdn.jsdelivr.net/gh/334962951-png/claude-desktop-zh-cn@main/docs/screenshots/home-overview.png" alt="首页中文界面" width="1200" />

设置页：

<img src="https://cdn.jsdelivr.net/gh/334962951-png/claude-desktop-zh-cn@main/docs/screenshots/settings-overview-wide.png" alt="设置页中文界面" width="1200" />

## 当前版本状态

- 适配版本：`1.11187.1.0`
- `ion-dist`：`15724` 条
- `desktop-shell`：`407` 条
- `statsig`：`65` 条
- 本轮 `ion-dist` 新增条目：`358`
- 本轮 `desktop-shell` 新增条目：`2`
- 本轮 `statsig` 新增条目：`0`
- 当前仍保留少量英文专有名词或产品名

详细统计见 [update-1.11187.1-summary.json](./update-1.11187.1-summary.json)。

## 快速开始

### 安装

1. 下载或克隆本仓库。
2. 完全关闭 Claude Desktop。
3. 双击 [安装中文语言包.bat](./安装中文语言包.bat)。
4. 在管理员权限弹窗中选择“是”。
5. 等待脚本执行完成；Claude 会自动重启。

也可以直接运行 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1
```

### 卸载

1. 完全关闭 Claude Desktop。
2. 双击 [卸载中文语言包.bat](./卸载中文语言包.bat)。
3. 在管理员权限弹窗中选择“是”。

或运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Uninstall
```

## 命令行用法

```powershell
# 安装中文语言包
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1

# 卸载中文语言包
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Uninstall

# 安装/卸载后不自动重启 Claude
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -NoRestart

# 提取当前已安装版本的英文原文
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Extract
```

## 构建发布包

仓库内置了一个简单的发布打包脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
```

默认会在 `dist/` 下生成：

- `claude-desktop-zh-cn-1.11187.1/`
- `claude-desktop-zh-cn-1.11187.1.zip`

## 工作原理

安装脚本会执行以下步骤：

1. 查找当前已安装的 Claude Desktop 路径
2. 获取 `resources` 目录写入权限
3. 复制 `translated-zh-CN` 中的翻译文件到 Claude 安装目录
4. 修改前端资源，注册 `zh-CN` 并修复运行时语言覆盖顺序
5. 更新当前用户配置文件中的 `locale=zh-CN`
6. 重启 Claude Desktop

卸载时会反向恢复：

1. 删除中文翻译文件
2. 恢复已备份的前端资源
3. 将 `locale` 重置为 `en-US`

## 目录结构

```text
.
├─ LanguagePack.ps1
├─ 安装中文语言包.bat
├─ 卸载中文语言包.bat
├─ translated-zh-CN/
│  ├─ ion-dist/zh-CN.json
│  ├─ desktop-shell/zh-CN.json
│  └─ statsig/zh-CN.json
├─ extracted-en-US/
├─ translation-template/
├─ docs/screenshots/
├─ archive/
├─ update-1.11187.1-summary.json
├─ new-ion-dist-keys-1.11187.1.txt
├─ new-desktop-shell-keys-1.11187.1.txt
└─ new-statsig-keys-1.11187.1.txt
```

## 更新与维护

当 Claude Desktop 升级后，通常需要重新适配一次。建议流程：

1. 更新 Claude Desktop
2. 运行 `LanguagePack.ps1 -Extract`
3. 对比新版 `en-US` 资源
4. 合并旧翻译并补齐新增 key
5. 更新 `translated-zh-CN/`
6. 重新执行安装并验证界面

历史版本资料和备份保存在 [archive](./archive/)。

## 已知说明

- 项目当前仅以 Windows 版 Claude Desktop 为目标
- 少量品牌名、字体名、专有名词可能保留英文
- Claude Desktop 更新后可能覆盖安装目录，需要重新执行安装
- 如果新版前端结构变化较大，安装脚本中的前端补丁规则也需要同步更新
- 安装脚本需要管理员权限；在非管理员 PowerShell 中直接运行会因 `WindowsApps` 写入权限不足而失败

## 常见问题

### 安装后没有变成中文？

- 确认 Claude Desktop 已完全关闭后再安装
- 确认脚本执行时已弹出并同意管理员权限
- 确认安装日志中出现：

```text
已注册语言: index-*.js
已启用运行时中文优先: index-*.js
已设置 locale=zh-CN
```

### Claude 更新后语言包失效？

这是正常情况。Claude 更新可能会：

- 覆盖 `resources` 目录
- 替换前端 JS 文件名和结构
- 新增或改动翻译 key

重新运行安装脚本即可；如果仍有问题，需要针对新版本做重新适配。

### 为什么还会有少量英文？

常见原因有两类：

- 专有名词刻意保留，例如字体名、品牌名、产品名
- 当前翻译文件里仍有个别未优先处理的条目

## 许可证

本项目采用 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)。
Claude Desktop 是 Anthropic 的产品，本项目为第三方中文化项目，与 Anthropic 官方无关。

## 致谢

- 中文包原始思路参考 Linux Do 社区相关讨论
- 现版本在旧版翻译基础上完成资源重提取、增量合并和脚本适配
