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
