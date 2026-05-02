---
name: review-diff
model: sonnet
description: Adversarial AI review of the current working diff. Spawns the reviewer subagent against `git diff HEAD`. Use when the user says "/review-diff", or after the Stop hook hints that a substantial diff is present.
---

You are running the inferential review sensor. The point is to find what the author missed — not to validate, not to rewrite.

## Procedure

1. Confirm there is a diff to review:

       git diff HEAD --stat

   If empty, tell the user "no working diff — nothing to review" and stop.

2. Capture the diff to a temp file (avoids inlining a huge blob in chat):

       git diff HEAD > /tmp/review-diff.patch

3. Spawn the `reviewer` agent. Pass:
   - Path to the diff file (`/tmp/review-diff.patch`).
   - One-sentence summary of the user's intent for the change, if you know it from context. If not, ask the user in one short line.

4. Relay the agent's verdict and findings to the user verbatim. Do not paraphrase, do not soften.

## What you do NOT do

- Do not edit files.
- Do not stage / commit / push.
- Do not auto-apply suggested fixes — the user decides.

If the agent verdict is **Revise** or **Block**, end your reply with: "Apply the fixes? (y/n)" and wait.
