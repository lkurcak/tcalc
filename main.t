//! tcalc: a calculator of integers, with variables.
//!
//! The lines it works out are written here, for now. Each is written
//! after `> `, and then its value or what's wrong with it.

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

fn main(os: Os) -> Result<(), std::io::Error> with {alloc, panic} {
    let mut out = os.stdout;
    let mut env = Env::new();
    let done = examples(&mut out, &mut env);
    env.free();
    done
}

/// Works out each line, one after another, with the variables in `env`.
fn examples(out: &mut Stdout, env: &mut Env) -> Result<(), std::io::Error> with {alloc, panic} {
    // Precedence and associativity.
    calc(out, env, "1 + 2 * 3")?;
    calc(out, env, "(1 + 2) * 3")?;
    calc(out, env, "10 - 4 - 3")?;
    calc(out, env, "100 / 10 / 5")?;
    calc(out, env, "7 % 4 * 3")?;
    calc(out, env, "-2 * 3")?;
    calc(out, env, "--5")?;
    calc(out, env, "-7 / 2")?;
    calc(out, env, "-7 % 2")?;
    // Variables.
    calc(out, env, "x = 2 * 3")?;
    calc(out, env, "x * x")?;
    calc(out, env, "y = x - 10")?;
    calc(out, env, "x = y")?;
    calc(out, env, "x + y")?;
    calc(out, env, "long_name_2 = 9223372036854775807")?;
    // Errors.
    calc(out, env, "2 $ 3")?;
    calc(out, env, "1 + € 2")?;
    calc(out, env, "1 +")?;
    calc(out, env, "(1 + 2")?;
    calc(out, env, "1 + 2)")?;
    calc(out, env, "x y")?;
    calc(out, env, "3 = 4")?;
    calc(out, env, "")?;
    calc(out, env, "z + 1")?;
    calc(out, env, "1 / (x - y)")?;
    calc(out, env, "5 % 0")?;
    calc(out, env, "long_name_2 + 1")?;
    calc(out, env, "-long_name_2 - 2")?;
    calc(out, env, "99999999999999999999")?;
    // An error leaves the variables as they were.
    calc(out, env, "x = 1 / 0")?;
    calc(out, env, "x")
}

/// Writes `line`, and then its value, or where and what's wrong with it.
fn calc(out: &mut Stdout, env: &mut Env, line: &str) -> Result<(), std::io::Error>
with {alloc, panic}
{
    out.put(&"> ")?;
    out.line(&line)?;
    let done = match parser::parse(line) {
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
    let written = out.line(&text.as_str());
    text.free();
    written
}

/// A `^` under where `e` is in `line`, which was written after `> `, and
/// then what's wrong.
fn report(out: &mut String, line: &str, e: Error) with {alloc, panic} {
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
fn push_tok(out: &mut String, t: Tok) with alloc {
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
