# claude-desktop-zh-cn

Claude Desktop 简体中文语言包项目。

[GitHub 仓库](https://github.com/334962951-png/claude-desktop-zh-cn) · [更新日志](./CHANGELOG.md)

为 Claude Desktop (Windows) 的界面语言增加简体中文。已同步到 Claude Desktop 1.8555.0.0 的资源文本，并在 3P 模式下测试可用。

使用 GLM5.1 / 自动翻译辅助 + 人工校对，尽量减少机翻味。
当前版本基于 1.8555.0.0 重新提取资源并合并旧翻译；新增 key 暂以英文保留，后续可继续人工补译。

## 项目状态

- 当前适配版本：Claude Desktop `1.8555.0.0`
- 当前翻译条目：
  `ion-dist` `14648`
  `desktop-shell` `373`
  `statsig` `46`
- 本次新增未补译条目：`781`
  清单见 `new-ion-dist-keys-1.8555.0.txt`
- 历史备份和旧版本更新产物已归档到 `archive/`

## 特性

- 支持一键安装和卸载简体中文语言包
- 自动提取 Claude Desktop 当前安装版本资源路径
- 自动注册 `zh-CN` 语言并切换本地 `locale`
- 保留历史备份，便于在 Claude 更新后继续增量维护
- 内置英文原文提取流程，方便后续升级版本时继续补译

<img width="75%" alt="image" src="https://github.com/user-attachments/assets/16c330db-6df9-43ca-a333-61172057ad6e" />

## 快速导航

- 当前中文翻译目录：`translated-zh-CN/`
- 当前英文提取目录：`extracted-en-US/`
- 当前版本更新摘要：`update-1.8555.0-summary.json`
- 当前版本新增 key：`new-ion-dist-keys-1.8555.0.txt`
- 历史备份与旧版本产物：`archive/`


## 前提

- 已安装 [Claude Desktop](https://claude.ai/download)
- Windows 10 / 11

## 快速安装

1. 以 git clone 或 zip 的形式下载本仓库
2. 完全关闭 Claude Desktop
3. 双击 `安装中文语言包.bat`。如果界面卡住，可以按几下回车键。
4. 在管理员权限弹窗中点击「是」
5. 等待安装完成
6. 打开 Claude，在左下角设置中切换语言为中文

## 快速卸载

1. 完全关闭 Claude Desktop
2. 双击 `卸载中文语言包.bat`
3. 在管理员权限弹窗中点击「是」
4. 等待卸载完成



## Cowork 使用教程

### 一、已有官方付费订阅

1. 打开 Claude Desktop。
2. 登录你的 Claude 账号。
3. 登录后，在左侧或主界面找到 **Cowork** 即可

### 二、3P 模式

无付费订阅的账号登录后无法使用 Cowork，需使用 3P 模式并设置自己的 API 端点。

1. 打开 Claude Desktop，不要登录 Claude 账号

2. 打开左上角菜单（三个横杠）：

```text
帮助 → 故障排除 → 启用开发者模式 (Help → Troubleshooting → Enable Developer Mode)
```
如果左上角菜单点不开，可以先点击邮箱输入框，再按 `Tab` 切换选定到菜单按钮并回车。

4. 开启开发者模式后，打开：

```text
开发者 → 配置第三方推理 (Developer → Configure third-party inference)
```

5. 在 connection 页面填写你的第三方接口信息，包括：

```text
Gateway base URL：https://你的 base URL。 
Gateway API key：你的密钥
Model list：依次添加你想要的模型。如果不添加，Claude 会自动获取。
```
<img width="50%" alt="image" src="https://github.com/user-attachments/assets/1e275fdf-1aac-4f4b-a9ad-23b71b49f101" />

注意base URL 结尾不要带 `/v1`，否则会导致自动获取模型失败，仅显示legacy 模型。只有本地 API 端点可以使用http，非本地 API 端点要求https。
无须勾选"Skip login-mode chooser"。
可按需在 Telemetry & updates 标签关闭前两项遥测。


6. 填好后点击：

```text
本地应用 (Apply locally)
```

7. Claude Desktop 会重启，重启后正常使用 Cowork 即可。


## 命令行用法（PowerShell）

```powershell
# 安装（默认行为，需管理员权限）
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1

# 卸载，恢复英文
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Uninstall

# 安装/卸载后不自动重启
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -NoRestart

# 提取英文原文（开发/更新翻译用）
powershell -ExecutionPolicy Bypass -File .\LanguagePack.ps1 -Extract
```

## 工作原理

安装脚本会做三件事：

1. **写入翻译文件** — 将 `translated-zh-CN/` 下的 3 个 JSON 复制到 Claude 的 resources 目录
2. **注册 zh-CN 语言** — 在 Claude 的 JS 包中补丁语言列表，添加 `"zh-CN"`
3. **切换配置** — 将 Claude 的 `config.json` 中 `locale` 设为 `"zh-CN"`

卸载时反向操作：删除翻译文件、从备份恢复原始 JS、重置 locale 为 `"en-US"`。

## 目录结构

```
├── 安装中文语言包.bat                  # 一键安装入口
├── 卸载中文语言包.bat                  # 一键卸载入口
├── LanguagePack.ps1                    # 主脚本
├── translated-zh-CN/                   # 当前使用的中文翻译
│   ├── ion-dist/zh-CN.json             # 主界面 (14,648 条)
│   ├── desktop-shell/zh-CN.json        # 桌面外壳 (373 条)
│   └── statsig/zh-CN.json              # 功能开关 (46 条)
├── extracted-en-US/                    # 当前版本提取的英文原文
├── translation-template/               # 待翻译模板
├── new-ion-dist-keys-1.8555.0.txt      # 当前版本新增未补译 key
├── update-1.8555.0-summary.json        # 当前版本更新摘要
└── archive/                            # 历史备份与旧版本更新产物
    ├── backups/
    └── updates/
```

## 维护说明

- 根目录保留当前活跃版本 `1.8555.0.0` 的文件。
- `archive/backups/` 保存历史备份目录。
- `archive/updates/` 保存旧版本的新增 key 清单和更新摘要。
- 后续升级新版本时，建议保留最新版本在根目录，旧版本继续移动到 `archive/updates/`。

## 常见问题

**安装后界面没变中文？**
- 确认 Claude Desktop 已重启
- 检查 Claude 设置 → 语言是否已设置为「中文(简体)」

**脚本报权限错误？**
- 会自动请求管理员权限，若被系统拦截请手动允许
- WindowsApps 目录受系统保护，`takeown` + `icacls` 需要管理员权限

**Claude 更新后中文消失？**
- Claude 更新会覆盖 resources 目录，需要重新运行安装脚本
- 如果新版 JS 变量名变化，脚本会自动尝试正则匹配

## 开发者说明

- 更新翻译时，可运行 `LanguagePack.ps1 -Extract` 提取最新英文原文
- 当前仓库默认维护最新活跃版本，旧版本更新产物移动到 `archive/updates/`
- 当前仓库默认保留历史备份，便于对比资源变化和回退

## 路线建议

- 继续补译 `new-ion-dist-keys-1.8555.0.txt` 中的 781 个新增条目
- 后续 Claude Desktop 更新后，先运行 `LanguagePack.ps1 -Extract`，再复用现有中文条目进行增量升级

## 许可

仅供个人学习使用。Claude Desktop 是 Anthropic 的产品，本项目与 Anthropic 无关。

本项目采用 [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-nc-sa/4.0)（CC BY-NC-SA 4.0）授权。

你可以在非商业目的下复制、分发、修改本项目，但必须保留原作者署名、注明修改内容，并以相同协议继续发布衍生版本。

## 感谢
- 简体中文包原型：https://linux.do/t/topic/2040184 by [RICK](https://linux.do/u/lbls888)
- 使用教程： [开启Claude 3P模式与自定义推理端点](https://linux.do/t/topic/2032192) & [使用自定义模型映射](https://linux.do/t/topic/2034445)
- [Linux Do 社区](https://linux.do/)：[![](https://ldo.betax.dev/badge/community)](https://linux.do/)。学AI，上L站。
