//! The evaluator: a syntax tree's value, and the variables lines bind.
//!
//! Nothing here can panic: every operator is a `checked_*`, and what
//! would panic is an error instead.

use alloc::string::String;
use hashmap::Map;

use crate::error::{Error, What};
use crate::parser::{Expr, Line, Op};

/// The variables bound so far, by name. It owns their names, so it
/// outlives the lines that bound them.
#[derive(Discard)]
pub struct Env { vars: Map<String, i64> }

impl Env {
    /// No variables.
    pub fn new() -> Env { Env { vars: Map::new() } }

    /// The value of `name`, if it's bound.
    pub fn get(&self, name: &str) -> Option<i64> {
        match self.vars.get(name) {
            Option::Some(v) => Option::Some(*v),
            Option::None => Option::None,
        }
    }

    /// Binds `name` to `value`, or rebinds it.
    pub fn set(&mut self, name: &str, value: i64) {
        match self.vars.get_mut(name) {
            Option::Some(v) => *v = value,
            Option::None => {
                self.vars.insert(String::from(name), value);
            },
        }
    }
}

/// What a line did.
#[derive(Discard, Copy)]
pub enum Done<'a> {
    /// Bound a name to a value.
    Bound(&'a str, i64),
    /// Worked out a value.
    Value(i64),
}

/// Runs `line`: works out its value, and binds it if it says to.
pub fn run<'a>(line: &Line<'a>, env: &mut Env) -> Result<Done<'a>, Error<'a>> {
    match line {
        Line::Let(name, e) => {
            let v = eval(e, env)?;
            env.set(*name, v);
            Result::Ok(Done::Bound(*name, v))
        },
        Line::Show(e) => Result::Ok(Done::Value(eval(e, env)?)),
    }
}

/// The value of `e`, with the variables in `env`.
pub fn eval<'a>(e: &Expr<'a>, env: &Env) -> Result<i64, Error<'a>> {
    match e {
        Expr::Num(n) => Result::Ok(*n),
        Expr::Var(name, at) => match env.get(*name) {
            Option::Some(v) => Result::Ok(v),
            Option::None => Result::Err(Error { what: What::UnknownVar(*name), at: *at }),
        },
        Expr::Neg(e, at) => match checked_neg(eval(e, env)?) {
            Option::Some(v) => Result::Ok(v),
            Option::None => Result::Err(Error { what: What::Overflow, at: *at }),
        },
        Expr::Bin(op, l, r, at) => {
            let l = eval(l, env)?;
            let r = eval(r, env)?;
            let what = match op {
                Op::Div | Op::Rem => if r == 0 { What::DivByZero } else { What::Overflow },
                _ => What::Overflow,
            };
            let v = match op {
                Op::Add => checked_add(l, r),
                Op::Sub => checked_sub(l, r),
                Op::Mul => checked_mul(l, r),
                Op::Div => checked_div(l, r),
                Op::Rem => checked_rem(l, r),
            };
            match v {
                Option::Some(v) => Result::Ok(v),
                Option::None => Result::Err(Error { what, at: *at }),
            }
        },
    }
}
