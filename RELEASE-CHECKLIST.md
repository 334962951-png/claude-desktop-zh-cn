# 发布清单

## 发版前确认

- 已确认适配的 Claude Desktop 版本号
- 已运行安装脚本并验证主界面中文正常
- 已验证设置菜单和设置页主要中文内容
- 已确认 `README.md`、`CHANGELOG.md`、`RELEASE.md` 已更新
- 已确认 `release-body-v1.9659.4.md` 可直接用于 GitHub Release
- 已确认截图资源存在于 `docs/screenshots/`
- 已确认 `LanguagePack.ps1` 安装与卸载都可执行

## 建议提交内容

当前版本建议至少包含：

- `LanguagePack.ps1`
- `README.md`
- `CHANGELOG.md`
- `RELEASE.md`
- `release-body-v1.9659.4.md`
- `docs/screenshots/`
- `translated-zh-CN/`
- `extracted-en-US/`
- `translation-template/`
- `update-1.9659.4-summary.json`
- `new-*-1.9659.4.txt`

## 建议 Git 提交信息

```text
release: prepare v1.9659.4
```

## 建议 Git tag

```text
v1.9659.4
```

## 建议 GitHub Release 标题

```text
v1.9659.4 - Claude Desktop 简体中文语言包
```

## GitHub Release 附件建议

建议上传一个打包好的 zip，至少包含：

- `LanguagePack.ps1`
- `安装中文语言包.bat`
- `卸载中文语言包.bat`
- `translated-zh-CN/`
- `README.md`
- `LICENSE`
- `NOTICE`

## 发布后回归检查

- 从 Release 下载 zip
- 在干净目录解压
- 管理员运行安装脚本
- 确认 Claude 首页中文正常
- 确认设置页中文正常
- 运行卸载脚本并确认恢复英文
