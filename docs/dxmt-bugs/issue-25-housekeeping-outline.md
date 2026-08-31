# dxmt#25 "Project Housekeeping" — outline only, deliberately parked

**Status: OUTLINE. Not started, not offered.** Parked 2026-08-31 behind the cross-process fix.

**Why parked:** the issue is open since **2024-10-01 with zero comments** — including from its author.
That is weak evidence it is a priority for anyone, and an unsolicited style sweep is the kind of
contribution that costs a maintainer more review than it saves. Revisit *after* the code fix lands:
a contributor with a merged functional PR is in a much better position to offer this, and will also
know the codebase well enough for the answer to be worth having.

## What 3Shain actually asked for

> A consistent code style guide should be figured out. At present our code is influenced by many
> style guides including Microsoft style … LLVM style, STL style, and even DXVK style… maybe we
> don't have to use the same code styles for all subcomponents, but at least we should clearly
> state a consistent code style at subcomponent level, and let them be enforced by lint checker and
> formatter (e.g. clang-format). Also we are unintentionally use code width of 80 characters and it
> often creates unbalanced line breaks. We probably should shift towards 120 characters from now on.

Four asks: **(a)** decide the styles, **(b)** allow per-subcomponent variation, **(c)** enforce with
clang-format + lint, **(d)** move 80 → 120 columns.

## The approach, if it is ever taken up

The value we can add is that this is a **measurement problem**, not a taste problem — which is
exactly the discipline this project has been running all week. Do not arrive with opinions.

1. **Measure what the code actually does**, per subcomponent (`src/d3d11`, `src/d3d12`, `src/dxgi`,
   `src/winemetal`, `src/util`, `src/airconv`): brace placement, indent width, pointer alignment,
   naming, current line-length distribution. Report the split, e.g. *"`src/util` is 78% LLVM-shaped;
   `src/d3d11` is 61% Microsoft-shaped"*.
2. **Derive** a candidate `.clang-format` per subcomponent from those measurements rather than
   proposing a favourite.
3. **Price each option.** For every candidate config, report the **diff volume it would create** —
   files touched, lines changed. A maintainer's real objection to a formatter is the churn and the
   `git blame` damage; quantify it so the decision is informed.
4. **Offer the 80 → 120 change separately and first.** It is the one concrete decision already made
   in the issue, it is the cheapest to land, and it can ship as `ColumnLimit` alone.
5. **Include the blame-preserving step**: a `.git-blame-ignore-revs` entry for the reformat commit.
   Cheap, and it removes the strongest argument against a bulk reformat.

**Deliverable shape:** one comment on #25 with the measurement table and the priced options — *not*
a surprise PR. Let the maintainer choose; offer to do whichever they pick.

⚠ **Do not bundle this with the functional fix.** A style PR riding along with a behaviour change is
harder to review and easier to reject, and would put the cross-process work at risk for no gain.
