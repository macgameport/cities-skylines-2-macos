# dxmt#141 — sixth comment: the shimmer, measured and closed

**Status: DRAFTED, NOT POSTED.** Posting is James's call, same as the last two.

Prior: 5400445243 · 5403561498 · 5458926046 · 5466938536 (`jvspearman`) ·
**5477055980** + **5477128209** (`iosoceans`).

## Before posting

- `GH_CONFIG_DIR="$HOME/.config/gh-cs2" gh auth status` must say **`iosoceans`**.
- No diff in the body — same rule as before. The patches are already public and linked from the
  addendum; this comment adds no code.
- **Only worth posting if they engage**, or if it stands as a correction to something I told them.
  It does: comment 5477055980 said the shimmer's cause was a hypothesis I had not tested. It is now
  measured, and the fix is two changes rather than the one I guessed at. That is the justification.

---

Following up on the one thing I left open: the resize shimmer. I said the cause was untested and
that churn was only a hypothesis. It is measured now, and it turned out to need two changes rather
than the one I had in mind — the second only became findable after the first.

**How it was measured**, because this is what made it tractable: capture **during** a scripted
churn, against an identically-sampled static control. A post-settle capture cannot see it, which is
why it sat open. 40 samples per run.

| build | samples | frames with a black content area | rate | interior luminance min |
|---|---|---|---|---|
| before | 40 | 2 | 5.00% | **0** |
| + retire-on-create | 160 | 2 | 1.25% | **0** |
| + per-child deferred release | **320** | **0** | **0.00%** | **28** |

The dark frames are diagnostic rather than merely dark: **Steam's chrome renders perfectly — menu
bar, nav, URL bar, bottom bar — with the entire content area black.** That is the content browser's
hosted layer with nothing to show. At churn rate during a drag, that is the shimmer.

### The two changes

**1. Retire a hosted layer on CREATE, not on destroy.** Removal was driven by the old swapchain
dying, while the replacement arrived later on its own message — so nothing was hosted in between.
Adding the replacement first and dropping its predecessors after means the child is never unhosted.
That alone took it 5.00% → 1.25%.

**2. Hold the deferred client-surface release PER CHILD, not in one global slot.** This is the part
worth passing on, because it is the only lever that keeps *content* alive across a recreate:
`CAContextSwapChain`'s `dealloc` releases the remote `CAContext`, so a `CALayerHost` whose context
is gone has nothing to show. Deferring the client-surface release defers the dealloc, which defers
the context destruction. With a single global slot, one browser's release drained the other's held
context early — and Steam runs two. Keyed per child, a context survives until the next release for
that same child, which by construction is after its successor was acquired. 1.25% → 0.00%.

### Two things I got wrong on the way, since they are cheaper as someone else's warnings

- **"Keep the orphaned host alive until a successor lands" cannot work**, and I nearly built it.
  `dealloc` does `[context setLayer:nil]; [context release]` — the host has no content source to
  preserve. Reading that first saved writing the wrong fix.
- **The first fix looked complete.** Retire-on-create measured 0/40 on its first trial and I would
  have reported it fixed; trials 2 and 3 each showed 1. At a 5% base rate a single clean run of 40
  has roughly a 13% chance of showing zero by luck. Repeating is the only reason this is a result.

### Still open

Flicker during a live **mouse** drag. My harness drives `SetWindowPos`; a human dragging a window
edge goes through macOS live-resize, which it cannot reach. Someone using the build afterwards
described it as minimal — but that is one person's eyes, not a measurement, so treat it as "probably
improved, not established". Everything numeric above is scripted churn.

Same offer as before: the patches are public and you are welcome to them under MIT, and I am not
asking for anything to be merged given #152.
