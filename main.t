//! tcalc: a calculator of integers, with variables.
//!
//! It reads lines, after a `> ` prompt, and writes the value of each, or
//! where and what's wrong with it, until its input ends.

use alloc::arena::Arena;
use alloc::string::String;
use core::fmt::Write;
use std::io::Stdout;
use std::Os;

use error::{Error, What};
use eval::{Done, Env};
use lexer::Tok;

mod error;
mod eval;
mod lexer;
mod parser;

/// Reads lines until there are no more, and works out each, after a
/// `> ` prompt, with the variables bound so far.
fn main(os: Os) -> Result<(), std::io::Error> {
    let mut input = os.stdin;
    let mut out = os.stdout;
    let mut env = Env::new();
    let mut line = String::new();
    out.put(&"> ")?;
    while input.read_line(&mut line)? {
        calc(&mut out, &mut env, line.as_str())?;
        out.put(&"> ")?;
    }
    out.line(&"")
}

/// Writes the value of `line`, or where and what's wrong with it.
fn calc(out: &mut Stdout, env: &mut Env, line: &str) -> Result<(), std::io::Error> {
    out.line(&answer(env, line).as_str())
}

/// The value of `line`, or where and what's wrong with it, as `calc`
/// writes it.
fn answer(env: &mut Env, line: &str) -> String {
    let nodes = Arena::new();
    let done = match parser::parse(line, &nodes) {
        Result::Ok(l) => eval::run(&l, env),
        Result::Err(e) => Result::Err(e),
    };
    let mut text = String::new();
    match done {
        Result::Ok(Done::Bound(name, v)) => {
            text.push_str(name);
            text.push_str(" = ");
            text.put(&v);
        },
        Result::Ok(Done::Value(v)) => text.put(&v).into_ok(),
        Result::Err(e) => report(&mut text, line, e),
    }
    text
}

/// A `^` under where `e` is in `line`, which was typed after `> `, and
/// then what's wrong.
fn report(out: &mut String, line: &str, e: Error) {
    // The caret goes under the character, so count characters, not bytes.
    let before = line.split_at(e.at).expect("an error is where a character starts").head;
    let column = before.chars().count();
    out.push_str("  ");
    for _ in 0..column {
        out.push(' ');
    }
    out.push_str("^ ");
    match e.what {
        What::UnknownChar(c) => {
            out.push_str("unknown character `");
            out.push(c);
            out.push('`');
        },
        What::Unexpected(Tok::End) => out.push_str("unexpected end of input"),
        What::Unexpected(t) => {
            out.push_str("unexpected `");
            push_tok(out, t);
            out.push('`');
        },
        What::UnknownVar(name) => {
            out.push_str("unknown variable `");
            out.push_str(name);
            out.push('`');
        },
        What::DivByZero => out.push_str("division by zero"),
        What::Overflow => out.push_str("overflow: the value doesn't fit in an `i64`"),
    }
}

/// Puts how `t` is written at the end of `out`.
fn push_tok(out: &mut String, t: Tok) {
    match t {
        Tok::Num(n) => out.put(&n).into_ok(),
        Tok::Name(name) => out.push_str(name),
        Tok::Plus => out.push('+'),
        Tok::Minus => out.push('-'),
        Tok::Star => out.push('*'),
        Tok::Slash => out.push('/'),
        Tok::Percent => out.push('%'),
        Tok::Open => out.push('('),
        Tok::Close => out.push(')'),
        Tok::Assign => out.push('='),
        Tok::End => {},
    }
}

/// What each line gives, worked out in turn with the same variables.
fn answers(lines: &[&str], want: &[&str]) {
    let mut env = Env::new();
    assert_eq(&lines.len(), &want.len());
    let mut i: usize = 0;
    while i < lines.len() && i < want.len() {
        let got = answer(&mut env, lines[i]);
        assert_eq(&got.as_str(), &want[i]);
        i = i + 1;
    }
}

#[test]
fn precedence_and_associativity() {
    answers(
        ["1 + 2 * 3", "(1 + 2) * 3", "10 - 4 - 3", "100 / 10 / 5", "7 % 4 * 3"].as_slice(),
        ["7", "9", "3", "2", "9"].as_slice(),
    );
}

#[test]
fn negation_rounds_toward_zero() {
    answers(["-2 * 3", "--5", "-7 / 2", "-7 % 2"].as_slice(), ["-6", "5", "-3", "-1"].as_slice());
}

#[test]
fn variables_bind_and_rebind() {
    answers(
        ["x = 2 * 3", "x * x", "y = x - 10", "x = y", "x + y"].as_slice(),
        ["x = 6", "36", "y = -4", "x = -4", "-8"].as_slice(),
    );
}

#[test]
fn errors_say_where() {
    answers(
        ["2 $ 3", "1 +", "1 + 2)", "z + 1", "5 % 0", "99999999999999999999"].as_slice(),
        [
            "    ^ unknown character `$`",
            "     ^ unexpected end of input",
            "       ^ unexpected `)`",
            "  ^ unknown variable `z`",
            "    ^ division by zero",
            "  ^ overflow: the value doesn't fit in an `i64`",
        ].as_slice(),
    );
}

#[test]
fn an_error_binds_nothing() {
    answers(
        ["x = 1 / 0", "x"].as_slice(),
        ["        ^ division by zero", "  ^ unknown variable `x`"].as_slice(),
    );
}
