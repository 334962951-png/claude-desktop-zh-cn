## Claude Desktop 简体中文语言包 v1.10628.0

适配版本：`Claude Desktop 1.10628.0.0`

### 更新内容

- 同步最新 `1.10628.0.0` 资源
- 更新 `translated-zh-CN` 翻译基线
- 适配当前前端语言注册与运行时覆盖结构
- 修复安装脚本误关闭 Claude Code CLI 的问题
- 更新正式发布文档与截图资源

### 已验证

- 首页中文显示正常
- 左侧导航中文显示正常
- 设置入口与主界面中文显示正常
- `zh-CN` 语言注册已写入当前前端资源
- 运行时中文覆盖顺序已生效

### 截图

首页：

<img src="https://cdn.jsdelivr.net/gh/334962951-png/claude-desktop-zh-cn@main/docs/screenshots/home-overview.png" alt="首页中文界面" width="1200" />

设置页：

<img src="https://cdn.jsdelivr.net/gh/334962951-png/claude-desktop-zh-cn@main/docs/screenshots/settings-overview.jpg" alt="设置页中文界面" width="608" />

### 安装

```powershell
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1
```

### 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Uninstall
```

### 说明

- 目标平台：Windows
- Claude Desktop 更新后可能需要重新安装语言包
- 少量专有名词可能保留英文
