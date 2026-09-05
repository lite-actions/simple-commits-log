# simple-commits-log

Composite GitHub Action (pure shell) that creates or updates `CHANGELOG.md`
with the latest commit merged to `main`, formatted as the date, a simple commit
log type, a short SHA, and the message on the following line.

## Usage

```yaml
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - uses: lite-actions/simple-commits-log@v1
  - run: cat CHANGELOG.md
```

On a `push` event the action defaults to the push event's `after` SHA, so it
logs the latest commit that landed on `main`.

To persist the generated changelog from a workflow, grant at least
`permissions: { contents: write }`. If your workflow updates `main` through a
PR like this repository does, it also needs `pull-requests: write` plus a token
that can push or open PRs. The PR-based automation in this repository also
assumes the GitHub CLI (`gh`) is available on the runner for PR creation,
approval, merge, and cleanup.

For GitHub merge commits, the action uses the PR title line when present so
entries still log the intended `type: message`. It also stores a hidden full-SHA
marker with each entry so reruns do not append the same commit twice.
