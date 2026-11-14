# Contributing

Work happens on `dev`; `main` only moves with releases. Branch from `dev` and open the pull request into `dev`:

```sh
git remote add upstream https://github.com/Nebelung-cloud/glyph-rice
git fetch upstream
git switch -c my-fix upstream/dev
```

Already branched from `main`? `git fetch upstream && git rebase --onto upstream/dev upstream/main`, then push again.

One change per pull request, and say how you tested it on a live session.
