# Release Notes

## v1.10628.0

适配版本：`Claude Desktop 1.10628.0.0`

### 本次更新

- 同步 Claude Desktop `1.10628.0.0` 的资源文件
- 更新 `translated-zh-CN` 翻译基线
- 适配当前前端语言注册逻辑
- 修复运行时 i18n 合并顺序，确保本地 `zh-CN` 优先生效
- 修复安装脚本误关闭 Claude Code CLI 的问题
- 更新正式发布说明与打包配置

### 已验证内容

- 首页中文显示正常
- 左侧导航中文显示正常
- 设置菜单中文显示正常
- 设置页主要内容中文显示正常
- `locale` 可正确写入当前用户配置

### 翻译统计

- `ion-dist`: `15519`
- `desktop-shell`: `406`
- `statsig`: `65`
- `ion-dist` 新增：`495`
- `desktop-shell` 新增：`9`
- `statsig` 新增：`19`

### 安装方式

```powershell
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1
```

### 卸载方式

```powershell
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Uninstall
```

### 说明

- 本版本目标平台为 Windows
- Claude Desktop 后续升级后，可能需要重新安装或重新适配
- 少量专有名词可能继续保留英文
