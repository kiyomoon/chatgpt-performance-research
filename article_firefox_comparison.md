# How Three Browser Engines Handle Font Loading on Large Pages

After finding that ChatGPT freezes on Safari due to [web font loading triggering full style rebuilds](./article_chatgpt_performance.md), I noticed the same page works fine on Firefox. I was curious why.

I compiled Firefox from source, added the same kind of C++ instrumentation I'd used in WebKit, and measured what happens when a web font loads on a large page. The results turned out to be interesting — each of the three major engines handles this situation differently.

---

## What Happens When a Font Loads

When a web font finishes downloading, the browser needs to update text that uses that font — dimensions may have changed, lines may need to re-wrap. The question is: which elements need updating?

### WebKit

WebKit's `Document::fontsNeedUpdate()` calls `scheduleFullStyleRebuild()`. This recalculates CSS styles for every element in the DOM, regardless of whether it uses the changed font. On a ChatGPT page with 60,000 render objects, this takes about 9 seconds.

```
Document::fontsNeedUpdate()
  → scheduleFullStyleRebuild()
  → resolveStyle(ResolveStyleType::Rebuild)
  → walks all 60,000 RenderObjects
```

### Gecko (Firefox)

Gecko's `nsPresContext::UserFontSetUpdated()` has two paths. When called without a specific font (e.g., a font rule change), it calls `PostRebuildAllStyleDataEvent` — a broader rebuild similar in spirit to WebKit's approach. The raw logs show many of these during page load.

But when a *specific* font finishes loading, it takes a targeted path: `nsFontFaceUtils::MarkDirtyForFontChange()`, which walks the frame tree and checks each frame: does this frame's computed font-family actually reference the font that just loaded? Only matching frames get marked dirty.

```
nsPresContext::UserFontSetUpdated(aUpdatedFont)
  → if aUpdatedFont is null:
      PostRebuildAllStyleDataEvent (rule change — broader rebuild)
  → if aUpdatedFont is set:
      nsFontFaceUtils::MarkDirtyForFontChange(root, aUpdatedFont)
      (only matching frames marked for reflow)
```

### Blink (Chrome)

From the Chromium source, Blink uses `InvalidateStyleAndLayoutForFontUpdates()` which calls `MarkSubtreeNeedsStyleRecalcForFontUpdates()` — a subtree marking approach. I didn't instrument Blink for this investigation, so I don't have timing data.

---

## Measured Data

I added timing probes and counters to both WebKit and Firefox. Same test pages, same machine (MacBook Air M4, 16GB).

### Standalone test page (27,000 elements + Google Fonts Inter)

**Firefox:**
```
UserFontSetUpdated("Inter") → MarkDirtyForFontChange: 12.1ms
  scanned=57,616 frames, markedDirty=450
```

57,616 frames scanned. 450 marked dirty (0.8%).

**WebKit (with fix reverted to original behavior):**
```
fontsNeedUpdate → scheduleFullStyleRebuild
[ZhiStyle]: 71.0ms [FULL REBUILD]
```

All elements rebuilt. 71ms on this relatively simple page.

### ChatGPT long conversation (~60,000 render objects)

**Firefox:**
```
UserFontSetUpdated("OpenAI Sans") → MarkDirtyForFontChange: 0.2ms
  scanned=403 frames, markedDirty=1
UserFontSetUpdated("OpenAI Sans") → MarkDirtyForFontChange: 0.1ms
  scanned=403 frames, markedDirty=1
```

In the specific-font-update path for "OpenAI Sans," Gecko's instrumentation recorded scanning 403 frames and marking 1 dirty. Note that this is the targeted font-matching path only — it's not directly comparable to WebKit's full render object count, but it shows how narrow Gecko's invalidation is for this particular font update.

**WebKit:**
```
[ZhiStyle] #13: 8947.2ms [FULL REBUILD]
[ZhiStyle] #14: 12005.7ms [FULL REBUILD]
... repeats every ~30 seconds while idle ...
```

All 60,000 render objects rebuilt. ~9 seconds. Repeating.

### Style recalc during normal use

**Firefox (scrolling and typing on ChatGPT):**
```
[ZhiGeckoStyle] #6: 756.7ms    ← worst case during initial render
[ZhiGeckoStyle] #10-#50: 10-28ms  ← steady state
```

**WebKit (page idle, no interaction):**
```
[ZhiStyle] #30: 9013.5ms [FULL REBUILD]
[ZhiStyle] #38: 9527.2ms [FULL REBUILD]
... continues indefinitely ...
```

---

## Summary

| | WebKit | Gecko | Blink |
|---|---|---|---|
| Strategy | Full style rebuild | Per-frame font matching (for specific font updates) | Subtree marking |
| ChatGPT font update | ~9,000ms | 0.1ms (specific-font path) | Not measured |
| Frames marked dirty | All 60,000 | 1 of 403 scanned (specific-font path) | Subtree |
| Repeats while idle | Yes | No | Not measured (source suggests no full rebuild loop) |

---

## What Makes Gecko's Approach Work

The key function is `nsFontFaceUtils::MarkDirtyForFontChange()` in `layout/style/nsFontFaceUtils.cpp` — about 140 lines of code. It does a straightforward tree walk:

1. For each frame, check if its `font-family` CSS property references the loaded font
2. If yes, verify the font group actually contains this specific font entry
3. Only matching frames get a reflow scheduled
4. If a frame is already marked dirty, skip its descendants (they'll be handled as part of the parent's reflow)

It also distinguishes between frames that use the font for rendering versus frames that use font-metric-dependent units (`em`, `ch`), applying the minimum necessary invalidation for each case.

On ChatGPT, this means: "OpenAI Sans" is used in very few places (probably UI chrome rather than message content). Gecko figures this out in 0.1ms by checking 403 frames. WebKit doesn't check — it rebuilds everything.

---

## A Note on ChatGPT's Font

An interesting detail: ChatGPT recently switched from "Inter" to "OpenAI Sans" (their own custom font). This doesn't change the analysis — WebKit's `fontsNeedUpdate()` triggers a full rebuild regardless of which font updated. But it does explain why Gecko's scan is so fast on ChatGPT specifically: the custom font appears to be used in relatively few elements.

---

## Methodology

**WebKit:** Personal fork with C++ timing probes. Details in [technical reports](./technical_reports.md) and [the original article](./article_chatgpt_performance.md).

**Gecko:** Compiled from mozilla-central (April 2026). Added `printf` and `mozilla::TimeStamp` probes in:
- `layout/base/nsPresContext.cpp` — `UserFontSetUpdated()` timing and caller identification
- `layout/style/nsFontFaceUtils.cpp` — frame scan and dirty counters in `MarkDirtyForFontChange()`
- `layout/style/RestyleManager.cpp` — `ProcessPendingRestyles()` timing (>5ms threshold)

**Blink:** Source code review only.

Raw experiment data is in `raw-data/` (WebKit) and `raw-data-firefox/` (Firefox).

Questions or similar findings? Reach me at toneverdo@gmail.com.
