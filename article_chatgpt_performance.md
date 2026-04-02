# Why ChatGPT Freezes on Long Conversations: An Investigation from Inside the Browser Engine

I have a ChatGPT conversation with over 200 messages — a months-long discussion about a fantasy novel I'm writing. Every time I open it, the page freezes for 30-40 seconds. Scrolling triggers white screens that last 10 seconds. Even leaving the tab idle in the background, the page periodically locks up.

This is a common experience. Anyone who uses ChatGPT for extended conversations knows the pain. The usual explanations are vague: "too many DOM nodes," "React is slow," "use a new conversation."

I wanted to know the real reason. I happen to maintain a personal fork of WebKit (the engine behind Safari), which gave me something most people don't have: the ability to add instrumentation directly inside the browser engine's C++ source code. Not browser DevTools, not JavaScript profiling — actual `printf` statements inside the rendering pipeline.

Here's what I found over four days of investigation. The answer surprised me.

---

## Setting Up: What the Page Looks Like from Inside

The first step was basic measurement. I added a profiling script that runs at page load, collecting DOM node counts, frame rate, and typing latency.

The short version: a 252-message ChatGPT conversation creates **34,264 element nodes** as seen from JavaScript (`querySelectorAll('*')`). That's 15.7x more than a fresh conversation (2,174 elements). Each message averages about 135 elements — paragraphs, list items, code blocks, bold text, SVG icons for the copy/feedback buttons. The total C++ node count is even higher: **161,800** when you include text nodes, shadow roots, and other non-element nodes that JavaScript doesn't directly expose.

Loading this page takes about 50 seconds to become interactive. During that time, the frame rate drops to near zero.

## First Discovery: React 18 Is Invisible to Performance Monitoring

While profiling, I noticed something odd. The browser's Long Task API — the standard tool for detecting performance problems — reported **zero long tasks**. Despite the page being frozen for 23 seconds while React rendered 34,000 nodes.

The reason: React 18 uses concurrent rendering. It breaks work into thousands of tiny chunks, each under 5 milliseconds. The Long Task API only flags tasks over 50 milliseconds. So React's 23 seconds of work flies completely under the radar.

This means any team using Long Task monitoring on a React 18 application is potentially blind to their biggest performance problems. The monitoring tool says everything is fine. The user sees a frozen page.

## Going Deeper: Where Does the Memory Go?

The page uses about 1 GB of memory. I used macOS memory tools (`footprint`, `vmmap`, `heap`) to break it down by category.

The result overturned my assumptions:

| Category | Memory | Share |
|----------|--------|-------|
| WebKit C++ objects (bmalloc) | 834 MB | 81% |
| GPU compositing layers | 73 MB | 7% |
| JavaScript heap | 7 MB | <1% |
| Everything else | 114 MB | 12% |

**The JavaScript heap — where React's virtual DOM, fiber tree, state, and props all live — is only 7 MB.** The common belief that "React's virtual DOM takes too much memory" is simply wrong for this page. The memory is overwhelmingly in WebKit's C++ rendering pipeline: DOM node mirrors, style objects, layout data, and string storage.

Dividing the 488 MB delta by the ~32,000 additional nodes added between a short and long conversation gives a rough amortized cost of **~15 KB per message-node**. This is *not* the `sizeof` of a DOM node (which is ~88 bytes) — it includes the full rendering pipeline cost: the node's C++ mirror, its RenderObject, computed style, layout data, and associated strings. As I'd later discover, the DOM nodes themselves are a tiny fraction of that cost.

## Seven Wrong Hypotheses

What followed was a systematic elimination process. I'll summarize it as a table, because each failed hypothesis narrowed the search:

| # | Hypothesis | What I Did | Result |
|---|-----------|-----------|--------|
| 1 | Too many DOM nodes | Enabled WebKit's built-in node statistics | Wrong — 161k nodes = 14 MB, only 1.4% of memory |
| 2 | RenderObject tree too large | Added atomic counters in C++ constructors | Wrong — 60k objects, stable count |
| 3 | JavaScript / React too slow | Measured JS heap | Wrong — 7 MB total |
| 4 | Layout is the bottleneck | Added timing in layout functions | Wrong — layout takes 255-307ms (3% of freeze time) |
| 5 | CSS transitions cause it | Injected `transition: none !important` | Partially — reduced small recalcs by 84%, but 9-second freezes unchanged |
| 6 | Can we just skip style recalc? | Throttled 99% of style resolution calls | Wrong — accumulated dirty flags caused a 30-minute input freeze |
| 7 | Style recalc itself is slow | Added timing in `resolveStyle()` | Right direction — 97% of freeze time is here |

Hypothesis 7 pointed clearly at CSS style recalculation. On this page, a single style recalculation pass takes about **9 seconds**, walking all 60,000 RenderObjects. But why was it happening so often?

## The Root Cause: Web Fonts Trigger an Infinite Style Rebuild Loop

I added caller tracing to `scheduleFullStyleRebuild()` — the WebKit function that requests a complete recalculation of CSS styles for every element in the DOM tree. The caller was:

```
Document::fontsNeedUpdate()
  → invalidateMatchedPropertiesCacheAndForceStyleRecalc()
    → scheduleFullStyleRebuild()
```

Every time a web font finishes loading (a new weight, style, or variant arrives), WebKit's font system notifies the document. The document responds by scheduling a **full style rebuild** — recalculating CSS for every single element.

On a page with 60,000 RenderObjects, this takes 9 seconds. During those 9 seconds, the main thread is blocked, no frames are rendered, and the user sees a white screen.

The problem is that font loading isn't a one-time event. The font system continues reporting updates (different variants arriving, fallback resolutions completing). So the cycle repeats: rebuild finishes → font update arrives → another rebuild starts → 9 more seconds of white screen. **This happens even when the page is sitting idle in a background tab with no user interaction at all.**

## Why WebKit Does This (And Why It's Not a "Bug")

When a font's metrics change, every element using that font might need different line heights, character widths, and `em`/`ex` unit values. WebKit's approach is conservative: rebuild all styles to guarantee correctness.

This is perfectly reasonable when a page has 1,000 elements — the rebuild takes about 150 milliseconds, imperceptible to the user. On ChatGPT's 60,000 elements, it takes 9 seconds.

It's not a bug in ChatGPT (web fonts are standard practice). It's not a bug in WebKit's font system (reporting font changes is correct behavior). It's a **pathological interaction** between two correct-by-design systems that were never tested together at this scale.

## The Fix: Two Lines of Logic

I made two changes inside WebKit:

1. **`fontsNeedUpdate()`**: Instead of triggering a full style rebuild, it now only invalidates the matched declarations cache. The next regular style recalculation picks up font changes incrementally.

2. **`StyleInvalidator::invalidateAllStyle()`**: Downgraded from a full rebuild to subtree invalidation on the document element. Same correctness (all elements eventually get re-styled), but through the incremental path that can yield to the event loop.

After these changes, the initial page load still has a few expensive style recalculation passes (the page is rendering 60,000+ elements for the first time, and some early font and stylesheet events still trigger large recalcs). But after that initial settling period, **zero 9-second rebuilds occur** — across scrolling, typing, streaming responses, and extended idle periods. All subsequent style recalculations complete in 5-14 milliseconds.

## Results

The style rebuild fix (two lines of logic) addressed the freezing:

| Metric | Before | After Fix | Change |
|--------|--------|-----------|--------|
| Scroll white-screen | 9-12 seconds, repeating | None during normal use | Eliminated |
| Idle background rebuilds | Every ~30 seconds, infinite | None | Eliminated |
| Typing latency | 20-28ms median | 5-14ms | -65% |

## Separate Experiment: Memory

In a separate experiment branch, I also addressed memory. WebKit's allocator (bmalloc) doesn't proactively return freed memory to the OS. I exposed two existing bmalloc APIs (`scavenge()` and `enableMiniMode()`) via `dlsym`, combined with a JS-level DOM trimming optimization that deflates off-screen messages:

| Metric | Before | After (DOM trim + miniMode) | Change |
|--------|--------|----------------------------|--------|
| Memory (WebProcess) | 1,133 MB | 656 MB | -42% |
| Reclaimable under pressure | 173 MB | 760 MB | +339% |

Note: the memory improvement comes from the DOM trimming + bmalloc miniMode experiment, not from the style rebuild fix. These are two independent optimization tracks that address different symptoms (freezing vs. memory footprint).

## What I Learned

**Style recalculation is the overlooked performance bottleneck.** Everyone in web development talks about JavaScript bundle size, React re-renders, and virtual DOM diffing. Almost nobody talks about CSS style recalculation, because it happens in the browser's C++ layer, invisible to JavaScript profiling tools. On this page, it accounts for 97% of the freeze time.

**Web fonts + large DOM is a performance trap.** The combination triggers pathological behavior that neither the font system nor the style system was designed to handle. If your application has 10,000+ elements and uses web fonts, you might have a milder version of this problem without knowing it.

**In this investigation, no standard web API surfaced the 9-second style recalc.** `PerformanceObserver` with `type: 'longtask'` reported zero entries — the Long Tasks spec defines tasks at the event-loop level, and in this WebKit build the style recalc appeared to run as a single blocking operation that didn't surface as a long task entry. Navigation Timing was also unhelpful (ChatGPT is an SPA). The only way I found the bottleneck was by adding `printf` inside WebKit's C++ source code. Whether other browsers or future spec revisions would expose this differently is an open question.

**Every "wrong" hypothesis was necessary.** Without confirming that DOM nodes are only 1.4% of memory, I wouldn't have focused on the rendering pipeline. Without confirming that layout is only 3% of freeze time, I wouldn't have focused on style recalculation. Without seeing that disabling CSS transitions reduces small recalcs by 84% but doesn't affect the 9-second ones, I wouldn't have looked for the full rebuild trigger. Seven wrong answers were the path to the right one.

---

## Methodology Note

This investigation was done by adding C++ instrumentation directly inside a WebKit source build — `printf` in rendering functions, atomic counters in object constructors, caller tracing in style invalidation paths. The methodology is simple in principle: when you can modify the browser engine's source code, you can observe exactly what happens at every layer when a real web page loads.

**Test environment:** MacBook Air M4, 16 GB RAM, macOS 26.3.1 (Darwin 25.3.0), WebKit trunk build 625.1.11+ (base commit `29c4212dc1`). The custom browser shell (Zhi) is a WKWebView wrapper with CLI automation, using the same WebProcess/GPU Process architecture as Safari.

**How I identified React 18 concurrent rendering:** The `setInterval` heartbeat (3-second period) was blocked for 23 seconds — when it resumed, DOM node count jumped from 1,249 to 34,236 in one observation. Despite this, `PerformanceObserver({type: 'longtask'})` reported zero entries. This pattern — large cumulative work invisible to Long Task API — is consistent with React 18's `MessageChannel`-based concurrent scheduler, which yields to the browser between 5ms work chunks. React's version was also confirmed via `__REACT_DEVTOOLS_GLOBAL_HOOK__` in the page's JavaScript context.

The investigation produced four detailed technical reports covering performance profiling, memory breakdown, engine-level memory optimization, and C++ object statistics with root cause analysis, plus nine raw experiment data files. These are available in the `technical_reports.md` file and `raw-data/` directory in this repository.

If you work on a web application with a large DOM and notice mysterious slowdowns, the style recalculation path is worth investigating. And if you're using React 18 with Long Task monitoring, you might want to check whether your monitoring is actually seeing what you think it's seeing.

Questions or similar findings? Reach me at toneverdo@gmail.com.
