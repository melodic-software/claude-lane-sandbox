# claude-lane-sandbox

A permanent **test fixture** for the Claude review lanes. Not a product repo, and
nothing here is meant to be depended on.

It exists so a deliberately broken lane credential can be exercised against
**real** lane output. A repo-level `CLAUDE_CODE_OAUTH_TOKEN` override shadows the
organization secret, the review check still concludes green, and the resulting
`class=auth` annotation is what the ci-workflows incident aggregator must detect.

Running that probe on a consumer repository would contaminate a live review
queue, and revoking the organization secret to force the failure would break
every lane at once. Hence a repository of its own.

## What lives here

- `.github/workflows/claude-review.yml` — the review-lane caller. **Locally
  owned**, not a sync-manifest target: this repo is deliberately outside the
  caller wave, so repin it by hand when the fleet pin moves.
- `probe.txt` — a throwaway file for probe pull requests to touch, so a PR can
  carry a real diff without inventing content.
- `stack-pilot.md` — the findings record from the stacked pull request pilot
  this fixture ran (PRs #6, #7, #8 as the layers, #10 as the control).

## Working in this repo

Through pull requests, always. The organization `base` ruleset targets every
repository's default branch and requires a pull request with no bypass, so a
direct push to `main` is refused by GitHub regardless of intent.

## Background

The lane topology, the incident aggregator, and this fixture's role in the
Phase 4 acceptance test are specified in
[`melodic-software/ci-workflows`](https://github.com/melodic-software/ci-workflows),
`docs/topics/claude-review-lanes/PLAN.md` (Phase 4), tracked by
[ci-workflows#238](https://github.com/melodic-software/ci-workflows/issues/238).
