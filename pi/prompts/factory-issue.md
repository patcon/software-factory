---
description: Take one labelled GitHub issue to a draft PR (scout, worker, reviewer)
---

Take GitHub issue #$1 of the repository in the current directory to a draft pull request. Work on this one issue only. I am watching this pane; if you stop early, say why and what you need.

Hard rules, for the whole run:
- Never merge a PR, never force-push, never push to or commit on the default branch.
- Do not change the issue: no labels, no comments, no edits. The draft PR is the only thing you publish.
- No new dependencies. If the issue needs one, stop and tell me.
- Do not weaken existing tests to make them pass. If one has to change, say so in the PR under "Needs a human look".

## 1. Check the issue

- `cat ~/.config/software-factory/label` gives the queue label.
- `gh issue view $1 --json number,title,body,labels,state,comments`. Stop if the issue is closed or does not carry that label.
- If the issue is too vague to implement without product decisions, stop and tell me what is missing.

## 2. Make the branch

- `git status --porcelain` must be empty; otherwise stop.
- `git fetch origin`, then find the default branch with `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
- Stop if `factory/issue-$1` already exists locally or on origin (`git ls-remote --heads origin factory/issue-$1`): someone already took it.
- `git switch -c factory/issue-$1 origin/<default branch>`.

## 3. Delegate

Use the `subagent` tool (if only `subagents_enable` is available, call it first). Run the children one after another, in this checkout, with fresh context and no worktrees. Pass each child the issue title and body; they cannot see this conversation.

1. `scout`: map the code the issue touches, and find how this repo runs its tests, linting and type checks (read its README, AGENTS.md / CLAUDE.md, package or project files, CI config).
2. `worker`: implement the issue from the scout's context. Where the change is testable, write a test that fails first, then the fix. Follow the repo's own conventions. Run the relevant checks.
3. Run the scout's test, lint and type-check commands yourself (the reviewer has no shell) and keep the output.
4. `reviewer`: review the uncommitted diff against the issue, with your check output. Ask for a merge verdict.

If the reviewer's verdict is BLOCK, or checks fail, send the findings back to `worker` once, re-run the checks, and review again. If it is still BLOCK or red after that, stop: leave the branch unpushed and report to me.

## 4. Open the draft PR

- Commit with a message that says what changed and why, ending with `Refs #$1`. Do not commit scratch files such as `context.md` or `progress.md`.
- `git push -u origin factory/issue-$1` (no force).
- `gh pr create --draft --base <default branch>` with this body:

```
## What
<what changed and why, in a few sentences>

Closes #$1

## How it was tested
<the commands run and their results; tests added>

## Review
<the reviewer's merge verdict and any findings not fixed>

## Needs a human look
<decisions you made that the issue didn't settle, changed existing tests, anything risky; "nothing" if none>

## Not done
<parts of the issue left out, or "nothing">

🤖 Opened by pi (/factory-issue) on a software-factory VM
```

Finish by printing the PR URL.
