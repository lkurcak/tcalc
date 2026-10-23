# tcalc

A calculator written in T, the language at `~/repos/tooling/t-lang`
(GitHub: lkurcak/t-lang), from scratch, the way T wants to be written.
Its real purpose is to find out what using T for a real project is like.
It's the first T program outside the compiler's repo.

## Scope

A first version is done when it has:

- integers, `+ - * / %`, unary `-`, parentheses, and the usual precedence
  and associativity;
- variables: `x = 2 * 3` binds `x`, and later lines can use it;
- an error for each kind of bad input, with where it is: an unknown
  character, an unexpected token or end of input, an unknown variable,
  division by zero, overflow. It goes on with the next line, rather than
  stopping;
- three parts, as modules in files: a tokenizer (over `str`), a parser
  (into a syntax tree of enums and `Box`es), and an evaluator.

Anything beyond that (floats, functions, a REPL once there's stdin) the
author decides.

## What T is

T is a soundness-first systems language. It has no GC, effects in
function types (`with {alloc, panic}`), linear types (values must be
used up unless `Discard`), refinement types, traits and modules. `t` is
an interpreter for now. Before writing T, read the compiler repo's
`README.md` and `docs/` (the step docs, from `01-stlc.md` to
`14-packages.md`). `tests/t/*.t` has more than a thousand small
programs, and `examples/` has a few more. The libraries built into `t`
are in `core/` and `alloc/` (`Option`, `Result`, `Iterator`, `List`,
`String`, `str`). There's no `std` yet.

Commands: `t <file.t>` runs a program, `t check`, `t mono`, `t fmt
[--check]`, `t lsp`. A program starts in `main.t`, and `mod m;` reads
`m.t` next to it.

## The plan (agreed 2026-10-24)

1. Start minimal: `main.t` plus modules in files, a README, and a CI
   (GitHub Actions) that installs a *pinned* `t` and runs `t check`,
   `t fmt --check`, and the program against expected output with a
   shell script. Installing `t`: the t-lang release binaries, the
   Homebrew formula, or `cargo install t-lang`. Finding out which works
   is part of the point.
2. Write tcalc in plain T as it is today. T can't read input yet (no
   stdin), so at first tcalc evaluates expressions written in its source
   and prints the results.
3. Keep a friction log (`FRICTION.md`): every language, library or
   tooling gap, each with the code that hit it. The first entry is
   "no stdin". Label each entry: a *gap* (T should have it: no `?`, no
   stdin), *by design* (T leaves it out on purpose, as freeing a tree
   since there's no GC; write down what it costs), or *unsure*. Expect
   missing tuples, `Clone`, `?`, hash maps, a test command, a manifest and
   dependencies.
4. Don't design manifests, dependencies or `t test` here. Only gather
   evidence. The log becomes steps for t-lang, planned there.

## How the author likes to work

- Soundness and principled design first. Ask before decisions that are
  the author's to make, one at a time, each with a recommendation.
- Commit work in progress at milestones. `git` over ssh doesn't work in
  Claude's shell, so push and fetch over https with `gh auth setup-git`
  and the https URL.
- If T itself has a bug or gap that blocks tcalc, note it in the friction
  log and tell the author. Don't change t-lang from here.
