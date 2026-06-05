# 发布清单

## 发版前确认

- 已确认适配的 Claude Desktop 版本为 `1.11187.1.0`
- 已运行提取脚本并确认 `extracted-en-US/` 为当前版本资源
- 已确认 `translated-zh-CN/` 覆盖全部当前 key
- 已确认 `README.md`、`CHANGELOG.md`、`RELEASE.md` 已更新
- 已确认 [release-body-v1.11187.1.md](./release-body-v1.11187.1.md) 可直接用于 GitHub Release
- 已确认截图资源存在于 `docs/screenshots/`
- 已确认 `LanguagePack.ps1` 仍可正确定位 `app\resources`
- 已确认安装需要管理员权限；非管理员直接运行会在 `WindowsApps` 写入阶段失败

## 建议提交内容

当前版本建议至少包含：

- `LanguagePack.ps1`
- `README.md`
- `CHANGELOG.md`
- `RELEASE.md`
- `release-body-v1.11187.1.md`
- `docs/screenshots/`
- `translated-zh-CN/`
- `extracted-en-US/`
- `translation-template/`
- `update-1.11187.1-summary.json`
- `new-*-1.11187.1.txt`
- `changed-*-1.11187.1.txt`

## 建议 Git 提交信息

```text
release: prepare v1.11187.1
```

## 建议 Git tag

```text
v1.11187.1
```

## 建议 GitHub Release 标题

```text
v1.11187.1 - Claude Desktop 简体中文语言包
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
- 以管理员身份运行安装脚本
- 确认 Claude 首页中文正常
- 确认设置页中文正常
- 运行卸载脚本并确认恢复英文
