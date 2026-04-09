# ChatGPT Long Conversation Performance

Investigations from inside browser engines — WebKit and Firefox — into why ChatGPT freezes on long conversations.

## Articles

1. **[Why ChatGPT Freezes on Long Conversations](./article_chatgpt_performance.md)** | **[Webpage](https://kiyomoon.github.io/chatgpt-performance-research/)**
   Web font loading triggers repeated full style rebuilds in WebKit on pages with large DOMs.

2. **[How Three Browser Engines Handle Font Loading on Large Pages](./article_firefox_comparison.md)** | **[Webpage](https://kiyomoon.github.io/chatgpt-performance-research/firefox.html)**
   A follow-up comparing how WebKit, Gecko, and Blink each handle the same situation. WebKit and Gecko measured from instrumented builds; Blink from source review.

## Repository Contents

```
article_chatgpt_performance.md    Original investigation (WebKit)
article_firefox_comparison.md     Three-engine comparison
index.html                        Original article as webpage
technical_reports.md              Detailed technical reports (WebKit)
font-rebuild-repro/               Standalone reproduction testcase
raw-data/                         WebKit experiment data (9 files)
raw-data-firefox/                 Firefox experiment data (2 files)
```

## Contact

toneverdo@gmail.com
