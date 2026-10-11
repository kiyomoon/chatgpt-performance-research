# ChatGPT Long Conversation Performance

Investigations from inside browser engines — WebKit and Firefox — into why ChatGPT freezes on long conversations.

## Articles

1. **[Why ChatGPT Freezes on Long Conversations](./article_chatgpt_performance.md)** | **[Webpage](https://kiyomoon.github.io/chatgpt-performance-research/)**
   On pages with large DOMs, a font change makes WebKit rebuild every CSS style, which on a long ChatGPT conversation took about 9 seconds and kept repeating. (April 2026; carries an October 2026 correction about what drives the repetition.)

2. **[How Three Browser Engines Handle Font Loading on Large Pages](./article_firefox_comparison.md)** | **[Webpage](https://kiyomoon.github.io/chatgpt-performance-research/firefox.html)**
   A follow-up comparing how WebKit, Gecko, and Blink each handle the same situation. WebKit and Gecko measured from instrumented builds; Blink from source review.

3. **[The 30-Second Loop Wasn't Fonts](./article_followup_30_second_loop.md)** | **[Webpage](https://kiyomoon.github.io/chatgpt-performance-research/followup.html)**
   Six months later: re-testing the WebKit fix, and tracing the repeating rebuilds to WebKit's memory-pressure handling on the Mac rather than to web fonts.

## Repository Contents

```
article_chatgpt_performance.md        Original investigation (WebKit)
article_firefox_comparison.md         Three-engine comparison
article_followup_30_second_loop.md    October 2026 follow-up
index.html, firefox.html, followup.html
                                      Webpages, generated from the articles (see below)
technical_reports.md                  Detailed technical reports (WebKit)
font-rebuild-repro/                   Standalone reproduction testcase
raw-data/                             WebKit experiment data (9 files)
raw-data-firefox/                     Firefox experiment data (2 files)
build.sh, site/                       Webpage generator: template, CSS, link rewriting
```

## Editing

The markdown articles are the source. The webpages are generated from them with [pandoc](https://pandoc.org); do not edit the `.html` files directly. After changing an article or `site/template.html`, run `./build.sh` and commit the regenerated pages together with the change.

## Contact

toneverdo@gmail.com
