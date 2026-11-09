//! tcalc: a calculator of integers, with variables.
//!
//! It reads lines, after a `> ` prompt, and writes the value of each, or
//! where and what's wrong with it, until its input ends. When its input
//! isn't typed at a terminal, it writes each line after its prompt too,
//! so what it writes reads as a session at one.

use alloc::arena::Arena;
use alloc::io::read_line;
use alloc::list::List;
use alloc::string::String;
use core::fmt::Write;
use core::io::{Bytes, Read};
use std::Os;

use error::{Error, What};
use eval::{Done, Env};
use lexer::Tok;
use lexer::Tok::{Assign, Close, End, Minus, Name, Num, Open, Percent, Plus, Slash, Star};

mod error;
mod eval;
mod lexer;
mod parser;

/// Works out each line of the input, echoing it if no one's typing it.
fn main(os: Os) -> Result<(), std::io::Error> {
    let mut input = os.stdin;
    let mut out = os.stdout;
    let echo = !input.is_terminal();
    session(&mut input, &mut out, echo)
}

/// Reads lines from `input` until there are no more, and works out each,
/// after a `> ` prompt, with the variables bound so far, writing to `out`.
/// If `echo`, writes each line after its prompt, as a terminal shows what's
/// typed.
fn session<R: Read, W: core::io::Write>(
    input: &mut R,
    out: &mut W,
    echo: bool,
) -> Result<(), std::io::Error> {
    let mut env = Env::new();
    let mut line = String::new();
    out.put("> ")?;
    while read_line(input, &mut line)? {
        if echo {
            out.line(&line.as_str())?;
        }
        out.line(&answer(&mut env, line.as_str()).as_str())?;
        out.put("> ")?;
    }
    out.line("")
}

/// The value of `line`, or where and what's wrong with it, as `calc`
/// writes it.
fn answer(env: &mut Env, line: &str) -> String {
    let nodes = Arena::new();
    let done = match parser::parse(line, &nodes) {
        Ok(l) => eval::run(&l, env),
        Err(e) => Err(e),
    };
    let mut text = String::new();
    match done {
        Ok(Done::Bound(name, v)) => {
            text.push_str(name);
            text.push_str(" = ");
            text.put(&v);
        },
        Ok(Done::Value(v)) => text.put(&v).into_ok(),
        Err(e) => report(&mut text, line, e),
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
        What::Unexpected(End) => out.push_str("unexpected end of input"),
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
        Num(n) => out.put(&n).into_ok(),
        Name(name) => out.push_str(name),
        Plus => out.push('+'),
        Minus => out.push('-'),
        Star => out.push('*'),
        Slash => out.push('/'),
        Percent => out.push('%'),
        Open => out.push('('),
        Close => out.push(')'),
        Assign => out.push('='),
        End => {},
    }
}

/// What each line gives, worked out in turn with the same variables.
#[blame_caller]
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

#[test]
fn a_session_reads_as_at_a_terminal() -> Result<(), std::io::Error> {
    let mut input = Bytes::new("x = 2 * 3\nx * x\n1 +".as_bytes());
    let mut out = List::new();
    session(&mut input, &mut out, true)?;
    let text = String::from_utf8(out).ok().expect("tcalc writes UTF-8");
    assert_eq(
        &text.as_str(),
        &"> x = 2 * 3\nx = 6\n> x * x\n36\n> 1 +\n     ^ unexpected end of input\n> \n",
    );
    Ok(())
}
