# Release Notes

## v1.9659.4

适配版本：`Claude Desktop 1.9659.4.0`

### 本次更新

- 同步 Claude Desktop `1.9659.4.0` 的资源文件
- 更新 `translated-zh-CN` 翻译基线
- 修复新版前端语言注册逻辑
- 修复运行时 i18n 合并顺序，确保本地 `zh-CN` 优先生效
- 修复管理员提权后写错用户配置目录的问题
- 增加对新版语言数组结构的兼容补丁
- 补齐主界面与设置页关键中文文案
- 新增本地截图资源，便于发布展示

### 已验证内容

- 首页中文显示正常
- 左侧导航中文显示正常
- 设置菜单中文显示正常
- 设置页主要内容中文显示正常
- `locale` 可正确写入当前用户配置

### 翻译统计

- `ion-dist`: `15209`
- `desktop-shell`: `397`
- `statsig`: `46`
- `ion-dist` 新增：`825`
- `desktop-shell` 新增：`24`
- `statsig` 新增：`0`

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
