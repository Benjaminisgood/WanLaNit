# 来源和许可

本仓库公开。课程句子、界面文案，以及 `Content/words.json` 里的泰文词头、Paiboon 罗马音、简体释义、话题和词频分档，都是这个项目自己编写的，不是从别的词表搬来的。词频只分成四档，表示大概的常用程度，不是某一份语料库的排名。

## 算法

间隔重复用 FSRS-5 的公开公式和默认参数（19 个权重，期望记住率 0.9）。算法说明见 [open-spaced-repetition](https://github.com/open-spaced-repetition) 公布的 The Algorithm。参考实现 fsrs-rs、py-fsrs、swift-fsrs 以 MIT 许可证发布。这里按公式重新写了 Swift，没有复制那些仓库的代码。

Anki（AGPL-3.0）和 LinguaCafe（GPL-3.0）只用来了解复习队列、卡片模板和阅读标注该怎么安排，没有翻译或复制它们的代码。
