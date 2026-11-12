# 雷达信号处理与统计学词库

个人维护的万象拼音标准版补充词库，包含 **684 条词语、14 个分类**，覆盖雷达、信号处理、概率统计与优化。

## 使用

1. 将 [radar_statistics.dict.yaml](radar_statistics.dict.yaml) 放入 Rime 用户文件夹。
2. 在 `wanxiang.custom.yaml` 原有的 `patch:` 下合并以下配置：

   ```yaml
   patch:
     "translator/packs/+":
       - radar_statistics
   ```

3. 重新部署输入法。

按普通拼音输入即可，例如 `kongshizishiyingchuli` → 空时自适应处理。

词条按 `词语<Tab>带声调拼音<Tab>词频` 格式维护，拼音音节之间用空格分隔。

## 可选屏蔽

按个人偏好屏蔽性相关、性暗示等候选，范围含部分医学和性教育词汇，可自行删改。

将以下三个文件按相同的目录结构复制到 Rime 用户文件夹：

- [custom/blocked_words.txt](custom/blocked_words.txt)：完整词名单。
- [custom/blocked_word_rules.tsv](custom/blocked_word_rules.tsv)：片段、英文整词及正常用法例外。
- [lua/personal_word_filter.lua](lua/personal_word_filter.lua)：执行候选过滤。

将屏蔽配置与上面的词库配置合并在同一个 `patch:` 下：

```yaml
patch:
  "translator/packs/+":
    - radar_statistics
  "engine/filters/@before last": lua_filter@*personal_word_filter
  personal_word_filter:
    word_file: custom/blocked_words.txt
    rules_file: custom/blocked_word_rules.tsv
```

已有相同配置项时合并内容，保持去重器 `uniquifier` 为最后一个过滤器。若旧配置通过 `engine/filters/+` 追加了 `personal_word_filter`，先移除列表中的那一项，再使用上面的配置，以免重复执行或影响去重。

修改名单或规则后重新部署，格式和例外用法见文件内注释。
