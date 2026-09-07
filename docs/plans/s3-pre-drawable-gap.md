# The S3 pre-drawable gap — the child's own layer before its first drawable

**Status: NOT YET CHECKED — run `check it` before any build.** Tracker:
[issue #13](https://github.com/macgameport/cities-skylines-2-macos/issues/13); the observation it
splits from is [#12](https://github.com/macgameport/cities-skylines-2-macos/issues/12); umbrella
[#1](https://github.com/macgameport/cities-skylines-2-macos/issues/1). Baseline: cs2 `43227c7`;
nested winemac `main` = `52789ff`, `core` = `63a0cec`, `aquadran` = `fe281fe`; installed daily
driver = stage 1 `2a251a4b2510fb84`. Line numbers are against nested `main` and name their file;
unqualified `:N` is `cocoa_window.m`.

> ⚠ **This document REDIRECTS issue #13's stated direction.** #13 proposes deferring
> `retire_superseded_layers`. That is still candidate B below, but reading the code first turned up
> a cheaper candidate #13 never considered, an in-tree precedent that already solved the same
> problem on the other side of the boundary, and the reason the gap is rare. Read § 2 before § 4.

## 1. What is already established (do not re-derive)

| | |
|---|---|
| **C55** | The one-frame black full-client host occurs on the pre-stage-1 baseline `cd79fc463795939f`. **Architectural — neither stage introduced it.** |
| **C56** | Its surface is **S3, the child's own offscreen layer before its first drawable** (`Tblue=100 %` on the diag build). Blue is a positively rendered colour, so it is a **real display gap, not a capture artifact**. |
| **C58** | It is a **single frame, ≤ 25 ms**, covering ~half the recorded client area. 4 episodes in 12 valid runs — **~0.3 per drag**. |
| **C58** | The S3 pre-drawable *window* **tiles the whole drag**: 2331 intervals, median 127 ms, 35.9 s of a 35.4 s drag. |

The tension those last two rows create **is the whole problem**: the pre-drawable state is present
essentially always, and the artifact appears once in ~4,500 frames. So **something covers it almost
every time**, and #13's question is what that is and why it misses one commit.

## 2. The mechanism, read from source (2026-09-07)

### 2.1 Which layer S3 is, and who owns it

`scripts/diag-colours-patch.py:64-72` paints blue onto `offscreen_layer.backgroundColor` and says
in situ that it "Runs in the GPU process." That layer is `CAContextSwapChain`'s, `:4303`,
constructed at `:4327-4342`:

```objc
offscreen_layer = [[CAMetalLayer alloc] init];          /* :4327 */
offscreen_layer.framebufferOnly = YES;                  /* :4337 */
offscreen_layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);   /* :4339 */
```

**The black is set unconditionally at construction, before any drawable exists.** On a production
build that black is exactly what a user sees in the gap; the diag build only recolours it.

**It is inherited, not project-authored.** Measured across the nested branches — the line is present
on `stock` (the pristine 11.16 import), `aquadran`, `main-raw`, `core` and `main` alike. Nothing in
this project introduced it, which bears on where a change belongs (§ 5).

### 2.2 The publish happens strictly before the first present

Still inside the same initialiser, immediately after the layer is built (`:4344-4359`):

```objc
OnMainThread(^{
    remote_context = [[CAContext contextWithCGSConnection:CGSMainConnectionID() ...] retain];
    [remote_context setLayer:offscreen_layer];
    context_id = [remote_context contextId];
});
...
macdrv_create_remote_layer(hwnd, child_hwnd, context_id);   /* :4359 */
```

`macdrv_create_remote_layer` is `NtUserPostMessage(WM_MACDRV_CREATE_REMOTE_LAYER, ...)`
(`window.c:1793-1798`). **The child advertises the context to the owner at construction — before
DXMT has rendered anything into it.** Every hosted generation therefore begins life as a black
rectangle of the correct size.

### 2.3 What supplies the covering

The owner handles that posted message at `window.c:1710-1766`: it computes the frame, calls
`macdrv_window_create_ca_layer_host_view` (→ `addCALayerHostViewWithContextId`, `:832`, which
`addSublayer`s the new host), and **only then** calls `retire_superseded_layers`
(`window.c:1761`), which releases every other host mirroring the same child.

That ordering is deliberate and its rationale is recorded on the function (`window.c:943-946`):
retiring on the old swapchain's death instead "leaves the child unhosted until the replacement's
own message arrives, and the window shows straight through for that long."

**So the covering is the predecessor host layer**, and it survives exactly until the owner's create
handler runs. Two asynchronous paths race:

- **Path A (owner):** child's `NtUserPostMessage` → wine message loop → create handler → main-thread
  `addSublayer` + retire of the predecessor.
- **Path B (child):** DXMT renders and presents the first drawable into `offscreen_layer`.

Path B normally wins — the round trip through a posted message and the owner's main queue is long
enough that the child has already presented by the time its predecessor is retired. **The artifact
is the interleaving where a CA commit lands after the retire and before the first present.** That is
"why it misses one commit," and it predicts the rate should track owner-side message latency, not
anything about drag geometry.

> ⚠ **Stated as a hypothesis about ordering, not a measurement.** §2.1 and §2.2 are read from
> source; this paragraph is an inference from them plus C58. § 6 says how to falsify it.

### 2.4 The in-tree precedent nobody carried across the boundary

The **owner** side already hit this exact problem and already fixed it. From
`addCALayerHostViewWithContextId`, `:847-861`:

```objc
/* The background covers what the snap below cannot -- an odd Win32 rect in a whole-point
 * slot leaves a sliver uncovered, showing white. Deferred because backgroundColor paints
 * the whole layer, which is visible from the moment it is added, so doing it at creation
 * flashes black on every new layer; transparent until only the seam is left to reveal. */
```

— then a 120 ms `dispatch_after` that paints the background only if that same layer is still the
one registered for the id. **The child side (`:4339`) does at construction precisely what the owner
side deliberately stopped doing, for the reason its own comment gives.** The comment even names the
symptom this issue is about: *flashes black on every new layer*.

## 3. Why #7's candidates do not reach this

Unchanged from #13, restated so this doc stands alone: #7's three candidates all target the **host**
background — the area a stale or reframed host fails to cover. S3 is a different surface. The host
is fine; the child's own layer is the thing with no content. #7 candidate 1 changes the gap's
colour, not its existence; candidate 3 moves black between host and content view; stage 2 is ruled
out on other grounds (C54).

## 4. Candidates

| | candidate | cost | what it does not fix |
|---|---|---|---|
| **A** | **Defer or drop the child's black background** (`:4339`), mirroring the owner-side precedent at `:847-861` | one line + a deferral block; a proven pattern already in this file | The layer becomes **transparent**, not covered — see the risk below |
| **B** | **Defer the retire** until the replacement presents (#13's stated direction) | needs a first-drawable signal the owner **does not currently have**; `CALayerHost` gives the owner a context id and nothing about the child's presents | Costs a held layer per child for an unbounded window if the child never presents |
| **C** | **Publish after the first present** — move `macdrv_create_remote_layer` (`:4359`) out of the initialiser to the first drawable | removes the race at its source rather than covering it | Delays hosting of every generation; interacts with C30's 417 creates/session |

⚠ **A is cheapest but is NOT obviously a win, and this doc does not claim it is.** Dropping the
black leaves the pre-drawable layer transparent, so what shows through is whatever is beneath — the
content view's own layer, which **C61** identifies as exactly the surface exposed in the strip case.
A therefore likely converts a black full-client flash into a stale-content flash. That is plausibly
much less visible (it is the native look) and plausibly just a different artifact. **Deciding
between "less visible" and "differently broken" is a measurement, not an argument** — § 6.

B and C both remove the gap rather than recolour it, at a structural cost. A `check it` pass should
adjudicate whether A is a legitimate ship on its own or only a mitigation under B.

## 5. Where a change belongs (upstream form)

§ 2.1 measured that `:4339` is inherited on every base branch. So:

- A change to `:4339` is a change to **inherited DXMT-side code**, not to this project's core. Per
  `CLAUDE.md` § ⛔, **no PR to dxmt** — a comment with exact locations is the permitted and correct
  channel, with the AI-assisted research disclosed.
- Whether the fix lands in the reference **core** or the DXMT **glue** is an open decision for the
  check, and it interacts with [#6](https://github.com/macgameport/cities-skylines-2-macos/issues/6)'s
  boundary question. `CAContextSwapChain` is the cross-process hosting mechanism, so a naive read
  puts it in core; that it is aquadran's code argues glue.
- Wine bug 60263's attachment 82030 is still the pre-stage-1 core. #6's own note says the next
  attachment update waits for stage 2 to settle — **it has now settled (C54, ruled out)**, so that
  hold is expired and can be revisited independently of this plan.

## 6. Test plan

The instruments exist; nothing new is needed to score this. `scripts/strip-module-ab.sh` at
`FRAMES=300` scores the artifact and `CAPTURE=video` (C58) resolves it at a 25 ms cadence.
⚠ Score the top band as black **or** any diagnostic colour — a true-black threshold cannot fire on a
diag build (C56, and the C49/C53/C56 scorer-bug family).

| id | test | pass condition | mutant |
|---|---|---|---|
| **S1** | **Falsify § 2.3's ordering claim.** Trace the interval between the owner's create-handler retire and the child's first present, per generation, over one full drag | the rare episodes coincide with intervals where retire **precedes** first present; if the artifact occurs on generations where the child presented first, § 2.3 is **wrong** and A/B/C are all mistargeted | n/a — this is the diagnostic, not a fix |
| **S2** | **Rate baseline at full coverage**, installed stage-1 driver, `FRAMES=300`, video capture, n ≥ 12 | reproduces C58's ~0.3 episodes/drag within its spread; establishes the denominator any fix is measured against | n/a |
| **S3** | **Candidate A built:** defer the child background 120 ms on the owner-side pattern | episodes/drag **separable below** S2's baseline (Mann-Whitney, the C54 standard) **and** no new full-client stale-content episode introduced — score the top band for the content-view colour too | revert `:4339` to unconditional black → the S2 rate must return |
| **S4** | **A's transparency risk, directly.** Diag build with the child layer transparent and the content view painted cyan (C42's build) | if A merely relocates the artifact, cyan appears at the same rate blue did — **that is A failing**, and it must be scored, not argued | force the content view opaque → cyan must vanish |
| **S5** | **T3 (human), narrowed.** James drags on the candidate build | verdict verbatim: does any full-client flash remain visible by eye at ≤ 25 ms? | none — a human drag is not repeated per mutant |
| **S6** | **No regression on the strip** (#7's surface) | stage 1's separation from baseline (p = 0.0079, C54) is preserved | none — structural |

Every listed mutant is **applied to real source and observed red, then restored green**. "Argued
red" is not red.

## 7. Exit criteria

1. § 2.3's ordering claim is **confirmed or refuted by S1** before any fix is built. A refutation
   sends this document back to § 2, not forward to § 4.
2. A candidate is chosen with its **cost stated** — including, for A, an explicit finding on whether
   it fixes the gap or relocates it (S4).
3. S3 shows separation from the S2 baseline at the C54 standard, with every mutant observed red.
4. S6 green — no regression on #7's strip.
5. T3 (S5) recorded verbatim in the ledger.
6. If the change touches published reference material, § 5's upstream-form decision is settled and
   the dxmt no-PR rule is honoured (comment, exact locations, AI assistance disclosed).

## 8. Rollback

The installed daily driver is stage 1 `2a251a4b2510fb84`, kept. Any candidate ships as a separate
module built through `scripts/build-winemac.sh` and is only installed after S3/S6; reverting is
reinstalling `2a251a4b2510fb84`. No prefix or settings change is involved.

## Review log

Not yet checked. **Run `check it` before the first build commit.**

| date | pass | lenses | method | model | verified against | verdict |
|---|---|---|---|---|---|---|
| — | — | — | — | — | cs2 `43227c7`, nested `main` `52789ff` | **UNCHECKED** |

**Key paths** (re-check if these move): `dlls/winemac.drv/cocoa_window.m` (`:832-861`, `:4298-4385`),
`dlls/winemac.drv/window.c` (`:943-970`, `:1710-1798`), `scripts/diag-colours-patch.py`,
`scripts/strip-module-ab.sh`, `scripts/video-gap-battery.sh`.
