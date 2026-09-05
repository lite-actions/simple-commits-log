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
