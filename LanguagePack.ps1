[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Extract,
    [switch]$NoRestart,
    [switch]$PauseAtEnd,
    [switch]$SkipElevation,
    [string]$OriginalLocalAppData,
    [string]$OriginalUserProfile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$packDir = Join-Path $scriptDir "translated-zh-CN"
$backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-zh-cn-backup"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Administrator {
    param(
        [string[]]$Arguments = @()
    )

    if (Test-IsAdministrator) {
        return
    }

    $argumentList = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`""
    ) + $Arguments

    if ($env:LOCALAPPDATA) {
        $argumentList += @("-OriginalLocalAppData", "`"$($env:LOCALAPPDATA)`"")
    }

    if ($env:USERPROFILE) {
        $argumentList += @("-OriginalUserProfile", "`"$($env:USERPROFILE)`"")
    }

    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argumentList | Out-Null
    exit
}

function Wait-BeforeExit {
    if (-not $PauseAtEnd) {
        return
    }

    Write-Host ""
    [void](Read-Host "按回车关闭窗口")
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Find-ClaudePath {
    try {
        $pkg = Get-AppxPackage -Name Claude -ErrorAction Stop |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation -and (Test-Path -LiteralPath $pkg.InstallLocation)) {
            return $pkg.InstallLocation
        }
    }
    catch {
    }

    try {
        $deployments = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deployments" -ErrorAction Stop |
            Where-Object { $_.PSChildName -like "Claude*" } |
            Sort-Object PSChildName -Descending

        foreach ($deployment in $deployments) {
            $candidate = Join-Path ${env:ProgramFiles} "WindowsApps\$($deployment.PSChildName)"
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }
    catch {
    }

    $windowsApps = Join-Path ${env:ProgramFiles} "WindowsApps"
    if (Test-Path -LiteralPath $windowsApps) {
        $candidate = Get-ChildItem -LiteralPath $windowsApps -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "Claude*" } |
            Sort-Object Name -Descending |
            Select-Object -First 1

        if ($candidate) {
            return $candidate.FullName
        }
    }

    return $null
}

function Get-ResourcesPath {
    param(
        [Parameter(Mandatory = $true)][string]$ClaudePath
    )

    $resourcesPath = Join-Path $ClaudePath "app\resources"
    if (Test-Path -LiteralPath $resourcesPath) {
        return $resourcesPath
    }

    return $null
}

function Grant-WriteAccess {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $takeownArgs = @("/f", $Path, "/a")
        if ($item.PSIsContainer) {
            $takeownArgs += @("/r", "/d", "Y")
        }

        & takeown.exe @takeownArgs | Out-Null

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($identity) {
            & icacls.exe $Path "/grant" "${identity}:(F)" "/t" "/c" | Out-Null
        }
    }
    catch {
    }
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    [System.IO.Directory]::CreateDirectory($backupDir) | Out-Null
    $backupPath = Join-Path $backupDir (Split-Path $Path -Leaf)
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        return
    }

    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
}

function Get-PreferredLocalAppDataRoots {
    $roots = New-Object 'System.Collections.Generic.List[string]'

    if ($OriginalLocalAppData) {
        $roots.Add($OriginalLocalAppData)
    }

    if ($env:LOCALAPPDATA) {
        $roots.Add($env:LOCALAPPDATA)
    }

    if ($OriginalUserProfile) {
        $roots.Add((Join-Path $OriginalUserProfile "AppData\Local"))
    }

    if ($env:USERPROFILE) {
        $roots.Add((Join-Path $env:USERPROFILE "AppData\Local"))
    }

    return $roots |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd("\") } |
        Select-Object -Unique
}

function Patch-JsLanguage {
    param(
        [Parameter(Mandatory = $true)][string]$ResourcesPath
    )

    $assetsDir = Join-Path $ResourcesPath "ion-dist\assets\v1"
    if (-not (Test-Path -LiteralPath $assetsDir -PathType Container)) {
        Write-Host "  [警告] 未找到 assets 目录，跳过 JS 补丁" -ForegroundColor Yellow
        return $false
    }

    $indexFiles = Get-ChildItem -LiteralPath $assetsDir -Filter "index-*.js" -File -ErrorAction SilentlyContinue
    if (-not $indexFiles) {
        Write-Host "  [警告] 未找到 index-*.js，跳过 JS 补丁" -ForegroundColor Yellow
        return $false
    }

    $allJsFiles = Get-ChildItem -LiteralPath $assetsDir -Filter "*.js" -File -ErrorAction SilentlyContinue
    $fallbackReplacements = [ordered]@{
        'defaultMessage:"New task",id:"K4O03zh0vo"'       = 'defaultMessage:"新建任务",id:"K4O03zh0vo"'
        'defaultMessage:"Projects",id:"UxTJRaKagI"'       = 'defaultMessage:"项目",id:"UxTJRaKagI"'
        'defaultMessage:"Scheduled",id:"cXAlMRerxW"'      = 'defaultMessage:"已排期",id:"cXAlMRerxW"'
        'defaultMessage:"Live artifacts",id:"fo4LT2foY3"' = 'defaultMessage:"实时构件",id:"fo4LT2foY3"'
        'defaultMessage:"Customize",id:"TXpOBiuxud"'      = 'defaultMessage:"自定义",id:"TXpOBiuxud"'
        'defaultMessage:"Pinned",id:"fWZYP5U4xZ"'         = 'defaultMessage:"已置顶",id:"fWZYP5U4xZ"'
        'defaultMessage:"Recents",id:"wA4FIMmtlS"'        = 'defaultMessage:"最近",id:"wA4FIMmtlS"'
        'defaultMessage:"View all",id:"pFK6bJU0EM"'       = 'defaultMessage:"查看全部",id:"pFK6bJU0EM"'
        'defaultMessage:"View all projects",id:"dQKgzxReOT"' = 'defaultMessage:"查看全部项目",id:"dQKgzxReOT"'
        'const rp={chat:"New chat",cowork:"New task",code:"New session"}' = 'const rp={chat:"New chat",cowork:"新建任务",code:"New session"}'
        '{id:"projects",surface:"projects",icon:"Projects",label:"Projects",modes:["chat","cowork"]}' = '{id:"projects",surface:"projects",icon:"Projects",label:"项目",modes:["chat","cowork"]}'
        '{id:"scheduled",surface:"scheduled",icon:"Clock",label:"Scheduled",gate:"scheduled",modes:["cowork","code"]}' = '{id:"scheduled",surface:"scheduled",icon:"Clock",label:"已排期",gate:"scheduled",modes:["cowork","code"]}'
        '{id:"cowork-artifacts",href:$t,icon:"Artifacts",label:"Live artifacts",gate:"cowork-artifacts",modes:["cowork"]}' = '{id:"cowork-artifacts",href:$t,icon:"Artifacts",label:"实时构件",gate:"cowork-artifacts",modes:["cowork"]}'
        '{id:"customize",surface:"customize",icon:"Tool",label:"Customize"}' = '{id:"customize",surface:"customize",icon:"Tool",label:"自定义"}'
        'const lp="Recents"' = 'const lp="最近"'
        'z5t={recents:"Recents",shared:"Shared"}' = 'z5t={recents:"最近",shared:"Shared"}'
        'children:["View all",Bo.jsx(Ht,{name:"CaretRight",size:"xsmall"})]' = 'children:["查看全部",Bo.jsx(Ht,{name:"CaretRight",size:"xsmall"})]'
        'Bo.jsx(Vt,{collapsed:r,onToggle:i,children:"Pinned"})' = 'Bo.jsx(Vt,{collapsed:r,onToggle:i,children:"已置顶"})'
    }
    $debugTargets = @(
        'label:"项目"',
        'label:"已排期"',
        'label:"实时构件"',
        'label:"自定义"',
        'const lp="最近"',
        'cowork:"新建任务"',
        '查看全部'
    )

    $exactLanguageArrays = @(
        @{
            Old = 'Mz=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]'
            New = 'Mz=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"]'
        },
        @{
            Old = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID",];'
            New = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN",];'
        },
        @{
            Old = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"];'
            New = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"];'
        },
        @{
            Old = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID",];'
            New = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN",];'
        },
        @{
            Old = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"];'
            New = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"];'
        }
    )
    $languageRegexes = @(
        [regex]'((?:\w+)=\["en-US"(?:,"[^"]+")+)(,?)\]',
        [regex]'((?:\w+)=\["en-US"(?:,"[^"]+")+)(,?);',
        [regex]'(const\s+[A-Za-z_$][\w$]*="en-US",[A-Za-z_$][\w$]*=\["en-US"(?:,"[^"]+")+)(,?)\]',
        [regex]'(const\s+[A-Za-z_$][\w$]*="en-US",[A-Za-z_$][\w$]*=\["en-US"(?:,"[^"]+")+)(,?);'
    )
    $mergeExactOld = 'const f={...u,...l?.messages};c(f,l?.gates??[],n?r:void 0)'
    $mergeExactNew = 'const f={...l?.messages,...u};c(f,l?.gates??[],n?r:void 0)'
    $mergeRegex = [regex]'const\s+([A-Za-z_$][\w$]*)=\{\.\.\.([A-Za-z_$][\w$]*),\.\.\.([A-Za-z_$][\w$]*)\?\.messages\};([A-Za-z_$][\w$]*)\(\1,\3\?\.gates\?\?\[\],'
    $mergePatchedRegex = [regex]'const\s+[A-Za-z_$][\w$]*=\{\.\.\.[A-Za-z_$][\w$]*\?\.messages,\.\.\.[A-Za-z_$][\w$]*\};[A-Za-z_$][\w$]*\([A-Za-z_$][\w$]*,[A-Za-z_$][\w$]*\?\.gates\?\?\[\],'

    $patched = $false

    foreach ($jsFile in $indexFiles) {
        Grant-WriteAccess -Path $jsFile.FullName

        $content = [System.IO.File]::ReadAllText($jsFile.FullName)
        $originalContent = $content
        $languageMatched = $false
        $mergeMatched = $false

        if ($content.Contains('"zh-CN"')) {
            Write-Host "  已注册语言: $($jsFile.Name)"
            $patched = $true
            $languageMatched = $true
        }

        if (-not $languageMatched) {
            foreach ($languageArray in $exactLanguageArrays) {
                if ($content.Contains($languageArray.Old)) {
                    $content = $content.Replace($languageArray.Old, $languageArray.New)
                    $languageMatched = $true
                    $patched = $true
                    Write-Host "  已注册语言: $($jsFile.Name)"
                    break
                }
            }

            if (-not $languageMatched) {
                foreach ($languageRegex in $languageRegexes) {
                    $newContent = $languageRegex.Replace($content, '$1,"zh-CN"$2]', 1)
                    if ($newContent -ne $content) {
                        $content = $newContent
                        $languageMatched = $true
                        $patched = $true
                        Write-Host "  已注册语言(正则): $($jsFile.Name)"
                        break
                    }
                }
            }
        }

        if ($content.Contains($mergeExactNew) -or $mergePatchedRegex.IsMatch($content)) {
            Write-Host "  已启用运行时中文优先: $($jsFile.Name)"
            $patched = $true
            $mergeMatched = $true
        }
        else {
            if ($content.Contains($mergeExactOld)) {
                $content = $content.Replace($mergeExactOld, $mergeExactNew)
                $mergeMatched = $true
                $patched = $true
                Write-Host "  已启用运行时中文优先: $($jsFile.Name)"
            }
            else {
                $newContent = $mergeRegex.Replace($content, 'const $1={...$3?.messages,...$2};$4($1,$3?.gates??[],', 1)
                if ($newContent -ne $content) {
                    $content = $newContent
                    $mergeMatched = $true
                    $patched = $true
                    Write-Host "  已启用运行时中文优先(正则): $($jsFile.Name)"
                }
            }
        }

        if ($content -ne $originalContent) {
            Backup-File -Path $jsFile.FullName
            Write-Utf8File -Path $jsFile.FullName -Content $content
        }

        if (-not $languageMatched) {
            Write-Host "  [警告] 未匹配到语言列表: $($jsFile.Name) (Claude 可能已更新)" -ForegroundColor Yellow
        }

        if (-not $mergeMatched) {
            Write-Host "  [警告] 未匹配到运行时覆盖补丁: $($jsFile.Name) (Claude 可能已更新)" -ForegroundColor Yellow
        }
    }

    foreach ($jsFile in $allJsFiles) {
        Grant-WriteAccess -Path $jsFile.FullName

        $content = [System.IO.File]::ReadAllText($jsFile.FullName)
        $originalContent = $content
        $replacementCount = 0

        foreach ($pair in $fallbackReplacements.GetEnumerator()) {
            if ($content.Contains($pair.Value)) {
                continue
            }

            if ($content.Contains($pair.Key)) {
                $content = $content.Replace($pair.Key, $pair.Value)
                $replacementCount += 1
            }
        }

        if ($content -ne $originalContent) {
            Backup-File -Path $jsFile.FullName
            Write-Utf8File -Path $jsFile.FullName -Content $content
            Write-Host "  已更新默认文案回退: $($jsFile.Name) (+$replacementCount)"
            $patched = $true
            if ($jsFile.Name -like "cc3d*.js") {
                $hits = @()
                foreach ($target in $debugTargets) {
                    if ($content.Contains($target)) {
                        $hits += $target
                    }
                }
                if ($hits.Count -gt 0) {
                    Write-Host "  [调试] cc3d 命中: $($hits -join ', ')"
                }
            }
        }
        elseif ($replacementCount -gt 0) {
            Write-Host "  [调试] 命中但内容未变化: $($jsFile.Name) (+$replacementCount)" -ForegroundColor Yellow
        }
    }

    return $patched
}

function Unpatch-JsLanguage {
    param(
        [Parameter(Mandatory = $true)][string]$ResourcesPath
    )

    $assetsDir = Join-Path $ResourcesPath "ion-dist\assets\v1"
    if (-not (Test-Path -LiteralPath $assetsDir -PathType Container)) {
        Write-Host "  [警告] 未找到 assets 目录" -ForegroundColor Yellow
        return
    }

    $indexFiles = Get-ChildItem -LiteralPath $assetsDir -Filter "index-*.js" -File -ErrorAction SilentlyContinue
    $allJsFiles = Get-ChildItem -LiteralPath $assetsDir -Filter "*.js" -File -ErrorAction SilentlyContinue
    $exactLanguageArrays = @(
        @{
            Old = 'Mz=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"]'
            New = 'Mz=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"]'
        },
        @{
            Old = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN",];'
            New = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID",];'
        },
        @{
            Old = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"];'
            New = 'const yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"];'
        },
        @{
            Old = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN",];'
            New = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID",];'
        },
        @{
            Old = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID","zh-CN"];'
            New = 'const xF="en-US",yF=["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"];'
        }
    )
    $languageRegexes = @(
        [regex]'((?:\w+)=\[(?:"[^"]+",)+)"zh-CN"(,?)\]',
        [regex]'((?:\w+)=\[(?:"[^"]+",)+)"zh-CN"(,?);',
        [regex]'(const\s+[A-Za-z_$][\w$]*="en-US",[A-Za-z_$][\w$]*=\[(?:"[^"]+",)+)"zh-CN"(,?)\]',
        [regex]'(const\s+[A-Za-z_$][\w$]*="en-US",[A-Za-z_$][\w$]*=\[(?:"[^"]+",)+)"zh-CN"(,?);'
    )
    $mergeExactOld = 'const f={...l?.messages,...u};c(f,l?.gates??[],n?r:void 0)'
    $mergeExactNew = 'const f={...u,...l?.messages};c(f,l?.gates??[],n?r:void 0)'
    $mergeRegex = [regex]'const\s+([A-Za-z_$][\w$]*)=\{\.\.\.([A-Za-z_$][\w$]*)\?\.messages,\.\.\.([A-Za-z_$][\w$]*)\};([A-Za-z_$][\w$]*)\(\1,\2\?\.gates\?\?\[\],'
    $fallbackReplacements = [ordered]@{
        'defaultMessage:"新建任务",id:"K4O03zh0vo"'   = 'defaultMessage:"New task",id:"K4O03zh0vo"'
        'defaultMessage:"项目",id:"UxTJRaKagI"'       = 'defaultMessage:"Projects",id:"UxTJRaKagI"'
        'defaultMessage:"已排期",id:"cXAlMRerxW"'      = 'defaultMessage:"Scheduled",id:"cXAlMRerxW"'
        'defaultMessage:"实时构件",id:"fo4LT2foY3"'    = 'defaultMessage:"Live artifacts",id:"fo4LT2foY3"'
        'defaultMessage:"自定义",id:"TXpOBiuxud"'      = 'defaultMessage:"Customize",id:"TXpOBiuxud"'
        'defaultMessage:"已置顶",id:"fWZYP5U4xZ"'      = 'defaultMessage:"Pinned",id:"fWZYP5U4xZ"'
        'defaultMessage:"最近",id:"wA4FIMmtlS"'        = 'defaultMessage:"Recents",id:"wA4FIMmtlS"'
        'defaultMessage:"查看全部",id:"pFK6bJU0EM"'    = 'defaultMessage:"View all",id:"pFK6bJU0EM"'
        'defaultMessage:"查看全部项目",id:"dQKgzxReOT"' = 'defaultMessage:"View all projects",id:"dQKgzxReOT"'
        'const rp={chat:"New chat",cowork:"新建任务",code:"New session"}' = 'const rp={chat:"New chat",cowork:"New task",code:"New session"}'
        '{id:"projects",surface:"projects",icon:"Projects",label:"项目",modes:["chat","cowork"]}' = '{id:"projects",surface:"projects",icon:"Projects",label:"Projects",modes:["chat","cowork"]}'
        '{id:"scheduled",surface:"scheduled",icon:"Clock",label:"已排期",gate:"scheduled",modes:["cowork","code"]}' = '{id:"scheduled",surface:"scheduled",icon:"Clock",label:"Scheduled",gate:"scheduled",modes:["cowork","code"]}'
        '{id:"cowork-artifacts",href:$t,icon:"Artifacts",label:"实时构件",gate:"cowork-artifacts",modes:["cowork"]}' = '{id:"cowork-artifacts",href:$t,icon:"Artifacts",label:"Live artifacts",gate:"cowork-artifacts",modes:["cowork"]}'
        '{id:"customize",surface:"customize",icon:"Tool",label:"自定义"}' = '{id:"customize",surface:"customize",icon:"Tool",label:"Customize"}'
        'const lp="最近"' = 'const lp="Recents"'
        'z5t={recents:"最近",shared:"Shared"}' = 'z5t={recents:"Recents",shared:"Shared"}'
        'children:["查看全部",Bo.jsx(Ht,{name:"CaretRight",size:"xsmall"})]' = 'children:["View all",Bo.jsx(Ht,{name:"CaretRight",size:"xsmall"})]'
        'Bo.jsx(Vt,{collapsed:r,onToggle:i,children:"已置顶"})' = 'Bo.jsx(Vt,{collapsed:r,onToggle:i,children:"Pinned"})'
    }
    $indexNames = @{}
    foreach ($indexFile in $indexFiles) {
        $indexNames[$indexFile.Name] = $true
    }

    foreach ($jsFile in $allJsFiles) {
        $backupPath = Join-Path $backupDir $jsFile.Name

        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            Grant-WriteAccess -Path $jsFile.FullName
            Copy-Item -LiteralPath $backupPath -Destination $jsFile.FullName -Force
            Write-Host "  从备份恢复: $($jsFile.Name)"
        }

        Grant-WriteAccess -Path $jsFile.FullName
        $content = [System.IO.File]::ReadAllText($jsFile.FullName)
        $originalContent = $content

        if ($indexNames.ContainsKey($jsFile.Name)) {
            if (-not $content.Contains('"zh-CN"')) {
                Write-Host "  无需恢复: $($jsFile.Name)"
            }
            else {
                $languageRestored = $false
                foreach ($languageArray in $exactLanguageArrays) {
                    if ($content.Contains($languageArray.Old)) {
                        $content = $content.Replace($languageArray.Old, $languageArray.New)
                        $languageRestored = $true
                        Write-Host "  语言注册已恢复: $($jsFile.Name)"
                        break
                    }
                }

                if (-not $languageRestored) {
                    foreach ($languageRegex in $languageRegexes) {
                        $newContent = $languageRegex.Replace($content, '$1$2]', 1)
                        if ($newContent -ne $content) {
                            $content = $newContent
                            $languageRestored = $true
                            Write-Host "  语言注册已恢复(正则): $($jsFile.Name)"
                            break
                        }
                    }
                }

                if (-not $languageRestored) {
                    Write-Host "  [警告] 无法移除 zh-CN: $($jsFile.Name)" -ForegroundColor Yellow
                    Write-Host "  建议重新安装 Claude Desktop" -ForegroundColor Yellow
                }
            }

            if ($content.Contains($mergeExactOld)) {
                $content = $content.Replace($mergeExactOld, $mergeExactNew)
                Write-Host "  运行时覆盖补丁已恢复: $($jsFile.Name)"
            }
            else {
                $newContent = $mergeRegex.Replace($content, 'const $1={...$3,...$2?.messages};$4($1,$2?.gates??[],', 1)
                if ($newContent -ne $content) {
                    $content = $newContent
                    Write-Host "  运行时覆盖补丁已恢复(正则): $($jsFile.Name)"
                }
            }
        }

        foreach ($pair in $fallbackReplacements.GetEnumerator()) {
            if ($content.Contains($pair.Key)) {
                $content = $content.Replace($pair.Key, $pair.Value)
            }
        }

        if ($content -ne $originalContent) {
            Write-Utf8File -Path $jsFile.FullName -Content $content
        }
    }

    if (Test-Path -LiteralPath $backupDir -PathType Container) {
        Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  备份已清理"
    }
}

function Update-Config {
    param(
        [Parameter(Mandatory = $true)][string]$Locale
    )

    $configPaths = foreach ($localAppData in (Get-PreferredLocalAppDataRoots)) {
        $base = Join-Path $localAppData "Packages\Claude_pzs8sxrjxfjjc"
        @(
            (Join-Path $localAppData "Claude-3p\config.json"),
            (Join-Path $localAppData "Claude\config.json"),
            (Join-Path $base "LocalCache\Roaming\Claude\config.json"),
            (Join-Path $base "LocalCache\Roaming\Claude-3p\config.json")
        )
    }

    $configPaths = $configPaths | Select-Object -Unique
    $updatedCount = 0

    foreach ($configPath in $configPaths) {
        Write-Host "  检查配置: $configPath"

        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
            Write-Host "    不存在，跳过"
            continue
        }

        try {
            $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
            $config = $raw | ConvertFrom-Json

            if ($config.PSObject.Properties.Name -contains "locale") {
                $config.locale = $Locale
            }
            else {
                $config | Add-Member -NotePropertyName "locale" -NotePropertyValue $Locale
            }

            $json = $config | ConvertTo-Json -Depth 100
            Write-Utf8File -Path $configPath -Content $json
            $updatedCount += 1
            Write-Host "    已设置 locale=$Locale"
        }
        catch {
            Write-Host "    [警告] 配置更新失败: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    if ($updatedCount -eq 0) {
        Write-Host "  [警告] 未找到可更新的配置文件，Claude 可能会继续使用英文界面" -ForegroundColor Yellow
    }
}

function Get-ClaudeApplicationId {
    param(
        [Parameter(Mandatory = $true)][string]$ClaudePath
    )

    $manifestPath = Join-Path $ClaudePath "AppxManifest.xml"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return $null
    }

    try {
        [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
        $application = @($manifest.Package.Applications.Application | Select-Object -First 1)[0]
        if ($application -and $application.Id) {
            return [string]$application.Id
        }
    }
    catch {
    }

    return $null
}

function Get-ClaudePackageFamilyName {
    param(
        [Parameter(Mandatory = $true)][string]$ClaudePath
    )

    try {
        $resolvedClaudePath = [System.IO.Path]::GetFullPath($ClaudePath).TrimEnd("\")
        $pkg = Get-AppxPackage -Name Claude -ErrorAction Stop |
            Sort-Object Version -Descending |
            Where-Object {
                $_.InstallLocation -and
                ([System.IO.Path]::GetFullPath($_.InstallLocation).TrimEnd("\") -ieq $resolvedClaudePath)
            } |
            Select-Object -First 1

        if ($pkg -and $pkg.PackageFamilyName) {
            return [string]$pkg.PackageFamilyName
        }
    }
    catch {
    }

    try {
        [xml]$manifest = Get-Content -LiteralPath (Join-Path $ClaudePath "AppxManifest.xml") -Raw
        $identityName = [string]$manifest.Package.Identity.Name
        $folderName = Split-Path -Leaf $ClaudePath
        if ($identityName -and ($folderName -match "__([^_\\]+)$")) {
            return "$identityName`_$($Matches[1])"
        }
    }
    catch {
    }

    return $null
}

function Get-ClaudeAppUserModelId {
    param(
        [Parameter(Mandatory = $true)][string]$ClaudePath
    )

    $packageFamilyName = Get-ClaudePackageFamilyName -ClaudePath $ClaudePath
    $applicationId = Get-ClaudeApplicationId -ClaudePath $ClaudePath

    if ($packageFamilyName -and $applicationId) {
        return "$packageFamilyName!$applicationId"
    }

    return $null
}

function Start-ClaudeWithExplorer {
    param(
        [Parameter(Mandatory = $true)][string]$Target
    )

    try {
        $argument = $Target
        if ($Target -notlike "shell:*") {
            $argument = "`"$Target`""
        }

        Start-Process -FilePath "explorer.exe" -ArgumentList $argument | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Start-ClaudeWithWmi {
    param(
        [Parameter(Mandatory = $true)][string]$ExePath
    )

    try {
        $workingDirectory = Split-Path -Parent $ExePath
        $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
            CommandLine      = "`"$ExePath`""
            CurrentDirectory = $workingDirectory
        }

        return ($result.ReturnValue -eq 0)
    }
    catch {
        return $false
    }
}

function Start-ClaudeDetached {
    param(
        [Parameter(Mandatory = $true)][string]$ClaudePath
    )

    $appUserModelId = Get-ClaudeAppUserModelId -ClaudePath $ClaudePath
    if ($appUserModelId) {
        if (Start-ClaudeWithExplorer -Target "shell:AppsFolder\$appUserModelId") {
            return $true
        }
    }

    $exe = Join-Path $ClaudePath "app\claude.exe"
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        return $false
    }

    if (Start-ClaudeWithExplorer -Target $exe) {
        return $true
    }

    return (Start-ClaudeWithWmi -ExePath $exe)
}

function Restart-Claude {
    Stop-ClaudeProcess

    $claudePath = Find-ClaudePath
    if (-not $claudePath) {
        return
    }

    if (Start-ClaudeDetached -ClaudePath $claudePath) {
        Start-Sleep -Seconds 3
        Write-Host "Claude Desktop 已重启"
    }
    else {
        Write-Host "  [警告] 自动启动 Claude 失败，请手动打开 Claude Desktop" -ForegroundColor Yellow
    }
}

function Stop-ClaudeProcess {
    $claudePath = $null
    try {
        $claudePath = Find-ClaudePath
    }
    catch {
    }

    $desktopExe = $null
    if ($claudePath) {
        $desktopExe = Join-Path $claudePath "app\claude.exe"
    }

    try {
        Get-CimInstance Win32_Process -Filter "name='claude.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                if (-not $_.ExecutablePath) {
                    return $false
                }

                if ($desktopExe) {
                    return ([System.IO.Path]::GetFullPath($_.ExecutablePath) -ieq [System.IO.Path]::GetFullPath($desktopExe))
                }

                return ($_.ExecutablePath -like "*\WindowsApps\Claude_*")
            } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
    }
    catch {
    }

    Start-Sleep -Seconds 2
}

function Get-RequiredTranslationFiles {
    $required = @(
        [pscustomobject]@{ Name = "ion-dist"; Path = (Join-Path $packDir "ion-dist\zh-CN.json") },
        [pscustomobject]@{ Name = "desktop-shell"; Path = (Join-Path $packDir "desktop-shell\zh-CN.json") },
        [pscustomobject]@{ Name = "statsig"; Path = (Join-Path $packDir "statsig\zh-CN.json") }
    )

    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
            $legacyPath = Join-Path $scriptDir "$($item.Name)\zh-CN.json"
            if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
                $item.Path = $legacyPath
            }
        }
    }

    return $required
}

function Resolve-ClaudeResources {
    $claudePath = Find-ClaudePath
    if (-not $claudePath) {
        throw "未检测到 Claude Desktop"
    }

    $resourcesPath = Get-ResourcesPath -ClaudePath $claudePath
    if (-not $resourcesPath) {
        throw "未找到 resources 目录"
    }

    return [pscustomobject]@{
        ClaudePath = $claudePath
        ResourcesPath = $resourcesPath
    }
}

function Install-LanguagePack {
    Write-Host ""
    Write-Host "=== Claude Desktop 中文语言包安装 ==="
    Write-Host ""
    Write-Host "无需 Python，正在直接使用 PowerShell 安装。"

    $required = Get-RequiredTranslationFiles
    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
            throw "缺少翻译文件: $($item.Path)"
        }

        $sizeKb = [math]::Floor((Get-Item -LiteralPath $item.Path).Length / 1KB)
        Write-Host ("  {0}: OK ({1}KB)" -f $item.Name, $sizeKb)
    }

    Write-Host ""
    Write-Host "[1/5] 查找 Claude Desktop..."
    $resolved = Resolve-ClaudeResources
    Write-Host "  Claude: $($resolved.ClaudePath)"

    Write-Host ""
    Write-Host "  正在关闭 Claude Desktop..."
    Stop-ClaudeProcess

    Write-Host ""
    Write-Host "[2/5] 获取写入权限..."

    # WindowsApps 目录有系统级保护，需要给路径链上的关键目录都授予管理员权限
    $claudeParent = Split-Path -Parent $resolved.ClaudePath  # C:\Program Files\WindowsApps
    $appPath = Join-Path $resolved.ClaudePath "app"
    $criticalPaths = @($claudeParent, $resolved.ClaudePath, $appPath, $resolved.ResourcesPath)
    foreach ($path in $criticalPaths) {
        if (Test-Path -LiteralPath $path) {
            try {
                & takeown.exe "/f" $path "/a" | Out-Null
                & icacls.exe $path "/grant" "BUILTIN\Administrators:(OI)(CI)(F)" "/c" | Out-Null
            }
            catch { }
        }
    }

    $pathsToGrant = @(
        $resolved.ResourcesPath,
        (Join-Path $resolved.ResourcesPath "ion-dist"),
        (Join-Path $resolved.ResourcesPath "ion-dist\i18n"),
        (Join-Path $resolved.ResourcesPath "ion-dist\i18n\statsig"),
        (Join-Path $resolved.ResourcesPath "ion-dist\assets"),
        (Join-Path $resolved.ResourcesPath "ion-dist\assets\v1")
    )

    foreach ($path in $pathsToGrant) {
        Grant-WriteAccess -Path $path
    }

    $assetsDir = Join-Path $resolved.ResourcesPath "ion-dist\assets\v1"
    if (Test-Path -LiteralPath $assetsDir -PathType Container) {
        Get-ChildItem -LiteralPath $assetsDir -Filter "index-*.js" -File -ErrorAction SilentlyContinue |
            ForEach-Object { Grant-WriteAccess -Path $_.FullName }
    }

    Write-Host "  权限处理完成"

    Write-Host ""
    Write-Host "[3/5] 安装翻译文件..."
    $targets = @(
        [pscustomobject]@{ Source = $required[0].Path; Target = (Join-Path $resolved.ResourcesPath "ion-dist\i18n\zh-CN.json") },
        [pscustomobject]@{ Source = $required[1].Path; Target = (Join-Path $resolved.ResourcesPath "zh-CN.json") },
        [pscustomobject]@{ Source = $required[2].Path; Target = (Join-Path $resolved.ResourcesPath "ion-dist\i18n\statsig\zh-CN.json") }
    )

    foreach ($target in $targets) {
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $target.Target)) | Out-Null
        Copy-Item -LiteralPath $target.Source -Destination $target.Target -Force
        $relativeTarget = $target.Target.Substring($resolved.ResourcesPath.Length).TrimStart("\")
        Write-Host "  $relativeTarget"
    }

    Write-Host ""
    Write-Host "[4/5] 注册中文语言并修复运行时覆盖..."
    [void](Patch-JsLanguage -ResourcesPath $resolved.ResourcesPath)

    Write-Host ""
    Write-Host "[5/5] 更新配置..."
    Update-Config -Locale "zh-CN"

    Write-Host ""
    Write-Host "=== 语言包安装完成 ==="
    if ($NoRestart) {
        Write-Host "请手动重启 Claude Desktop 使更改生效。"
    }
    else {
        Write-Host ""
        Restart-Claude
    }
}

function Uninstall-LanguagePack {
    Write-Host ""
    Write-Host "=== Claude Desktop 中文语言包卸载 ==="
    Write-Host ""

    Write-Host "[1/4] 查找 Claude Desktop..."
    $resolved = Resolve-ClaudeResources
    Write-Host "  Claude: $($resolved.ClaudePath)"

    Write-Host ""
    Write-Host "  正在关闭 Claude Desktop..."
    Stop-ClaudeProcess

    Write-Host ""
    Write-Host "[2/4] 删除翻译文件..."

    # 确保路径链上的关键目录有权限
    $claudeParent = Split-Path -Parent $resolved.ClaudePath
    $appPath = Join-Path $resolved.ClaudePath "app"
    $criticalPaths = @($claudeParent, $resolved.ClaudePath, $appPath, $resolved.ResourcesPath)
    foreach ($path in $criticalPaths) {
        if (Test-Path -LiteralPath $path) {
            try {
                & takeown.exe "/f" $path "/a" | Out-Null
                & icacls.exe $path "/grant" "BUILTIN\Administrators:(OI)(CI)(F)" "/c" | Out-Null
            }
            catch { }
        }
    }

    foreach ($path in @(
            (Join-Path $resolved.ResourcesPath "ion-dist\i18n\zh-CN.json"),
            (Join-Path $resolved.ResourcesPath "zh-CN.json"),
            (Join-Path $resolved.ResourcesPath "ion-dist\i18n\statsig\zh-CN.json")
        )) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Grant-WriteAccess -Path $path
            Remove-Item -LiteralPath $path -Force
        }
    }
    Write-Host "  翻译文件已删除"

    Write-Host ""
    Write-Host "[3/4] 恢复语言注册..."
    Unpatch-JsLanguage -ResourcesPath $resolved.ResourcesPath

    Write-Host ""
    Write-Host "[4/4] 恢复配置..."
    Update-Config -Locale "en-US"

    Write-Host ""
    Write-Host "=== 语言包卸载完成 ==="
    if ($NoRestart) {
        Write-Host "请手动重启 Claude Desktop 使更改生效。"
    }
    else {
        Write-Host ""
        Restart-Claude
    }
}

function Extract-EnglishFiles {
    Write-Host ""
    Write-Host "=== Claude Desktop 英文文本提取 ==="
    Write-Host ""

    Write-Host "[1/3] 查找 Claude Desktop..."
    $resolved = Resolve-ClaudeResources
    Write-Host "  Claude: $($resolved.ClaudePath)"

    $enDir = Join-Path $scriptDir "extracted-en-US"
    $templateDir = Join-Path $scriptDir "translation-template"
    $targets = @(
        [pscustomobject]@{ Name = "ion-dist"; Source = (Join-Path $resolved.ResourcesPath "ion-dist\i18n\en-US.json") },
        [pscustomobject]@{ Name = "desktop-shell"; Source = (Join-Path $resolved.ResourcesPath "en-US.json") },
        [pscustomobject]@{ Name = "statsig"; Source = (Join-Path $resolved.ResourcesPath "ion-dist\i18n\statsig\en-US.json") }
    )

    Write-Host ""
    Write-Host "[2/3] 提取 en-US 原文..."
    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target.Source -PathType Leaf)) {
            Write-Host "  [警告] 未找到: $($target.Source)" -ForegroundColor Yellow
            continue
        }

        $enOut = Join-Path $enDir "$($target.Name)\en-US.json"
        $templateOut = Join-Path $templateDir "$($target.Name)\zh-CN.json"
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $enOut)) | Out-Null
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $templateOut)) | Out-Null
        Copy-Item -LiteralPath $target.Source -Destination $enOut -Force
        Copy-Item -LiteralPath $target.Source -Destination $templateOut -Force
        Write-Host "  $($target.Name): OK"
    }

    Write-Host ""
    Write-Host "[3/3] 提取完成"
    Write-Host ""
    Write-Host "英文原文目录: extracted-en-US/"
    Write-Host "待翻译模板目录: translation-template/"
    Write-Host ""
    Write-Host "翻译说明:"
    Write-Host "  1. 翻译 translation-template 目录中的 zh-CN.json"
    Write-Host "  2. 只修改 JSON 的 value，不要修改 key"
    Write-Host "  3. 不要删除 {count}、{name}、%s、<b>...</b> 等占位符"
    Write-Host "  4. 翻译完成后放到 translated-zh-CN 目录"
    Write-Host "  5. 然后运行安装中文语言包.bat 重新安装"
}

$scriptArgs = @()
if ($Uninstall) {
    $scriptArgs += "-Uninstall"
}
if ($Extract) {
    $scriptArgs += "-Extract"
}
if ($NoRestart) {
    $scriptArgs += "-NoRestart"
}
if ($PauseAtEnd) {
    $scriptArgs += "-PauseAtEnd"
}
if ($SkipElevation) {
    $scriptArgs += "-SkipElevation"
}
if ($OriginalLocalAppData) {
    $scriptArgs += @("-OriginalLocalAppData", "`"$OriginalLocalAppData`"")
}
if ($OriginalUserProfile) {
    $scriptArgs += @("-OriginalUserProfile", "`"$OriginalUserProfile`"")
}

if (-not $SkipElevation) {
    Ensure-Administrator -Arguments $scriptArgs
}

$exitCode = 0
try {
    if ($Extract) {
        Extract-EnglishFiles
    }
    elseif ($Uninstall) {
        Uninstall-LanguagePack
    }
    else {
        Install-LanguagePack
    }
}
catch {
    Write-Host ""
    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}
finally {
    Wait-BeforeExit
}

exit $exitCode
