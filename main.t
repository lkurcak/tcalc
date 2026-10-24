//! tcalc: a calculator of integers, with variables.
//!
//! T can't read input yet, so the lines it works out are written here.
//! Each is printed after `> `, and then its value or what's wrong with it.

use alloc::string::String;
use core::fmt::Write;

use error::{Error, What};
use eval::{Done, Env};
use lexer::Tok;

mod error;
mod eval;
mod lexer;
mod parser;

fn main() with {alloc, panic} {
    let mut env = Env::new();
    // Precedence and associativity.
    calc(&mut env, "1 + 2 * 3");
    calc(&mut env, "(1 + 2) * 3");
    calc(&mut env, "10 - 4 - 3");
    calc(&mut env, "100 / 10 / 5");
    calc(&mut env, "7 % 4 * 3");
    calc(&mut env, "-2 * 3");
    calc(&mut env, "--5");
    calc(&mut env, "-7 / 2");
    calc(&mut env, "-7 % 2");
    // Variables.
    calc(&mut env, "x = 2 * 3");
    calc(&mut env, "x * x");
    calc(&mut env, "y = x - 10");
    calc(&mut env, "x = y");
    calc(&mut env, "x + y");
    calc(&mut env, "long_name_2 = 9223372036854775807");
    // Errors.
    calc(&mut env, "2 $ 3");
    calc(&mut env, "1 + € 2");
    calc(&mut env, "1 +");
    calc(&mut env, "(1 + 2");
    calc(&mut env, "1 + 2)");
    calc(&mut env, "x y");
    calc(&mut env, "3 = 4");
    calc(&mut env, "");
    calc(&mut env, "z + 1");
    calc(&mut env, "1 / (x - y)");
    calc(&mut env, "5 % 0");
    calc(&mut env, "long_name_2 + 1");
    calc(&mut env, "-long_name_2 - 2");
    calc(&mut env, "99999999999999999999");
    // An error leaves the variables as they were.
    calc(&mut env, "x = 1 / 0");
    calc(&mut env, "x");
    env.free();
}

/// Prints `line`, and then its value, or where and what's wrong with it.
fn calc(env: &mut Env, line: &str) with {alloc, panic} {
    let mut echo = String::from("> ");
    echo.push_str(line);
    print_str(echo.as_str());
    echo.free();
    let done = match parser::parse(line) {
        Result::Ok(l) => eval::run(&l, env),
        Result::Err(e) => Result::Err(e),
    };
    let mut out = String::new();
    match done {
        Result::Ok(Done::Bound(name, v)) => {
            out.push_str(name);
            out.push_str(" = ");
            out.put(&v);
        },
        Result::Ok(Done::Value(v)) => {
            out.put(&v);
        },
        Result::Err(e) => report(&mut out, line, e),
    }
    print_str(out.as_str());
    out.free();
}

/// A `^` under where `e` is in `line`, which was printed after `> `, and
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
        Tok::Num(n) => {
            out.put(&n);
        },
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
