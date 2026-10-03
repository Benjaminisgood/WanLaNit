# วันละนิด

给 Benjamin 用的泰语练习。界面是简体中文，句子同时给出泰文、Paiboon 罗马音和中文。按每天大约二十分钟来排：先两周声调和生存句，再大约一个月认字，然后是虚词和词汇。男生礼貌词用 ครับ。

进度记在这台 Mac 的 `~/Library/Application Support/WanLaNit/progress.json`。不需要账号。

## 打开和运行

需要 macOS 14 和 Xcode 15 或更新版本。

仓库里没有 `.xcodeproj`，用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成：

```bash
brew install xcodegen
xcodegen generate
open WanLaNit.xcodeproj
```

在 Xcode 里选方案 WanLaNit，按 Run。应用名字是 วันละนิด。

只想检查课程和复习算法、不打开界面时：

```bash
swift test
```

## 从 GitHub 下载编好的应用

Actions 里的 “Build macOS app” 会在 macOS 上跑测试、编译，并上传未签名的 `WanLaNit-unsigned.zip`。在 Actions 页面打开某一次成功的运行，下载这个 artifact，解压得到 `WanLaNit.app`。

第一次打开会被系统拦住。在 Finder 里对 `WanLaNit.app` **按住 Control 点一下（或右键）→ 打开 → 仍要打开**。只对这一次需要这样，以后可以正常双击。不要用「移到废纸篓」那条提示里的直接双击。

## 泰语语音

播放用系统自带的 `AVSpeechSynthesizer`，不带录音文件。如果还没装泰语声音，应用里会写明，这里再写一遍：

1. 打开「系统设置」→「辅助功能」→「朗读内容」。
2. 在「系统声音」旁点「管理声音…」（有的系统是点声音名称旁边的信息按钮）。
3. 找到泰语（ไทย，语言代码 th-TH）并下载。
4. 回到应用再点「听」。

系统语音对五个声调只是大致的高低。罗马音上的符号才是标准：中调不标，低调 à，降调 â，高调 á，升调 ǎ。

## 每天学什么

从 2026-10-02 算起。

| 天数 | 内容 |
| --- | --- |
| 第 1–14 天 | 声调和生存句。每天大约 8 个新句子，其余时间复习。 |
| 第 15–45 天 | 辅音、元音、声调规则，每天大约 4 个新字，句子少加几个。 |
| 第 46 天起 | 虚词、家人、颜色。没认完的字母还会出现。 |

复习用 SM-2。忘了的卡片会在这一轮里再出现一次。文字课随时能翻，不必等到第 15 天。

## 怎么加内容

课程都在 `Content/` 里，和界面代码分开。

| 文件 | 内容 |
| --- | --- |
| `decks.json` | 词组 |
| `phrases.json` | 句子和词 |
| `consonants.json` | 44 个辅音 |
| `vowels.json` | 元音 |
| `tones.json` | 五个声调的说明 |
| `minimal_sets.json` | 声调最小对立 |
| `sounds.json` | 浊音、词首 ง、不除阻韵尾、送气 |
| `culture.json` | 文化笔记 |

加一句时，复制 `phrases.json` 里一条，换掉 `id`，填泰文、罗马音、中文，以及每个音节。音节要写辅音类、声调符号、活/死、长短。`word` 相同的音节属于同一个词，中间用连字符；不同的 `word` 之间用空格。罗马音必须和这些条件算出来的声调一致，`swift test` 会检查。

少数词和规则不一致，比如 ก็ 实际读降调。这种在音节上加 `exception`，用中文写明原因，否则测试不会放过。

有 ๆ 的句子要再写 `speech`，把重复展开，例如 `พูดช้าๆ` 的 `speech` 是 `พูดช้าช้า`。系统语音不一定会读那个重复号。

辅音的顺序和中/高/低分类要和 `ThaiAlphabet` 一致，多一个或少一个测试都会失败。
