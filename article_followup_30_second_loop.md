# The 30-Second Loop Wasn't Fonts: A Follow-up, Six Months Later

*A follow-up to [Why ChatGPT Freezes on Long Conversations](./article_chatgpt_performance.md), published April 2026.*

In April I traced a long ChatGPT conversation that froze in Safari to one line of WebKit behavior: when the font system reports a change, the document throws away every computed style and rebuilds all of them. On that page, one rebuild took about 9 seconds. It also kept happening, roughly every 30 seconds, even with the tab sitting idle.

I explained the repetition by saying that web fonts keep arriving: new weights, new variants, fallback resolution, each one triggering another full rebuild. That explanation was wrong. This October, while re-testing the WebKit fix, I finally traced where the 30-second rhythm comes from. It is not fonts at all.

## What happened since April

I filed the issue as [WebKit bug 311368](https://bugs.webkit.org/show_bug.cgi?id=311368). A fix is now in review upstream ([PR 63018](https://github.com/WebKit/WebKit/pull/63018)): instead of rebuilding every style when fonts change, WebKit now walks the tree once, restyles only the elements whose computed values depend on font metrics (units like `ch` or `lh`, `font-size-adjust`), and lets everything else pick up the new font during layout. In July a reworked version was posted, with a request on the bug to check whether it helps the case I reported.

To answer that properly, I built the patch and its parent commit on the same machine, with the same timing probes in both, and ran the same conversation on each.

## The page has changed

The first thing I noticed is that today's ChatGPT is not the page I measured in April. It now loads history in segments and keeps only a window of the conversation in the DOM. Even after scrolling all the way to the top, only about 2,500 to 5,000 elements are mounted, against roughly 34,000 in April.

That alone makes the old behavior much cheaper. On the unpatched build, each full rebuild of the conversation now takes around 100 ms, compared with about 9 seconds in my original measurements and about 1.5 seconds on late-April WebKit. The page no longer feels frozen, with or without the fix.

## The fix works

| | Without the fix | With the fix |
|---|---|---|
| 30-second ticks that triggered a full rebuild | 20 of 20 | 0 of 22 |
| Work done per tick on the main document | full rebuild, 66–105 ms | targeted walk, 2.5–9.6 ms |
| Anything over 100 ms during the session | about once per tick | never |

The standalone testcase I attached to the bug in April shows the same: a 45 ms full rebuild becomes a 4.5 ms walk.

The improvement is structural rather than dramatic on today's page. The cost of the old path grows with the number of elements on the page. The new path still visits every element, but only does real work for the handful that need it.

## Where the 30 seconds come from

The clue was in the logs all along. Each 30-second tick did not reach just the ChatGPT document. In the same millisecond, the font-change notification arrived at every document in the process: the main page, an embedded frame from another OpenAI domain, and an empty `about:blank` iframe. An empty iframe loads no fonts. Something below the page was announcing a font change to everyone at once.

So I attached a debugger to the page's process and stopped every time WebKit's font cache was invalidated. Every tick produced the same call stack:

```
MemoryPressureHandler::measurementTimerFired     every 30 s
  releaseMemory(non-critical)                    over the threshold
    FontCache::releaseNoncriticalMemory
      FontCache::platformReleaseNoncriticalMemory  Mac only
        FontCache::invalidate()                  drop all font data
          -> every document: "fonts changed"
            -> unpatched WebKit: rebuild every style
```

In plain terms: every 30 seconds, WebKit checks how much memory the page's process uses. Above a threshold (on a Mac, about 1 GB by default), it frees memory it considers non-critical. On macOS, part of that is discarding the entire font cache, and discarding the font cache tells every document that its fonts have changed. Nothing about the fonts has changed, but each document has to assume they did, and before the fix that meant restyling every element.

To make sure, I logged the memory figure WebKit itself computes on each tick. On the unpatched build, the one tick at 936 MB, below the threshold, was followed by nothing. Every tick above it, at 1,055 to 1,553 MB, was followed in the same millisecond by font-change notifications to every document. Under the threshold the loop stops; above it, it never does.

## What this changes in the April article

- **Still correct:** a font change makes unpatched WebKit rebuild every style, and on a large page that takes seconds. Both fixes, mine from April and the one now in review, cut exactly that link, so they hold no matter what triggers the change.
- **Still correct as an observation:** the rebuilds repeat about every 30 seconds, even when idle.
- **Wrong:** "font loading isn't a one-time event." Real web-font loads cause a few rebuilds while the page opens. The endless repetition comes from memory-pressure handling on the Mac.
- **Weaker than I said:** I wrote that this is not a bug in WebKit's font system because reporting font changes is correct behavior. On these ticks, no font changed.
- **Different cast:** I described two well-designed systems, ChatGPT's fonts and WebKit's style engine, colliding at scale. In fact three parts of WebKit (memory pressure, the font cache, the style system) produce the loop on their own. ChatGPT only contributes what any heavy page can: lots of elements and over a gigabyte of memory.

It also explains why the bug was hard to reproduce. You need a Mac, a page whose process grows past about 1 GB, and a few minutes on that page. A short conversation never gets there, and neither does my small testcase. The first attempts on the bug to reproduce it on ChatGPT failed, and now that makes sense.

## What is still open

With the fix, each tick no longer triggers a full rebuild, but WebKit still treats it as "every font changed" and checks every element on the page every 30 seconds. On today's ChatGPT that costs a few milliseconds. On a larger page it would cost more, for a font change that never happened. I asked on the bug whether freeing memory should notify documents about fonts at all.

## The lesson I'm taking from this

In April the clue was already in my own table: "every ~30 seconds." Fonts don't finish downloading on a schedule. A perfectly regular interval is a timer, and timers usually belong to the engine, not the network. I wrote the number down and explained it with the first plausible story instead of tracing who was calling. This time the one question that settled it was the simplest: when this function runs, who called it?

---

*Links: [WebKit bug 311368](https://bugs.webkit.org/show_bug.cgi?id=311368) · [PR 63018](https://github.com/WebKit/WebKit/pull/63018) · [Original article](./article_chatgpt_performance.md) · [Three-engine comparison](./article_firefox_comparison.md)*
