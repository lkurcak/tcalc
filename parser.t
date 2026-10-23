// The parser: a line's tokens, as a syntax tree.
//
//     line  = name "=" expr | expr
//     expr  = term { ("+" | "-") term }
//     term  = unary { ("*" | "/" | "%") unary }
//     unary = "-" unary | atom
//     atom  = number | name | "(" expr ")"

use crate::error::{Error, What};
use crate::lexer::{Lexer, Tok, Token};

/// A binary operator.
#[derive(Discard, Copy, Eq)]
pub enum Op { Add, Sub, Mul, Div, Rem }

/// An expression. Each operator and name has the byte of the line it's
/// at, to say where an error is.
#[derive(Discard)]
pub enum Expr<'a> {
    Num(i64),
    Var(&'a str, usize),
    Neg(Box<Expr<'a>>, usize),
    Bin(Op, Box<Expr<'a>>, Box<Expr<'a>>, usize),
}

/// A line: a name bound to the value of an expression, or an expression
/// whose value is shown.
#[derive(Discard)]
pub enum Line<'a> { Let(&'a str, Expr<'a>), Show(Expr<'a>) }

/// The tree of `line`, or the first thing wrong with it.
pub fn parse(line: &str) -> Result<Line, Error> with {alloc, panic} {
    let mut lexer = Lexer::new(line);
    let tok = match lexer.next() {
        Result::Ok(t) => t,
        Result::Err(e) => return Result::Err(e),
    };
    let mut p = Parser { lexer, tok };
    let line = match p.line() {
        Result::Ok(l) => l,
        Result::Err(e) => return Result::Err(e),
    };
    match p.tok.tok {
        Tok::End => Result::Ok(line),
        _ => Result::Err(p.unexpected()),
    }
}

/// Where it's up to: `tok` is the next token, and `lexer` is after it.
#[derive(Discard)]
struct Parser<'a> { lexer: Lexer<'a>, tok: Token<'a> }

impl<'a> Parser<'a> {
    /// Moves on to the next token.
    fn bump(&mut self) -> Result<(), Error<'a>> with panic {
        match self.lexer.next() {
            Result::Ok(t) => {
                self.tok = t;
                Result::Ok(())
            },
            Result::Err(e) => Result::Err(e),
        }
    }

    /// The error for the token it's at, which can't be there.
    fn unexpected(&self) -> Error<'a> {
        Error { what: What::Unexpected(self.tok.tok), at: self.tok.at }
    }

    fn line(&mut self) -> Result<Line<'a>, Error<'a>> with {alloc, panic} {
        // `name =` starts a binding: look one token past the name, on a
        // copy of the lexer.
        match self.tok.tok {
            Tok::Name(name) => {
                let mut ahead = self.lexer;
                match ahead.next() {
                    Result::Ok(Token { tok: Tok::Assign, .. }) => {
                        self.lexer = ahead;
                        match self.bump() {
                            Result::Ok(()) => {},
                            Result::Err(e) => return Result::Err(e),
                        }
                        return match self.expr() {
                            Result::Ok(e) => Result::Ok(Line::Let(name, e)),
                            Result::Err(e) => Result::Err(e),
                        };
                    },
                    _ => {},
                }
            },
            _ => {},
        }
        match self.expr() {
            Result::Ok(e) => Result::Ok(Line::Show(e)),
            Result::Err(e) => Result::Err(e),
        }
    }

    fn expr(&mut self) -> Result<Expr<'a>, Error<'a>> with {alloc, panic} {
        let mut lhs = match self.term() {
            Result::Ok(e) => e,
            Result::Err(e) => return Result::Err(e),
        };
        loop {
            let op = match self.tok.tok {
                Tok::Plus => Op::Add,
                Tok::Minus => Op::Sub,
                _ => return Result::Ok(lhs),
            };
            let at = self.tok.at;
            match self.bump() {
                Result::Ok(()) => {},
                Result::Err(e) => return Result::Err(e),
            }
            let rhs = match self.term() {
                Result::Ok(e) => e,
                Result::Err(e) => return Result::Err(e),
            };
            lhs = Expr::Bin(op, Box::new(lhs), Box::new(rhs), at);
        }
    }

    fn term(&mut self) -> Result<Expr<'a>, Error<'a>> with {alloc, panic} {
        let mut lhs = match self.unary() {
            Result::Ok(e) => e,
            Result::Err(e) => return Result::Err(e),
        };
        loop {
            let op = match self.tok.tok {
                Tok::Star => Op::Mul,
                Tok::Slash => Op::Div,
                Tok::Percent => Op::Rem,
                _ => return Result::Ok(lhs),
            };
            let at = self.tok.at;
            match self.bump() {
                Result::Ok(()) => {},
                Result::Err(e) => return Result::Err(e),
            }
            let rhs = match self.unary() {
                Result::Ok(e) => e,
                Result::Err(e) => return Result::Err(e),
            };
            lhs = Expr::Bin(op, Box::new(lhs), Box::new(rhs), at);
        }
    }

    fn unary(&mut self) -> Result<Expr<'a>, Error<'a>> with {alloc, panic} {
        match self.tok.tok {
            Tok::Minus => {
                let at = self.tok.at;
                match self.bump() {
                    Result::Ok(()) => {},
                    Result::Err(e) => return Result::Err(e),
                }
                match self.unary() {
                    Result::Ok(e) => Result::Ok(Expr::Neg(Box::new(e), at)),
                    Result::Err(e) => Result::Err(e),
                }
            },
            _ => self.atom(),
        }
    }

    fn atom(&mut self) -> Result<Expr<'a>, Error<'a>> with {alloc, panic} {
        let e = match self.tok.tok {
            Tok::Num(n) => Expr::Num(n),
            Tok::Name(name) => Expr::Var(name, self.tok.at),
            Tok::Open => {
                match self.bump() {
                    Result::Ok(()) => {},
                    Result::Err(e) => return Result::Err(e),
                }
                let e = match self.expr() {
                    Result::Ok(e) => e,
                    Result::Err(e) => return Result::Err(e),
                };
                match self.tok.tok {
                    Tok::Close => e,
                    _ => return Result::Err(self.unexpected()),
                }
            },
            _ => return Result::Err(self.unexpected()),
        };
        match self.bump() {
            Result::Ok(()) => Result::Ok(e),
            Result::Err(e) => Result::Err(e),
        }
    }
}
