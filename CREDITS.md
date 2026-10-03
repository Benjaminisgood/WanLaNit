# 来源和许可

本仓库公开。课程句子、界面文案、`Content/starters.json` 里的三篇短文、`Content/passages.json` 里的精读短文，以及 `Content/words.json` 里的泰文词头、Paiboon 罗马音、简体释义、话题和词频分档，都是这个项目自己编写的，不是从别的词表搬来的。词频只分成四档，表示大概的常用程度，不是某一份语料库的排名。没有收录许可不明的词典或词表。Kedmanee 键位按公开的泰文键盘排列写成表，没有复制其他打字软件的代码。

## 算法

间隔重复用 FSRS-5 的公开公式和默认参数（19 个权重，期望记住率 0.9）。算法说明见 [open-spaced-repetition](https://github.com/open-spaced-repetition) 公布的 The Algorithm。参考实现 fsrs-rs、py-fsrs、swift-fsrs 以 MIT 许可证发布。这里按公式重新写了 Swift，没有复制那些仓库的代码。

Anki（AGPL-3.0）和 LinguaCafe（GPL-3.0）只用来了解复习队列、卡片模板和阅读标注该怎么安排，没有翻译或复制它们的代码。

AI 练习的形式参考了这些项目的说明，没有复制它们的代码：

- [LibreLingo](https://github.com/LibreLingo/LibreLingo)（AGPL-3.0）：短输入、听写、双向翻译、按话题练一小段。
- Anki 的朗读类插件（如 AwesomeTTS、HyperTTS）这种「多家语音、没有钥匙就退回系统声音」的安排。
- [Echoic](https://github.com/xialeistudio/echoic)、[ShadowCoach](https://github.com/Marvelousp4/ShadowCoach)、[english-trainer](https://github.com/Oliviaviaviavia/english-trainer)、[Shadowly](https://github.com/hanh-nd/shadowly)：先听一句，自己说，再把转写和原句对齐打分；模型只做可选的文字说明，并写明这不是声学评分。

各家模型的 HTTP 接口按它们公开的文档写了客户端。没有把任何钥匙放进仓库。
