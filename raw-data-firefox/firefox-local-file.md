```
user@host firefox % ./mach run -- file:///path/to/WebKit/font-rebuild-repro/index.html

 0:00.32 /path/to/firefox/obj-aarch64-apple-darwin25.3.0/dist/Nightly.app/Contents/MacOS/firefox file:///path/to/WebKit/font-rebuild-repro/index.html -foreground -profile /path/to/firefox/obj-aarch64-apple-darwin25.3.0/tmp/profile-[redacted]
2026-04-09 00:26:42.684 Nightly GPU Helper[90979:23626132] Failure on line 688 in function id scheduleApplicationNotification(LSNotificationCode, NSWorkspaceNotificationCenter *): noErr == _LSModifyNotification(notificationID, 1, &code, 0, NULL, NULL, NULL)
2026-04-09 00:26:42.815 Nightly GPU Helper[90979:23626157] Connection Invalid error for service com.apple.hiservices-xpcservice.
2026-04-09 00:26:42.815 Nightly GPU Helper[90979:23626132] Error received in message reply handler: Connection invalid
[ZhiGeckoFont] #1: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #2: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #1: 13.5ms
[ZhiGeckoFont] #1: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #3: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #4: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #5: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #6: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #7: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #8: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #9: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #10: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #11: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #12: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #13: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #14: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #15: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #16: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #17: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #18: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #19: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #20: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
UNSUPPORTED (log once): POSSIBLE ISSUE: unit 1 GLD_TEXTURE_INDEX_2D is unloadable and bound to sampler type (Float) - using zero texture because texture unloadable
[ZhiGeckoFont] #21: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #2: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #22: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #23: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #24: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #25: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #26: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #1: 6.5ms
[ZhiGeckoStyle] #2: 9.2ms
[ZhiGeckoStyle] #3: 10.6ms
[ZhiGeckoFont] #1: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #4: 6.8ms
[ZhiGeckoFont] #2: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #3: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #4: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #5: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #5: 11.1ms
[ZhiGeckoFont] #6: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #6: 9.8ms
[ZhiGeckoStyle] #7: 6.9ms
[ZhiGeckoStyle] #8: 8.0ms
[ZhiGeckoStyle] #9: 7.2ms
[ZhiGeckoStyle] #10: 13.1ms
[ZhiGeckoFont] #1: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #1: 13.3ms
[ZhiGeckoFont] #2: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #3: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #4: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #5: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #6: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #7: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #8: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #9: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #2: 6.4ms
[ZhiGeckoFont] #3: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoStyle] #11: 77.1ms
[ZhiGeckoFont]   → scanned=14 frames, markedDirty=1, markedRestyle=0
[ZhiGeckoFont] #4: UserFontSetUpdated("Inter") → MarkDirtyForFontChange: 6.1ms
[ZhiGeckoFont]   → scanned=57616 frames, markedDirty=450, markedRestyle=0
[ZhiGeckoFont] #5: UserFontSetUpdated("Inter") → MarkDirtyForFontChange: 12.1ms
[ZhiGeckoFont]   → scanned=54016 frames, markedDirty=4050, markedRestyle=0
[ZhiGeckoFont] #6: UserFontSetUpdated("Inter") → MarkDirtyForFontChange: 14.2ms
[ZhiGeckoStyle] #12: 10.7ms
[ZhiGeckoStyle] #3: 6.7ms
[ZhiGeckoFont] #10: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
[ZhiGeckoFont] #11: UserFontSetUpdated(null) → PostRebuildAllStyleDataEvent (rule change, not specific font)
```
