# Rime 个人维护词库

[![数据校验](https://github.com/EvanMa1/rime-personal-dict/actions/workflows/checks.yml/badge.svg)](https://github.com/EvanMa1/rime-personal-dict/actions/workflows/checks.yml)

面向 **万象拼音标准版** 的个人补充词库，主要收录雷达信号处理、数字信号处理与概率统计术语。首版包含 **684 条词语、14 个分类**，使用带声调的全拼编码，通过 `translator/packs` 接入。

仓库也提供拼音纠错和严格候选过滤配置，按需安装。默认模板只加载专业词库。

## 快速安装

前提：已经安装万象拼音标准版，Rime 支持 `translator/packs`。目前已在小狼毫 **0.17.4 / librime 1.13.1 / 标准版全拼** 上验证。其他版本、双拼与 PRO 版需要另行确认兼容性。

1. 从 GitHub 的 **Code → Download ZIP** 下载本仓库，或克隆：

   ```bash
   git clone https://github.com/EvanMa1/rime-personal-dict.git
   ```

2. 在输入法菜单打开 Rime 用户文件夹，将根目录的 [`radar_statistics.dict.yaml`](radar_statistics.dict.yaml) 复制进去。
3. 将以下内容合并到用户目录的 `wanxiang.custom.yaml`。已有 `translator/packs/+` 时，只在列表中追加一次 `radar_statistics`；整个文件只保留一个顶层 `patch:`。

   ```yaml
   patch:
     "translator/packs/+":
       - radar_statistics
   ```

   也可以使用 [`examples/wanxiang.custom.yaml`](examples/wanxiang.custom.yaml) 作为新文件模板。合并时保留自己原有的全拼／双拼及其他设置。

4. 在小狼毫菜单中选择 **重新部署**。

平时按普通无声调拼音输入即可：

| 输入 | 词语 |
|---|---|
| `leidaxinhaochuli` | 雷达信号处理 |
| `maichongyasuo` | 脉冲压缩 |
| `hengxujingjiance` | 恒虚警检测 |
| `kongshizishiyingchuli` | 空时自适应处理 |
| `zuidasiranguji` | 最大似然估计 |
| `posongfenbu` | 泊松分布 |
| `xiefangchajuzhen` | 协方差矩阵 |

候选顺序还受语言模型、上下文和用户记录影响。词条分类、读音约定与详细维护方法见 [专业词库说明](custom/radar_statistics/README.md)。

## 可选配置

下面三个模板择一使用，合并到用户目录的 `wanxiang.custom.yaml`。模板文件名中的额外标记仅用于区分示例。

| 模板 | 功能 | 额外需要复制或合并的文件 |
|---|---|---|
| [默认模板](examples/wanxiang.custom.yaml) | 专业词库 | `radar_statistics.dict.yaml` |
| [拼音纠错模板](examples/wanxiang.corrections.custom.yaml) | 专业词库 + 拼音纠错 | `lua/personal_word_filter.lua`、`custom/typing_corrections.tsv`；合并短语示例 |
| [个人过滤模板](examples/wanxiang.personal-filter.custom.yaml) | 专业词库 + 拼音纠错 + 严格候选过滤 | `lua/personal_word_filter.lua`、`custom/blocked_words.txt`、`custom/blocked_word_rules.tsv`；合并短语示例 |

三种模板都需要复制专业词库。额外文件按仓库中的相对目录放入 Rime 用户文件夹；将 [`custom_phrase.example.txt`](custom_phrase.example.txt) 中需要的条目合并到已有的 `custom_phrase.txt`，保留自己的其他短语。

拼音纠错处理了 `bun` 被非普通话字“兺”占用的问题，并提供：

- `nengb`、`nengbu` → 能不。
- `nengbun` → 能不能。
- `ninengbun` → 你能不能。

严格候选过滤是个人偏好配置，包含成人内容及性相关表达，范围也涉及部分医学、性教育等中性用语。启用前请阅读 [过滤规则说明](custom/word_filter_README.md)，按自己的需要调整名单与例外。

## 维护与校验

需要 **Python 3.9+**，无需第三方 Python 包。在仓库根目录运行：

```bash
python tools/check_radar_dictionary.py
python tools/check_personal_files.py
```

默认检查词库结构、重复词、拼音格式、部分专业词读音，以及可选配置数据的格式。逐字读音校验需要提供本机万象的字表：

```bash
python tools/check_radar_dictionary.py --chars /path/to/rime/dicts/chars.dict.yaml
```

GitHub Actions 在 Python 3.9 和 3.13 上执行默认检查；它不包含逐字字表校验或 Rime 实际部署。

建议先在 Git 仓库中增补词条、更新词库版本，校验后将改动文件同步到 Rime 用户文件夹，再重新部署、验证输入并提交。词库版本使用 `YYYY.MM.DD.N`，同日再次修改时递增最后一位。

提交词条建议或读音修正时，请提供词语、拼音和所属领域；反馈候选问题时，请提供实际输入编码和预期结果。完整的 Rime 用户目录含学习记录等本机数据，维护提交应限定在本仓库列出的源文件中。

## 许可与相关项目

本仓库原创维护内容采用 [MIT License](LICENSE)。专业词条为人工整理；未整包导入搜狗词库。词条校验与运行验证使用本机万象环境。

- [Rime](https://github.com/rime) / [小狼毫](https://github.com/rime/weasel)
- [万象拼音](https://github.com/amzxyz/rime_wanxiang)
- [万象词库与语言模型](https://github.com/amzxyz/RIME-LMDG)

运行依赖以上项目，各自的内容遵循其项目许可证。更新记录见 [CHANGELOG.md](CHANGELOG.md)。
