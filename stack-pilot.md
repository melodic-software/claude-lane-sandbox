# Stacked pull requests — pilot findings

GitHub's stacked pull requests entered public preview on 2026-07-30 and are live for this
organization (the GraphQL schema exposes `PullRequest.stack` / `stackEntry` and the
`PullRequestStack*` types). This fixture ran the pilot; PRs #6, #7, #8 were its three layers,
merged atomically, and PR #10 was the control.

## Proven here

- **Squash-only + required linear history + required signatures are compatible with an atomic
  stack merge.** `gh stack merge --squash` landed all three layers under the `base` org ruleset
  (pull request required, no bypass) in one all-or-nothing operation, producing one squash commit
  per layer on `main` and deleting every branch. All three merge commits report
  `verification.verified: true`, `reason: valid`.
- **`gh stack rebase` preserves signatures.** Every rebased commit stayed `G` (good signature)
  under `commit.gpgsign=true` / `gpg.format=ssh`.
- **Each layer gets its own CI run.** A `pull_request` workflow fires once per layer, so an
  N-layer stack costs N times the pipeline.
- **A diverged stack presents as "checks never appear" on the upper layers.** While layers 2 and 3
  were non-linear with layer 1, no workflow runs fired for them; a plain control pull request onto
  the same non-`main` base *did* run, ruling out "workflows do not run for non-`main` bases". After
  `gh stack rebase` restored linearity, runs fired for both. On a `requires-ci` repository this
  failure mode reads as a hung gate rather than a broken stack.
- **`gh stack submit` opens every layer as a draft** and writes a one-line body containing only the
  CLI attribution — no closing keyword, no `## Related` section.

## Not proven here

This fixture carries `RequiresCi: false` and no `pr-issue-linkage` or `pr-title` caller, so it has
no required checks. Its only `pull_request` caller is `.github/workflows/claude-review.yml`, and no
workflow here produces the `ci-status` context at all — so the per-layer observation establishes
*trigger behavior* only. Whether every layer of a stack emits a correctly named, successfully
completed `ci-status` check, and therefore satisfies the `ci-gate` ruleset, remains an explicit
hypothesis until a stack is exercised against a live gate on a `requires-ci` repository. The linkage
gate's *inputs* were observed; its verdict was not.

## Conventions this changes

- **Web "Rebase stack" is unusable in this organization.** GitHub's own engineering guidance names
  web-based rebase an anti-pattern for branches requiring signed commits, and the `signing` ruleset
  is active fleet-wide. `gh stack rebase` is the only supported path.
- **Rebase before submitting.** `gh stack rebase` precedes `gh stack submit` as a standing rule, so
  a diverged stack never reaches CI as a phantom-hung gate.
- **`pr-issue-linkage` needs a stack-aware mode.** Requiring a closing keyword on every layer means
  N pull requests closing one issue. Lower layers should reference the stack; the top layer closes
  the issue. That change belongs to the shared reusable in `ci-workflows`, not to a per-repository
  caller.
- **The per-layer Conventional Commits title gate stays.** Each layer squashes to its own commit on
  `main`, so `pr-title` is enforcing exactly the right thing for stacks.
- **Merge-lane automation is stack-unaware.** Any loop that discovers pull requests independently
  and gate-checks them one at a time can try to merge an upper layer before the layer beneath it,
  and does not know `gh stack merge` is a single atomic operation.

## Trigger

Revisit when stacked pull requests reach general availability, when merge-queue support finishes
rolling out, or when `gh stack` ships stack-aware issue-linkage support. Public preview is
explicitly subject to change, so nothing here is encoded into rulesets or the governed repository
profile yet.
