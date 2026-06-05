## Claude Desktop 简体中文语言包 v1.11187.1

适配版本：`Claude Desktop 1.11187.1.0`

### 更新内容

- 同步最新 `1.11187.1.0` 资源
- 更新 `translated-zh-CN` 翻译基线
- 补齐本轮新增的 `ion-dist` 与 `desktop-shell` 中文翻译
- 更新聊天沙箱说明文案，覆盖新的电子表格/计算提示
- 保持安装脚本对当前 `app\resources` 结构的兼容
- 更新正式发布文档与打包配置

### 已验证

- 英文资源提取成功
- 三份翻译文件已覆盖所有当前 key
- 直接在非管理员 PowerShell 中运行安装时，会在 `WindowsApps` 写入阶段因权限不足而失败

### 截图

首页：
<img src="https://cdn.jsdelivr.net/gh/334962951-png/claude-desktop-zh-cn@main/docs/screenshots/home-overview.png" alt="首页中文界面" width="1200" />

设置页：

<img src="https://cdn.jsdelivr.net/gh/334962951-png/claude-desktop-zh-cn@main/docs/screenshots/settings-overview-wide.png" alt="设置页中文界面" width="1200" />

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
- 安装需要管理员权限
- Claude Desktop 升级后可能需要重新安装语言包
- 少量产品名或专有名词可能保留英文
