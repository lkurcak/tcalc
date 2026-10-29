//! The parser: a line's tokens, as a syntax tree.
//!
//!     line  = name "=" expr | expr
//!     expr  = term { ("+" | "-") term }
//!     term  = unary { ("*" | "/" | "%") unary }
//!     unary = "-" unary | atom
//!     atom  = number | name | "(" expr ")"

use alloc::arena::Arena;

use crate::error::{Error, What};
use crate::lexer::{Lexer, Tok, Token};

/// A binary operator.
#[derive(Discard, Copy, Eq)]
pub enum Op { Add, Sub, Mul, Div, Rem }

/// An expression, whose parts are in an arena, as long as the line it's
/// of. Each operator and name has the byte of the line it's at, to say
/// where an error is.
#[derive(Discard, Copy)]
pub enum Expr<'a> {
    Num(i64),
    Var(&'a str, usize),
    Neg(&'a Expr<'a>, usize),
    Bin(Op, &'a Expr<'a>, &'a Expr<'a>, usize),
}

/// A line: a name bound to the value of an expression, or an expression
/// whose value is shown.
#[derive(Discard)]
pub enum Line<'a> { Let(&'a str, Expr<'a>), Show(Expr<'a>) }

/// The tree of `line`, with its parts in `nodes`, or the first thing
/// wrong with it.
pub fn parse<'a>(line: &'a str, nodes: &'a Arena<Expr<'a>>) -> Result<Line<'a>, Error<'a>> {
    let mut lexer = Lexer::new(line);
    let tok = lexer.next()?;
    let mut p = Parser { lexer, tok, nodes };
    let line = p.line()?;
    match p.tok.tok {
        Tok::End => Result::Ok(line),
        _ => Result::Err(p.unexpected()),
    }
}

/// Where it's up to: `tok` is the next token, and `lexer` is after it.
#[derive(Discard)]
struct Parser<'a> { lexer: Lexer<'a>, tok: Token<'a>, nodes: &'a Arena<Expr<'a>> }

impl<'a> Parser<'a> {
    /// `e`, put in the arena.
    fn node(&self, e: Expr<'a>) -> &'a Expr<'a> { self.nodes.alloc(e) }

    /// Moves on to the next token.
    fn bump(&mut self) -> Result<(), Error<'a>> {
        self.tok = self.lexer.next()?;
        Result::Ok(())
    }

    /// The error for the token it's at, which can't be there.
    fn unexpected(&self) -> Error<'a> {
        Error { what: What::Unexpected(self.tok.tok), at: self.tok.at }
    }

    fn line(&mut self) -> Result<Line<'a>, Error<'a>> {
        // `name =` starts a binding: look one token past the name, on a
        // copy of the lexer.
        match self.tok.tok {
            Tok::Name(name) => {
                let mut ahead = self.lexer;
                match ahead.next() {
                    Result::Ok(Token { tok: Tok::Assign, .. }) => {
                        self.lexer = ahead;
                        self.bump()?;
                        return Result::Ok(Line::Let(name, self.expr()?));
                    },
                    _ => {},
                }
            },
            _ => {},
        }
        Result::Ok(Line::Show(self.expr()?))
    }

    fn expr(&mut self) -> Result<Expr<'a>, Error<'a>> {
        let mut lhs = self.term()?;
        loop {
            let op = match self.tok.tok {
                Tok::Plus => Op::Add,
                Tok::Minus => Op::Sub,
                _ => return Result::Ok(lhs),
            };
            let at = self.tok.at;
            self.bump()?;
            let rhs = self.term()?;
            lhs = Expr::Bin(op, self.node(lhs), self.node(rhs), at);
        }
    }

    fn term(&mut self) -> Result<Expr<'a>, Error<'a>> {
        let mut lhs = self.unary()?;
        loop {
            let op = match self.tok.tok {
                Tok::Star => Op::Mul,
                Tok::Slash => Op::Div,
                Tok::Percent => Op::Rem,
                _ => return Result::Ok(lhs),
            };
            let at = self.tok.at;
            self.bump()?;
            let rhs = self.unary()?;
            lhs = Expr::Bin(op, self.node(lhs), self.node(rhs), at);
        }
    }

    fn unary(&mut self) -> Result<Expr<'a>, Error<'a>> {
        match self.tok.tok {
            Tok::Minus => {
                let at = self.tok.at;
                self.bump()?;
                Result::Ok(Expr::Neg(self.node(self.unary()?), at))
            },
            _ => self.atom(),
        }
    }

    fn atom(&mut self) -> Result<Expr<'a>, Error<'a>> {
        let e = match self.tok.tok {
            Tok::Num(n) => Expr::Num(n),
            Tok::Name(name) => Expr::Var(name, self.tok.at),
            Tok::Open => {
                self.bump()?;
                let e = self.expr()?;
                match self.tok.tok {
                    Tok::Close => e,
                    _ => return Result::Err(self.unexpected()),
                }
            },
            _ => return Result::Err(self.unexpected()),
        };
        self.bump()?;
        Result::Ok(e)
    }
}
