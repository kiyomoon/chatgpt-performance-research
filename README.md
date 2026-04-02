# Why ChatGPT Freezes on Long Conversations

An investigation from inside the browser engine. The bottleneck isn't JavaScript or React — it's web fonts triggering infinite CSS style rebuilds.

**[Read the full article](./article_chatgpt_performance.md)** | **[View as webpage](https://kiyomoon.github.io/chatgpt-performance-research/)**

## Key Finding

On ChatGPT pages with 200+ messages (~60,000 render objects), WebKit's `fontsNeedUpdate()` triggers a full style rebuild that takes **~9 seconds**. The font system keeps reporting updates, creating an infinite loop — even with the page idle in a background tab.

## Repository Contents

```
article_chatgpt_performance.md   Main article
index.html                       Article as a standalone webpage
technical_reports.md             Detailed technical reports (4 reports covering
                                  performance profiling, memory breakdown,
                                  engine-level optimization, and root cause analysis)
raw-data/                        9 experiment data files (terminal output from
                                  each investigation session)
```

## Quick Numbers

| Metric | Before | After Fix |
|--------|--------|-----------|
| Scroll white-screen | 9-12 sec, repeating | Eliminated |
| Idle background rebuilds | Every ~30 sec, infinite | Eliminated |
| Typing latency | 20-28ms | 5-14ms |

## Contact

toneverdo@gmail.com
