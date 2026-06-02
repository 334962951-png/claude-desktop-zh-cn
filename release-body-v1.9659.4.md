## Claude Desktop 简体中文语言包 v1.9659.4

适配版本：`Claude Desktop 1.9659.4.0`

### 更新内容

- 同步最新 `1.9659.4.0` 资源
- 修复新版前端语言注册逻辑
- 修复运行时中文覆盖顺序
- 修复提权后写入错误用户配置目录的问题
- 补齐主界面和设置页关键中文文案
- 增加正式发布用截图和说明文档

### 已验证

- 首页中文显示正常
- 左侧导航中文显示正常
- 设置菜单中文显示正常
- 设置页主要内容中文显示正常

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
