# 学术词库（数学优先）

面向万象拼音标准版的学术补充词库，共 **1,890 条词语、26 个分类**。

- [academic_math.dict.yaml](academic_math.dict.yaml)：**1,199 条、12 类**，涵盖维度与环面、逻辑与集合、线性代数、微积分、实分析、拓扑、微分几何、代数与数论、复分析、图论、数值计算和学术写作。
- [radar_statistics.dict.yaml](radar_statistics.dict.yaml)：**691 条、14 类**，涵盖雷达、信号处理、概率统计与优化。

## 使用

把两份词库和 [lua/personal_word_filter.lua](lua/personal_word_filter.lua) 按仓库目录结构复制到 Rime 用户文件夹。将以下配置合并到 `wanxiang.custom.yaml`，只保留一个顶层 `patch:`：

```yaml
patch:
  "translator/packs/+":
    - academic_math
    - radar_statistics
  "engine/filters/@before last": lua_filter@*personal_word_filter
  personal_word_filter:
    academic_dictionaries:
      - academic_math.dict.yaml
      - radar_statistics.dict.yaml
```

重新部署后，完整全拼匹配的学术词优先显示，支持拼音分隔符。个人固定短语优先；学术候选之间保留输入法原有排序和学习结果。

例如：`yiwei` → 一维，`yiweihuanmian` → 一维环面，`liuxing` → 流形，`tongpei` → 同胚，`kewei` → 可微，`xujing` → 虚警，`xiangwei` → 相位。

个人常用表达可另建本地词库包，加入 `translator/packs`，并把文件名列入 `personal_word_filter/preferred_dictionaries`。它支持完整全拼，以及六音节以内短语的声母混拼；个人词条和学习数据留在本机。

保持去重器 `uniquifier` 为最后一个过滤器。如果旧配置通过 `engine/filters/+` 追加了 `personal_word_filter`，先移除列表中的那一项，以免重复执行或影响去重。

## 可选屏蔽

按个人偏好屏蔽性相关、性暗示等候选，范围含部分医学和性教育词汇，可自行删改。

将以下文件按相同的目录结构复制到 Rime 用户文件夹：

- [custom/blocked_words.txt](custom/blocked_words.txt)：完整词名单。
- [custom/blocked_word_rules.tsv](custom/blocked_word_rules.tsv)：片段、英文整词及正常用法例外。

在上面的同一个 `patch:` 下追加这两项，再重新部署：

```yaml
  "personal_word_filter/word_file": custom/blocked_words.txt
  "personal_word_filter/rules_file": custom/blocked_word_rules.tsv
```

## 增补术语

词条格式为 `词语<Tab>带声调拼音<Tab>词频`，使用真实制表符。按数学含义检查多音字；数学词库常用短词通常用 `1000`，其他术语用 `500`。

例如，以下词条已收录：

```text
一维环面	yī wéi huán miàn	1000
```

在对应词库的分类下增补词条、更新头部版本并重新部署，新词会沿用学术优先规则。修改屏蔽名单后也需要重新部署。
