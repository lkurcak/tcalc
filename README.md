# tcalc

A calculator written in [T](https://github.com/lkurcak/t-lang), to find out
what using T for a real project is like. What got in the way is in
[FRICTION.md](FRICTION.md).

```text
> x = 2 * 3
x = 6
> (x + 1) * -x
-42
> 1 / (x - 6)
    ^ division by zero
```

It has integers (`i64`), `+ - * / %`, unary `-`, parentheses, and
variables. `/` and `%` round towards zero, as T's do. A bad line gets an
error saying where it is and what's wrong (an unknown character, an
unexpected token or end of input, an unknown variable, division by zero,
overflow), and the next line goes on as if it hadn't been there.

T can't read input yet, so the lines tcalc works out are written in
`main.t`. Running it prints each one after `> `, and then its value or its
error.

## Running it

```sh
t main.t          # run
tests/run.sh      # check: no warnings, formatted, output is tests/expected.txt
BLESS=1 tests/run.sh   # rewrite tests/expected.txt
```

It needs `t` 0.27.0, the version CI pins (in `.github/workflows/ci.yml`).
Any of these installs it:

- a release binary from <https://github.com/lkurcak/t-lang/releases>, which
  is what CI does, checking its SHA-256;
- `brew install lkurcak/tap/t-lang`;
- `cargo install t-lang --version 0.27.0` (needs a C compiler).

## How it's built

| File | What |
|---|---|
| `lexer.t` | the tokenizer: a `&str` as tokens, one at a time, each with the byte it starts at |
| `parser.t` | recursive descent into a syntax tree of enums and `Box`es |
| `eval.t` | the value of a tree, and the variables (`Env`) |
| `error.t` | what can go wrong with a line, and where |
| `main.t` | the lines, and printing what they give |

The grammar:

```text
line  = name "=" expr | expr
expr  = term { ("+" | "-") term }
term  = unary { ("*" | "/" | "%") unary }
unary = "-" unary | atom
atom  = number | name | "(" expr ")"
```

The evaluator can't panic, and its type says so: every operator is a
`checked_*` from T's core library, and what would overflow or divide by
zero is an error value instead. The tokenizer and parser say `with panic`;
FRICTION.md says why.
