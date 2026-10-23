# Friction log

What got in the way of writing tcalc in T, with the code that hit it.
Each entry is labelled:

- **gap**: T should have it;
- **by design**: T leaves it out on purpose, and the entry says what that
  costs here;
- **unsure**: not clear which.

The log is evidence for t-lang's plans, not a design for them.

Written against `t` 0.26.0.

## No stdin — gap

T has no way to read input, so tcalc can't be a calculator you type into.
Its lines are string literals in `main.t`, and its output is checked
against a file:

```rust,ignore
calc(&mut env, "x = 2 * 3");
calc(&mut env, "x * x");
```

Because each line is a `&'static str`, the program never has to own a
line it read, which is where real input would make a difference: the
variables already copy their names into `String`s (`Env::set`), so that
part would carry over.

## No `?` — gap

Every fallible call is a four-line `match`. `parser.t` has twelve of
these, and `eval.t` two:

```rust,ignore
let rhs = match self.term() {
    Result::Ok(e) => e,
    Result::Err(e) => return Result::Err(e),
};
```

and a call made only for its error is the same with `()`:

```rust,ignore
match self.bump() {
    Result::Ok(()) => {},
    Result::Err(e) => return Result::Err(e),
}
```

About a third of `parser.t` is this. The docs (`05.1-control-flow.md`) say
`?` waits for a trait that says what can be returned early.

## No formatting, and `print_str` prints whole lines — gap

There's no `format!`, no `Display`, no way to turn an integer into text,
and `print_str` prints one line per call, so a line of output made of
pieces has to be built in a `String` first. tcalc has its own integer to
decimal:

```rust,ignore
fn push_digits(out: &mut String, m: { v: i64 | v <= 0 }) with {alloc, panic} {
    if m <= -10 {
        push_digits(out, m / 10);
    }
    let digit = -(m % 10);
    out.push((digit as u32 + 0x30) as char);
}
```

(The refinement made writing it pleasant: the checker proves `m / 10`,
`m % 10` and the negation can't go wrong, and working with `-|n|` handles
the least `i64`. But every program will write this.)

Printing `> ` before a line takes a `String`, a `push_str` and a `free`
too (`calc` in `main.t`).

## Every `String` must be freed by hand — by design

`String` isn't `Discard`, so each one is used up by `free()`. `calc` makes
two per line and frees both; `Env` holds names, so it isn't `Discard`
either, and takes them apart to free them:

```rust,ignore
pub fn free(self) {
    let Env { vars } = self;
    vars.free_with(|v| {
        let Var { name, .. } = v;
        name.free();
    });
}
```

This is linearity working as meant: forgetting a `free` is a compile
error, not a leak. The cost is the lines above and a `free` after each
`print_str(s.as_str())`. Nothing is needed for the syntax tree: `Expr` is
`#[derive(Discard)]` and holds only `Box`es, `i64`s and `&str`s, so it's
freed when it goes out of scope, which is as easy as in a GC'd language.

## Positions in a line need `with panic` — unsure

The tokenizer keeps `at`, the byte it's up to, and adds to it as it skips
a token:

```rust,ignore
fn skip(&mut self, n: usize) with panic {
    let rest = self.rest;
    self.rest = rest.split_at(n).expect("skipping whole characters").tail;
    self.at = self.at + n;
}
```

`at + n` is at most the line's length, so it can't overflow, but nothing
can say so: a refinement can't name `rest.len()` (measures don't exist
yet, `08-refinement-types.md`). Likewise the `expect` can't fail, as `n`
counts whole characters, but `split_at` gives an `Option`. So the
tokenizer says `with panic`, and so does everything that calls it, though
none of it can panic. A gap if measures are coming; by design if `with
panic` is the honest answer here.

## `Box::new` is `with {alloc, panic}` — by design

The parser builds `Box`es, so it says `with {alloc, panic}`: running out
of memory aborts. That's honest, but it means the parser's type can't
tell "may abort on out-of-memory" from "has a bug that panics". Together
with the entry above, only the evaluator ends up with a type saying it
can't panic.

## No hash map — gap

Variables are a `List` searched front to back (`Env::get`, `Env::set`).
Fine for a calculator; a map would need hashing or `Ord` on keys, and a
`List<(String, i64)>` would need tuples, so it's a `struct Var`.

## No pattern guards — by design

Taking a digit in the tokenizer wants `Option::Some(c) if c.is_ascii_digit()`;
without guards it's a nested `match` (which, as a bonus, tells the checker
`c` is between `'0'` and `'9'`, so `c as u32 - 0x30` can't underflow):

```rust,ignore
let digit = match self.rest.chars().next() {
    Option::Some(c) => match c {
        '0'..='9' => (c as u32 - 0x30) as i64,
        _ => break,
    },
    Option::None => break,
};
```

`02-adts.md` leaves guards out because they make exhaustiveness
approximate. The cost here was small.

## No test command — gap

`tests/run.sh` runs `t check`, `t fmt --check` and the program, and diffs
the output against `tests/expected.txt`. It also fails on warnings, which
`t check` prints but doesn't fail on, so it has to look at what `t check`
printed. Something like `t test`, or the `// expect:` comments the
compiler's own tests use, would replace it.

## Installing a pinned `t` — not friction

The release binaries have SHA-256 digests (`gh release view v0.26.0 -R
lkurcak/t-lang --json assets`), so CI downloads one by URL and checks it,
with no Rust toolchain. Locally, a Homebrew install had stayed at 0.23.0
while 0.26.0 was out, which is Homebrew's way, not T's.

## Expected, but didn't hurt

- **Tuples.** `Lexer::next` gives a `Token { tok, at }`, which reads
  better than a tuple would.
- **`Clone`.** Never needed: names are copied with `String::from`.
