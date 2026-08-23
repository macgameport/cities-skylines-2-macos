# Follow-up comment for dxmt#206 — POSTED 2026-08-23

> Live at https://github.com/3Shain/dxmt/issues/206#issuecomment-5386889070
> (body below is as posted)

---

Two follow-up confirmations from today, plus a workaround for anyone else hitting this.

**1. In-game recovery confirms the mechanism from a second angle.** With the game frozen
(exclusive fullscreen, after an alt-tab), switching the game's display mode to **"Fullscreen
Window"** brings presentation back *live* immediately. The winemac trace shows **no new swapchain
is created at the toggle** — the game simply starts presenting to its existing windowed swapchain,
which is the newest one on the HWND and therefore the one whose layer is composited. So both
directions now check out: presenting to the non-newest chain = invisible; presenting to the
newest = visible.

**2. Borderless is immune.** Playing in Fullscreen Window mode, alt-tab in and out is completely
clean over an extended session — no self-minimize, no freeze, input routes correctly. Consistent
with the mechanism: nothing ever displaces the windowed chain as the newest on the window.

**Workaround for affected users until this is fixed:** set Display Mode to *Fullscreen Window*.
If you're already frozen in exclusive fullscreen, you can recover without killing the session: the
screen repaints once per alt-tab cycle, so alt-tab your way through Options → Graphics → Display
Mode → Fullscreen Window → Apply, and it comes back live.

Offer stands to test any build or run any experiment against this setup.
