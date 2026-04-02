# Technical Reports: ChatGPT Performance Investigation

These reports contain the detailed data, methodology, and analysis behind the article ["Why ChatGPT Freezes on Long Conversations"](./article_chatgpt_performance.md). They are presented in chronological order of the investigation.

---

## Report 1: Performance Profiling — React 18 Concurrent Rendering Analysis

**Date:** 2026-03-30
**Method:** JS-level profiling injected at document-start via custom WebKit browser (Zhi)

### Profiler Design

Collected via `WKUserScript` injection at `document-start`:
- `PerformanceObserver` type=longtask (tasks >50ms)
- `MutationObserver` for DOM node count changes
- `requestAnimationFrame` counter for real-time FPS
- `keydown` → next `rAF` timestamp for typing latency
- `performance.getEntriesByType('navigation')` for navigation timing

### Baseline: Short vs Long Conversation

| Metric | Short (few messages) | Long (252 messages) | Ratio |
|--------|---------------------|--------------------:|------:|
| DOM nodes | 2,174 | 34,264 | 15.7x |
| Main thread blocking | 0 | ~23 seconds | ∞ |
| Paint freeze | 0 | ~19 seconds | ∞ |
| Time to interactive | ~6 seconds | ~52 seconds | 8.7x |
| Long Tasks (>50ms) | 0 | **0** | — |

### Key Finding: React 18 Concurrent Rendering Bypasses Long Task Detection

React 18 splits rendering into thousands of <5ms chunks via `MessageChannel` scheduling. Each chunk is below the 50ms Long Task threshold. Result:
- **Zero long tasks detected** despite 23 seconds of cumulative JS work
- `setInterval` callbacks are blocked for 23 seconds (from t=6s to t=29s, no periodic stats output)
- When stats resume, node count jumps from 1,249 to 34,236

**In this observation, Long Task API did not surface React 18's cumulative rendering work.** Whether this generalizes to other browsers or spec implementations is an open question. Alternative detection methods that did work: rAF FPS counting + setInterval heartbeat drift.

### Rendering Pipeline Timeline

```
t=0s        Browser navigation starts
t=0.7s      didFinishNavigation (HTML + JS bundle loaded)
t=0.7-6s    React hydration + initial shell render
t=6s        API returns conversation data, React starts rendering messages
            ┌─── React concurrent rendering (each chunk <5ms, total ~23s) ───┐
t=6-29s     │  createElement × 34,000 nodes                                  │
            │  Zero Long Tasks detected (React 18 scheduler)                  │
            └─────────────────────────────────────────────────────────────────┘
            ┌─── WebKit rendering pipeline (~20 seconds) ────────────────────┐
t=29-49s    │  Style Recalculation: 34,264 nodes                             │
            │  Layout (reflow): full computation                              │
            │  Paint + Compositing: near-zero frame output (fps=0.1)          │
            └─────────────────────────────────────────────────────────────────┘
t=49-52s    Rendering pipeline catches up, compositor recovers
t=52s       Page interactive (FPS=56)
```

### Navigation Timing

```
dns=0ms  tcp=0ms  ttfb=0ms  domInteractive=0ms  domComplete=0ms  loadEvent=393ms
```

All zeros except loadEvent — ChatGPT is an SPA with client-side routing. **Web Vitals (LCP, FID, CLS) cannot accurately measure ChatGPT's real loading performance.**

### CSS `content-visibility: auto` Experiment (Failed)

Injected CSS for message containers. Expected to speed up rendering by skipping off-screen layout/paint. **Result: made FPS worse** — from recovering at t=52s to still frozen at t=76s. Possibly WebKit's `content-visibility` implementation has overhead with 226 elements.

### DOM Trimming Fix (JS-Level)

Replaced off-screen message content with fixed-height placeholders. IntersectionObserver restores on scroll.

```
deflated 206/226 turns: 34,264 → 4,950 nodes (-85%)
```

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| DOM nodes (stable) | 34,264 | 4,950 | -85.6% |
| Typing latency median | 20-28ms | 2-10ms | -65% |
| First character latency | 52ms | 6ms | -88% |
| Typing FPS | 9.9 | 32-57 | +3-5x |
| Backspace worst case | 64ms | 37ms | -42% |

User feedback: "Typing is much faster, but occasionally still stutters. First input is fast. Much better overall."

Remaining: space/backspace spikes at 57-62ms — React internal logic (@mention checking), not DOM-quantity related.

---

## Report 2: Memory Breakdown — 834MB bmalloc, 7MB JS Heap

**Date:** 2026-03-30
**Method:** macOS `footprint` / `vmmap` / `heap` — zero code changes

### Process-Level Memory Map

| Process | Footprint | Role |
|---------|-----------|------|
| **WebProcess** | **880 MB** | DOM, JS, style, layout, paint |
| GPU Process | 94 MB | IOSurface compositing, Metal rendering |
| Zhi (UIProcess) | 38 MB | WKWebView shell, window management |
| NetworkProcess | 16 MB | HTTP connection pool, cache |
| **Total** | **~1,028 MB** | |

**85% of memory is in WebProcess.**

### WebProcess Breakdown: Short vs Long

| Category | Short (Dirty) | Long (Dirty) | Delta | Share of Delta |
|----------|--------------|--------------|-------|---------------|
| **WebKit malloc (bmalloc)** | 350 MB | **834 MB** | **+484 MB** | **93.4%** |
| JS JIT generated code | 15 MB | 22 MB | +7 MB | 1.4% |
| JS VM Gigacage | 12 MB | 7 MB | -5 MB | — |
| MALLOC_SMALL (system) | 8 MB | 10 MB | +2 MB | 0.4% |
| Other | 7 MB | 7 MB | ~0 | — |
| **Footprint Total** | **392 MB** | **880 MB** | **+488 MB** | 100% |

**JS-related memory barely changed.** JIT code: 15→22MB. Gigacage (JS heap): 12→7MB (GC timing).

This disproves "React virtual DOM takes too much memory." React's fiber tree, props, state are all in the JS heap — only 7MB. **The real memory consumer is WebKit's C++ rendering pipeline.**

### Per-Node Memory Cost

Short→Long delta: 488MB for ~32,000 additional nodes = **~15KB amortized rendering-pipeline cost per message-node** (not `sizeof` of the node itself, which is ~88 bytes — the 15KB includes the node's C++ mirror, RenderObject, computed style, layout data, and associated strings).

### DOM Trimming Memory Experiment

DOM trimming improved performance but **worsened memory** (+277MB):
- `innerHTML` cache strings externalized to bmalloc
- bmalloc doesn't return freed pages to OS
- Peak: 880MB → 1,448MB during trimming process

**Performance optimization and memory optimization require different strategies.**

---

## Report 3: Engine-Level Memory Optimization — bmalloc scavenge + miniMode

**Date:** 2026-03-31
**Method:** dlsym bridge to bmalloc C++ API (no WebKit recompilation needed)

### Approach

Created `ZhiBmallocBridge` — ObjC class that calls bmalloc internal functions via `dlsym(RTLD_DEFAULT, mangled_name)`:

- `bmalloc::api::scavenge()` — Force return all free pages to OS via `madvise(MADV_FREE_REUSABLE)`
- `bmalloc::api::enableMiniMode(true)` — Aggressive scavenging: 5ms period, physical page sharing

Symbols found in JavaScriptCore.framework:
```
__ZN7bmalloc3api8scavengeEv
__ZN7bmalloc3api14enableMiniModeEb
```

### Three-Way Comparison

| Configuration | phys_footprint | Reclaimable | Effective under pressure |
|--------------|---------------|-------------|------------------------|
| Baseline (no optimization) | **1,133 MB** | 173 MB | ~960 MB |
| DOM trim + scavenge | 1,076 MB | 382 MB | ~694 MB |
| DOM trim + **miniMode** | **656 MB** (stable) | 760 MB | **~230 MB** |

miniMode's scavenger runs every 5ms in QOS_CLASS_BACKGROUND. No measurable impact on FPS or typing latency. `scavenge()` itself costs <0.1ms.

### Why Regular Browsers Don't Do This

Safari/Chrome use conservative scavenge policies to avoid frequent page faults when switching between tabs. For a single-tab dedicated browser, aggressive reclaim is pure upside.

---

## Report 4: C++ Object Statistics + Root Cause Analysis

**Date:** 2026-04-01 to 2026-04-02
**Method:** Modified WebKit source: DUMP_NODE_STATISTICS, atomic counters, timing probes, caller tracing

### DOM Node Statistics (C++ Precision)

Enabled `DUMP_NODE_STATISTICS` in `Element.h`. Added `nodestats` interactive command triggered via `console.log('__ZHI_DUMP_NODES__')` → `FrameConsoleClient` hook → `Node::zhiDumpAllStats()`.

| Category | Count |
|----------|-------|
| **Total DOM Nodes** | **161,800** |
| Element nodes | 71,000 |
| Text nodes | 89,000 |
| ShadowRoot | 1,260 |
| **DOM layer memory** | **~14 MB (1.4% of bmalloc)** |

Top element tags: `<P>` 22,807 · `<LI>` 6,950 · `<BR>` 5,744 · `<DIV>` 5,649 · `<STRONG>` 4,113 · SVG-related 7,900 (19.4%)

**DOM nodes are NOT the memory bottleneck.** 161k nodes × ~88 bytes = 14MB. The remaining 99% is in the rendering pipeline.

### RenderObject Statistics

Added atomic counters in `RenderObject` constructor/destructor:

| Metric | Value | During Scroll |
|--------|-------|---------------|
| RenderObject live | 60,220 | **Stable** (±10) |
| RenderObject total created | 60,276 → 60,407 | +130 during full scroll |

**RenderObjects don't change during scroll.** No creation/destruction.

### RenderStyle Statistics — The Breakthrough

Added counters in `RenderStyle::create()` and `RenderStyle::clone()`:

| Stage | Created | Cloned | **Total** |
|-------|---------|--------|-----------|
| Page load complete | 21,049 | 97,645 | **118,694** |
| After first scroll | 103,813 | 513,956 | **617,769** |
| After full scroll | 251,977 | 1,200,906 | **1,452,883** |
| After typing | 356,270 | 1,680,903 | **2,037,173** |

**2 million RenderStyle operations for 60,000 RenderObjects.** Each object's style recalculated ~34 times on average. Each scroll adds ~240,000 clones.

### Style vs Layout vs Paint Timing

Added `MonotonicTime` probes in `Document::resolveStyle()` and `LocalFrameViewLayoutContext::layout()`:

| Operation | Duration | Share of White-Screen |
|-----------|----------|----------------------|
| **Style recalculation** | **8,900-12,000ms** | **~97%** |
| Layout | 255-307ms | ~3% |
| Paint | <5ms (below threshold) | ~0% |

**Freeze time is 97% style recalculation.**

### Throttle Experiment (Failed — Informative)

Skipped 99% of `resolveStyle()` calls after initial load:
- Scroll-time RenderStyle: -49%
- But typing: 30-minute input freeze from accumulated dirty flags
- **Lesson: can't skip recalc; must reduce dirty element count**

### CSS Transition Disable Experiment (Partial)

Injected `* { transition: none !important; animation: none !important }` at document-start:
- Scroll-time RenderStyle increments: **-84%**
- But 9-second mega-recalcs: **unchanged**
- **Lesson: transitions cause frequent small recalcs, not the catastrophic ones**

### Root Cause: fontsNeedUpdate() → Full Style Rebuild Loop

Added `WTFLogAlways` at all `scheduleFullStyleRebuild()` call sites. **Caller identified:**

```
Document::fontsNeedUpdate(FontSelector&)
  → invalidateMatchedPropertiesCacheAndForceStyleRecalc()
    → scheduleFullStyleRebuild()
```

Pattern observed with **zero user interaction** (page idle in background):

```
[ZhiStyleRebuild] caller: Document::invalidateMatchedPropertiesCacheAndForceStyleRecalc
[ZhiStyle] #30: 9013.5ms [FULL REBUILD]
... ~20 seconds of 5ms recalcs ...
[ZhiStyleRebuild] caller: Document::invalidateMatchedPropertiesCacheAndForceStyleRecalc
[ZhiStyle] #38: 9527.2ms [FULL REBUILD]
... repeats indefinitely ...
```

**Web font loading triggers full style rebuild on every font update. On 60k RenderObjects, each rebuild takes 9 seconds. Font system keeps reporting updates → infinite loop.**

### The Fix

1. `fontsNeedUpdate()` → cache invalidation only, no full rebuild
2. `StyleInvalidator::invalidateAllStyle()` → downgraded to subtree invalidation

**Result:** After the initial load settles, 1000+ consecutive style recalcs at 5-14ms. A few expensive startup style recalculation passes still occur, but after that there are no further 9-second rebuilds during scroll, typing, stream responses, or idle.

---

## Raw Experiment Data Files

The following files contain unprocessed terminal output from each experiment session:

| File | Content | Key Observations |
|------|---------|-----------------|
| `chatgpt-nodestats.md` | 7 dumps during scroll+type, no optimization | RenderStyle 118k→2,037k during normal use |
| `chatgpt-renderobject-optimize.md` | Throttle experiment, 6 dumps | 30-min input freeze from accumulated dirty flags |
| `chatgpt-eval-inject.md` | Transition disable via eval injection | RenderStyle scroll increment -84%, but 9s unchanged |
| `chatgpt-js-inject.md` | Transition disable at document-start + timing | Confirmed: transitions ≠ cause of 9s recalc |
| `chatgpt-layout-render.md` | Style vs layout timing probes | Style=97%, Layout=3%, Paint≈0% |
| `chatgpt-full-style-rebuild.md` | Caller tracing output | fontsNeedUpdate identified as trigger |
| `chatgpt-font-disable.md` | Font debounce v1 (30s window) | Eliminated font loop, but 30s expiry too short |
| `chatgpt-font-disable-stream-response.md` | Font debounce v1 + stream test | Font loop returns after 30s cooldown |
| `chatgpt-font-disable-stream-response-test-2.md` | Font debounce v2 (permanent) | 1000+ consecutive 5-14ms recalcs, fix confirmed |
