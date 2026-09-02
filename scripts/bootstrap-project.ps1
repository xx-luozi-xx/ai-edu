param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-ProjectFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $target = Join-Path $script:Root $RelativePath
    $parent = Split-Path -Parent $target

    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ((Test-Path $target) -and -not $Force) {
        $script:Skipped += $RelativePath
        return
    }

    $Content = $Content -replace "^\r?\n", ""

    if (-not $Content.EndsWith("`n")) {
        $Content += "`n"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($target, $Content, $utf8NoBom)

    $script:Created += $RelativePath
}

function Add-GitIgnoreRules {
    param(
        [string[]]$Rules
    )

    $path = Join-Path $script:Root ".gitignore"

    if (Test-Path $path) {
        $content = [System.IO.File]::ReadAllText($path)
    }
    else {
        $content = ""
    }

    foreach ($rule in $Rules) {
        $escapedRule = [Regex]::Escape($rule)

        if ($content -notmatch "(?m)^$escapedRule\s*$") {
            if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
                $content += "`n"
            }

            $content += "$rule`n"
        }
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ------------------------------------------------------------
# 检查 Git 仓库
# ------------------------------------------------------------

$gitRoot = & git rev-parse --show-toplevel 2>$null

if ($LASTEXITCODE -ne 0 -or -not $gitRoot) {
    throw "当前目录不是 Git 仓库。请进入 D:\workspace\ai-edu 后重新运行。"
}

$script:Root = [System.IO.Path]::GetFullPath($gitRoot.Trim())
$script:Created = @()
$script:Skipped = @()

$origin = (& git -C $script:Root remote get-url origin).Trim()
$origin = $origin -replace "\.git$", ""

if ($origin -notmatch "github\.com[/:](?<owner>[^/]+)/(?<repo>[^/]+)$") {
    throw "无法从 origin 识别 GitHub 用户名和仓库名：$origin"
}

$owner = $Matches["owner"]
$repo = $Matches["repo"]

$branch = (& git -C $script:Root branch --show-current).Trim()

if (-not $branch) {
    $branch = "main"
}

$repoSlug = "$owner/$repo"
$repoUrl = "https://github.com/$repoSlug"

if ($repo -eq "$owner.github.io") {
    $siteUrl = "https://$owner.github.io/"
}
else {
    $siteUrl = "https://$owner.github.io/$repo/"
}

Write-Host ""
Write-Host "项目根目录：$script:Root" -ForegroundColor Cyan
Write-Host "远程仓库：$repoSlug" -ForegroundColor Cyan
Write-Host "当前分支：$branch" -ForegroundColor Cyan
Write-Host "Pages 地址：$siteUrl" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 创建目录
# ------------------------------------------------------------

$directories = @(
    "docs",
    "docs/research",
    "docs/engineering",
    "docs/shared",
    "docs/meetings",
    "docs/meetings/2026",
    "docs/decisions",
    "docs/assets/images",
    "docs/assets/diagrams",
    "templates",
    "src",
    "configs",
    "tests",
    "notebooks",
    "schemas",
    ".github/workflows"
)

foreach ($directory in $directories) {
    $fullPath = Join-Path $script:Root $directory
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

$emptyDirectories = @(
    "docs/assets/images/.gitkeep",
    "docs/assets/diagrams/.gitkeep",
    "src/.gitkeep",
    "configs/.gitkeep",
    "tests/.gitkeep",
    "notebooks/.gitkeep",
    "schemas/.gitkeep"
)

foreach ($file in $emptyDirectories) {
    Write-ProjectFile -RelativePath $file -Content ""
}

# ------------------------------------------------------------
# 依赖
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "requirements.txt" -Content @'
mkdocs-material>=9,<10
'@

# ------------------------------------------------------------
# README
# ------------------------------------------------------------

$readme = @"
# 生成式人工智能介入时机与大学生深度学习研究

本仓库用于维护教育研究文档、工程设计、会议记录、决策记录和实验系统代码。

## 核心命题

AI帮助并非越多越好，其教育效果取决于帮助是否出现在
“非生产性困难转向生产性困难”的临界点。

## 文档网站

$siteUrl

## 本地运行

1. 激活环境：conda activate ai_edu
2. 安装依赖：python -m pip install -r requirements.txt
3. 启动网站：python -m mkdocs serve
4. 浏览器访问：http://127.0.0.1:8000/

## 数据安全

这是公开仓库，请勿提交：

- 学生姓名、学号、邮箱；
- 未脱敏的实验数据；
- 未脱敏的学生与AI对话；
- API Key、Token、密码；
- 未经许可公开的研究材料。
"@

Write-ProjectFile -RelativePath "README.md" -Content $readme

# ------------------------------------------------------------
# MkDocs 配置
# ------------------------------------------------------------

$mkdocs = @"
site_name: 生成式AI介入时机与深度学习研究
site_description: 生成式人工智能介入时机对大学生深度学习影响机制研究
site_url: $siteUrl

repo_name: $repoSlug
repo_url: $repoUrl
edit_uri: edit/$branch/docs/

theme:
  name: material
  language: zh
  font: false
  palette:
    - scheme: default
      primary: indigo
      accent: blue
      toggle:
        icon: material/brightness-7
        name: 切换到深色模式
    - scheme: slate
      primary: indigo
      accent: blue
      toggle:
        icon: material/brightness-4
        name: 切换到浅色模式
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.indexes
    - navigation.top
    - search.suggest
    - search.highlight
    - content.code.copy
    - content.action.edit

plugins:
  - search:
      lang:
        - zh
        - en

markdown_extensions:
  - admonition
  - attr_list
  - md_in_html
  - tables
  - footnotes
  - pymdownx.details
  - pymdownx.superfences
  - toc:
      permalink: true

nav:
  - 首页: index.md

  - 教育研究:
      - 研究总览: research/index.md
      - 研究问题: research/questions.md
      - 核心概念: research/concepts.md
      - 理论框架: research/theory.md
      - 概念模型: research/conceptual-model.md
      - 实验设计: research/design.md
      - 测量方案: research/measures.md
      - 文献笔记: research/literature.md
      - 伦理与数据: research/ethics-and-data.md

  - 工程实现:
      - 工程总览: engineering/index.md
      - 系统架构: engineering/architecture.md
      - AI介入策略: engineering/intervention-policy.md
      - 实验条件配置: engineering/experiment-config.md
      - 交互设计: engineering/interaction-design.md
      - 事件日志: engineering/event-logging.md
      - 数据结构: engineering/data-schema.md
      - 分析管线: engineering/analysis-pipeline.md
      - 测试方案: engineering/testing.md
      - 工程路线图: engineering/roadmap.md

  - 项目协作:
      - 项目成员: shared/team.md
      - 跨学科术语表: shared/glossary.md
      - 研究—工程映射: shared/traceability-matrix.md
      - 项目里程碑: shared/milestones.md
      - 贡献指南: shared/contributing.md
      - 会议记录:
          - 会议索引: meetings/index.md
          - 2026-09-02 项目初始化: meetings/2026/2026-09-02-kickoff.md
      - 决策记录:
          - 决策索引: decisions/index.md
          - RDR-0001 认知依赖: decisions/RDR-0001-cognitive-dependence.md
          - ADR-0001 帮助事件: decisions/ADR-0001-help-event-schema.md
"@

Write-ProjectFile -RelativePath "mkdocs.yml" -Content $mkdocs

# ------------------------------------------------------------
# 首页
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "docs/index.md" -Content @'
# 生成式人工智能介入时机对大学生深度学习的影响机制研究

本项目研究生成式人工智能在不同时间、以不同形式提供帮助时，
如何影响大学生的任务表现、知识保持、迁移能力、元认知判断与认知依赖。

> **核心命题：**
> AI帮助并非越多越好，其教育效果取决于帮助是否出现在
> “非生产性困难转向生产性困难”的临界点。

## 两条项目主线

### 教育研究

包括研究问题、理论框架、概念模型、实验设计、测量方案、
文献综述和研究伦理。

[进入教育研究](research/index.md)

### 工程实现

包括系统架构、AI介入策略、实验配置、交互设计、
事件日志、数据结构和分析管线。

[进入工程实现](engineering/index.md)

## 当前研究问题

1. 学生经历的是生产性失败还是非生产性失败？
2. AI应当在什么时间介入？
3. AI应提供提示、提问、过程指导还是直接答案？
4. 如何区分高频使用AI与认知依赖？
5. AI是否造成“我已经学会”的学习幻觉？

## 快速入口

- [研究—工程映射表](shared/traceability-matrix.md)
- [跨学科术语表](shared/glossary.md)
- [会议记录](meetings/index.md)
- [决策记录](decisions/index.md)
- [工程路线图](engineering/roadmap.md)
'@

# ------------------------------------------------------------
# 教育研究总览
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "docs/research/index.md" -Content @'
# 教育研究总览

本部分用于记录研究问题、理论框架、概念模型、实验设计、
变量定义和测量方案。

## 核心任务

1. 定义生产性困难和非生产性困难；
2. 定义AI帮助介入的临界点；
3. 建立认知依赖的操作性定义；
4. 区分练习表现、即时学习和持久学习；
5. 将研究变量映射为系统功能和日志字段。
'@

Write-ProjectFile -RelativePath "docs/research/questions.md" -Content @'
# 研究问题

## 总体问题

生成式人工智能在何时、以何种方式介入大学生学习过程，
能够促进深度学习，同时减少学习幻觉和认知依赖？

## 核心研究问题

1. 不同AI介入时机如何影响练习表现、即时学习和持久学习？
2. 提问、提示、解释和直接答案是否产生不同效果？
3. 学生的尝试、解释、核查和复制行为是否发挥中介作用？
4. AI是否导致学生高估自己的真实掌握程度？
5. AI介入策略是否造成答案、过程、判断和元认知依赖？

## 待讨论

- 介入时机应按固定时间定义，还是按学生状态定义？
- 如何识别非生产性困难？
- 不同任务是否需要不同的介入标准？
'@

Write-ProjectFile -RelativePath "docs/research/conceptual-model.md" -Content @'
# 概念模型

## 自变量：AI如何帮助

- 帮助出现的时间；
- 帮助的详细程度；
- 直接回答还是提问引导；
- 是否允许无限求助；
- 是否要求学生先尝试；
- 是否根据学生状态调整。

## 中介变量：学生做了什么

- 是否认真尝试；
- 是否解释自己的思路；
- 是否比较多种策略；
- 是否核实AI答案；
- 是否修正错误概念；
- 是否直接复制答案。

## 因变量：学生学到了什么

1. 练习表现：有AI时的表现；
2. 即时学习：练习后关闭AI的表现；
3. 持久学习：延迟后面对新问题的表现。

## 调节变量

- 原有知识水平；
- 元认知能力；
- AI素养；
- 学习动机；
- 任务难度和开放程度；
- 对AI的信任程度。
'@

Write-ProjectFile -RelativePath "docs/research/measures.md" -Content @'
# 测量方案

## 行为依赖

- 多快开始求助；
- 是否未经尝试就求助；
- 请求完整答案的比例；
- 是否主动核查AI答案；
- AI关闭后能否独立启动任务；
- 是否直接复制AI答案。

## 学习结果依赖

初步定义：

AI依赖差值 = 有AI练习表现 - 无AI独立表现

需要继续确定是否标准化、是否取绝对值，以及如何控制题目难度。

## 元认知依赖

校准误差 = 预测正确率与实际正确率之间的差异。

## 主观依赖

可测量：

- 没有AI时的不安；
- 独立启动任务的困难；
- 对AI建议的服从程度；
- 放弃验证AI答案的倾向。

## 综合测量

认知依赖应结合：

- 行为日志；
- 独立测试；
- 元认知校准；
- 主观问卷。
'@

# ------------------------------------------------------------
# 工程研究总览
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "docs/engineering/index.md" -Content @'
# 工程实现总览

本部分用于把教育研究问题转化为系统功能、实验配置、
交互流程、日志字段和分析管线。

## 核心要求

1. AI介入时机可以配置；
2. AI帮助详细程度可以配置；
3. 可以要求学生先尝试；
4. 可以限制求助次数；
5. 所有关键学习行为可以记录；
6. AI关闭后可以进行独立测试；
7. 实验条件和提示词版本可以追溯。
'@

Write-ProjectFile -RelativePath "docs/engineering/intervention-policy.md" -Content @'
# AI介入策略

## 初步状态流程

开始任务 → 独立尝试 → 判断学习状态 → 提供适当帮助 → 要求重新作答。

## 候选触发信号

- 停滞时间；
- 连续错误次数；
- 重复提交相同答案；
- 是否表达了解题思路；
- 是否知道下一步；
- 学生主动求助。

## 帮助层级

| 等级 | 帮助类型 |
|---|---|
| L0 | 不帮助 |
| L1 | 元认知提问 |
| L2 | 方向提示 |
| L3 | 步骤提示 |
| L4 | 部分解释 |
| L5 | 完整解法 |
| L6 | 直接答案 |
'@

Write-ProjectFile -RelativePath "docs/engineering/event-logging.md" -Content @'
# 事件日志设计

## 通用字段

| 字段 | 说明 |
|---|---|
| event_id | 事件唯一标识 |
| participant_id | 匿名参与者编号 |
| session_id | 学习会话编号 |
| task_id | 任务编号 |
| condition_id | 实验条件编号 |
| event_type | 事件类型 |
| server_timestamp | 服务端时间 |
| elapsed_time_ms | 从任务开始计算的时间 |
| config_version | 实验配置版本 |

## 候选事件

- task_started
- answer_edited
- answer_submitted
- confidence_reported
- help_requested
- help_triggered
- help_displayed
- verification_submitted
- reflection_submitted
- task_completed

## AI帮助字段

- help_id；
- trigger_type；
- trigger_reason；
- help_level；
- help_format；
- attempt_count_before_help；
- elapsed_time_before_help_ms；
- prompt_version；
- model_version。
'@

Write-ProjectFile -RelativePath "docs/engineering/roadmap.md" -Content @'
# 工程路线图

## 阶段一：概念对齐

- [ ] 完善术语表；
- [ ] 完善研究—工程映射表；
- [ ] 明确实验条件；
- [ ] 明确核心日志字段。

## 阶段二：最小实验原型

- [ ] 任务展示；
- [ ] 学生作答；
- [ ] AI求助；
- [ ] 帮助层级控制；
- [ ] 行为日志；
- [ ] 无AI独立测试。

## 阶段三：介入策略

- [ ] 要求先尝试；
- [ ] 延迟帮助；
- [ ] 错误触发帮助；
- [ ] 停滞触发帮助；
- [ ] 渐进式帮助。

## 阶段四：预测试

- [ ] 功能测试；
- [ ] 日志完整性测试；
- [ ] 数据安全检查；
- [ ] 小规模预测试。
'@

# ------------------------------------------------------------
# 其余研究和工程页面
# ------------------------------------------------------------

$pageTitles = [ordered]@{
    "docs/research/concepts.md"                    = "核心概念"
    "docs/research/theory.md"                      = "理论框架"
    "docs/research/design.md"                      = "实验设计"
    "docs/research/literature.md"                  = "文献笔记"
    "docs/research/ethics-and-data.md"             = "伦理与数据管理"
    "docs/engineering/architecture.md"             = "系统架构"
    "docs/engineering/experiment-config.md"        = "实验条件配置"
    "docs/engineering/interaction-design.md"       = "交互设计"
    "docs/engineering/data-schema.md"              = "数据结构"
    "docs/engineering/analysis-pipeline.md"         = "分析管线"
    "docs/engineering/testing.md"                  = "测试方案"
}

foreach ($entry in $pageTitles.GetEnumerator()) {
    $pageContent = @"
# $($entry.Value)

> **文档状态：** 草稿  
> **最近更新：** 2026-09-02  
> **负责人：** 待指定

## 本页需要回答的问题

- [ ] 该内容对应哪个研究问题？
- [ ] 核心概念或功能是什么？
- [ ] 如何进行操作性定义？
- [ ] 需要什么系统功能和日志字段？
- [ ] 尚未解决的问题是什么？

## 当前结论

尚未形成稳定结论。

## 变更记录

| 日期 | 修改内容 |
|---|---|
| 2026-09-02 | 创建文档框架 |
"@

    Write-ProjectFile -RelativePath $entry.Key -Content $pageContent
}

# ------------------------------------------------------------
# 跨学科协作文档
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "docs/shared/glossary.md" -Content @'
# 跨学科术语表

## AI介入

- **教育学含义：** AI在学习过程中提供支持。
- **工程含义：** 系统向学生展示一次可见帮助。
- **注意：** 后台日志写入不属于可见介入。

## 生产性失败

学生初始解决失败，但进行了与目标知识相关的有效探索，
并能从后续指导中形成理解。

第一次答错不能直接等同于生产性失败。

## 认知依赖

学生逐渐失去在没有AI时完成任务的能力或意愿。

暂定包括：

- 答案依赖；
- 过程依赖；
- 判断依赖；
- 元认知依赖。

AI使用频率高不必然代表认知依赖。

## 学习幻觉

学生主观认为自己已经掌握，但无AI独立表现未达到相应水平。
'@

Write-ProjectFile -RelativePath "docs/shared/traceability-matrix.md" -Content @'
# 研究—工程映射表

| 研究概念 | 操作性定义 | 系统实现 | 日志字段 | 分析指标 |
|---|---|---|---|---|
| AI介入时机 | 首次帮助出现的时间或状态节点 | 定时、错误或停滞触发 | elapsed_time_before_help_ms | 首次帮助时间 |
| 要求先尝试 | 至少尝试一次后才能求助 | 求助前置检查 | attempt_count_before_help | 未尝试求助比例 |
| 帮助详细程度 | 提问、提示、解释、答案 | 分级帮助模板 | help_level | 实验条件 |
| 答案依赖 | 请求完整答案 | 请求类型识别 | request_type | 完整答案请求比例 |
| 判断依赖 | 不主动核查AI答案 | 核查界面 | verification_action | 主动核查比例 |
| 元认知依赖 | 预测与实际表现不一致 | 信心评分 | confidence、correctness | 校准误差 |
| AI依赖差值 | 有AI和无AI表现差距 | 练习和独立测试 | aided_score、unaided_score | 依赖差值 |
| 持久学习 | 延迟后的独立表现 | 延迟迁移测试 | delayed_score | 长期学习结果 |

## 使用方法

每增加一个研究变量，都应回答：

1. 教育学含义是什么？
2. 如何进行操作性定义？
3. 系统需要提供什么功能？
4. 需要记录什么数据？
5. 最终如何计算指标？
'@

Write-ProjectFile -RelativePath "docs/shared/team.md" -Content @'
# 项目成员

| 姓名 | 学科背景 | 项目角色 | 负责内容 |
|---|---|---|---|
| 待填写 | 教育学 | 研究负责人 | 理论与研究设计 |
| 待填写 | 计算机 | 工程负责人 | 系统与数据设计 |

## 协作原则

- 研究概念必须具有操作性定义；
- 工程功能必须对应研究问题；
- 重要决定必须形成记录；
- 会议行动项必须有负责人和截止日期。
'@

Write-ProjectFile -RelativePath "docs/shared/milestones.md" -Content @'
# 项目里程碑

| 里程碑 | 目标日期 | 状态 |
|---|---|---|
| 概念和理论框架 | 待确定 | 进行中 |
| 实验条件设计 | 待确定 | 待开始 |
| 最小原型 | 待确定 | 待开始 |
| 预测试 | 待确定 | 待开始 |
| 正式实验 | 待确定 | 待开始 |
| 数据分析 | 待确定 | 待开始 |
'@

Write-ProjectFile -RelativePath "docs/shared/contributing.md" -Content @'
# 贡献指南

## 建议流程

创建 Issue → 创建分支 → 修改文档或代码 → 提交 Pull Request → 审核 → 合并。

## Commit 示例

- docs: add meeting notes
- research: refine cognitive dependence definition
- engineering: define AI help event schema
- fix: correct navigation link

## 禁止提交

- 参与者身份信息；
- 未脱敏实验数据；
- API Key和密码；
- 未经授权公开的研究材料。
'@

# ------------------------------------------------------------
# 会议和决策记录
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "docs/meetings/index.md" -Content @'
# 会议记录

## 2026年

- [2026-09-02：项目初始化](2026/2026-09-02-kickoff.md)

## 文件命名

统一使用：YYYY-MM-DD-topic.md

会议记录重点包括：

1. 讨论的问题；
2. 形成的结论；
3. 尚未解决的分歧；
4. 重要决定；
5. 行动项、负责人和截止日期。
'@

Write-ProjectFile -RelativePath "docs/meetings/2026/2026-09-02-kickoff.md" -Content @'
# 2026-09-02 项目初始化

## 基本信息

- **时间：** 2026-09-02
- **参与者：** 待填写
- **记录人：** 待填写

## 本次目标

1. 建立跨学科项目知识库；
2. 建立教育研究和工程实现两条文档主线；
3. 建立会议与决策记录机制。

## 已完成

- 建立GitHub仓库；
- 设计项目文档结构；
- 配置MkDocs文档站；
- 配置GitHub Pages工作流。

## 待解决

- 生产性困难的操作性定义；
- AI介入临界点；
- 第一版实验任务；
- 实验系统技术栈；
- 行为日志结构。

## 行动项

| 任务 | 负责人 | 截止日期 | 状态 |
|---|---|---|---|
| 完善核心概念 | 待指定 | 待确定 | 待开始 |
| 设计AI帮助事件 | 待指定 | 待确定 | 待开始 |
| 确定实验任务 | 待指定 | 待确定 | 待开始 |
'@

Write-ProjectFile -RelativePath "docs/decisions/index.md" -Content @'
# 决策记录

## 研究决策

- [RDR-0001：认知依赖的暂定维度](RDR-0001-cognitive-dependence.md)

## 工程决策

- [ADR-0001：AI帮助事件结构](ADR-0001-help-event-schema.md)

## 状态说明

- proposed：提议中；
- accepted：已接受；
- rejected：已拒绝；
- deprecated：已废弃。
'@

Write-ProjectFile -RelativePath "docs/decisions/RDR-0001-cognitive-dependence.md" -Content @'
# RDR-0001：认知依赖的暂定维度

- **日期：** 2026-09-02
- **状态：** 提议中

## 暂定决定

认知依赖包括：

1. 答案依赖；
2. 过程依赖；
3. 判断依赖；
4. 元认知依赖。

## 待验证

- 四个维度是否相互独立？
- 是否需要加入情感或动机依赖？
- 如何验证测量工具的信效度？
'@

Write-ProjectFile -RelativePath "docs/decisions/ADR-0001-help-event-schema.md" -Content @'
# ADR-0001：AI帮助事件结构

- **日期：** 2026-09-02
- **状态：** 提议中

## 暂定决定

每次AI帮助至少记录：

- 帮助唯一ID；
- 参与者匿名ID；
- 任务ID；
- 实验条件；
- 触发时间；
- 触发原因；
- 帮助等级；
- 帮助形式；
- 帮助前尝试次数；
- 提示词版本；
- 模型版本。

## 目的

确保可以重建学生在什么时候、因为什么原因、接受了何种AI帮助。
'@

# ------------------------------------------------------------
# 模板
# ------------------------------------------------------------

Write-ProjectFile -RelativePath "templates/meeting-note.md" -Content @'
# YYYY-MM-DD 会议主题

## 基本信息

- 时间：
- 参与者：
- 主持人：
- 记录人：

## 本次目标

1.
2.

## 研究进展

## 工程进展

## 讨论内容

## 本次决定

| 编号 | 决定 | 状态 |
|---|---|---|
| | | |

## 行动项

| 任务 | 负责人 | 截止日期 | 状态 |
|---|---|---|---|
| | | | |

## 下次会议
'@

Write-ProjectFile -RelativePath "templates/decision-record.md" -Content @'
# DR-0000：决策名称

- 日期：
- 状态：提议中

## 背景

## 候选方案

## 最终决定

## 决定理由

## 对教育研究的影响

## 对工程实现的影响

## 验证方法
'@

# ------------------------------------------------------------
# GitHub Pages
# ------------------------------------------------------------

$workflow = @'
name: Deploy documentation to GitHub Pages

on:
  push:
    branches:
      - __BRANCH__

  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: github-pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Set up Python
        uses: actions/setup-python@v6
        with:
          python-version: "3.13"
          cache: pip

      - name: Install dependencies
        run: python -m pip install -r requirements.txt

      - name: Build documentation
        run: python -m mkdocs build --strict --site-dir site

      - name: Configure GitHub Pages
        uses: actions/configure-pages@v5

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v4
        with:
          path: site

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Deploy GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
'@

$workflow = $workflow.Replace("__BRANCH__", $branch)

Write-ProjectFile `
    -RelativePath ".github/workflows/pages.yml" `
    -Content $workflow

# ------------------------------------------------------------
# .gitignore
# ------------------------------------------------------------

Add-GitIgnoreRules -Rules @(
    ".venv/",
    "site/",
    "__pycache__/",
    "*.py[cod]",
    ".pytest_cache/",
    ".idea/",
    ".vscode/",
    ".env",
    ".env.*",
    "data/raw/",
    "data/private/",
    "*.sqlite3"
)

# ------------------------------------------------------------
# 完成
# ------------------------------------------------------------

Write-Host ""
Write-Host "项目初始化完成。" -ForegroundColor Green
Write-Host "新建文件：$($script:Created.Count)" -ForegroundColor Green
Write-Host "跳过已有文件：$($script:Skipped.Count)" -ForegroundColor Yellow

if ($script:Skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "以下文件已存在，未覆盖：" -ForegroundColor Yellow

    foreach ($file in $script:Skipped) {
        Write-Host "  = $file"
    }
}

Write-Host ""
Write-Host "下一步：" -ForegroundColor Cyan
Write-Host "  python -m pip install -r requirements.txt"
Write-Host "  python -m mkdocs build --strict"
Write-Host "  python -m mkdocs serve"
Write-Host ""
Write-Host "本地地址：http://127.0.0.1:8000/"
Write-Host "Pages 地址：$siteUrl"
