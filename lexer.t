// The tokenizer: a line of text, as tokens, one at a time.

use crate::error::{Error, What};

/// What a token is.
#[derive(Discard, Copy, Eq)]
pub enum Tok<'a> {
    Num(i64),
    Name(&'a str),
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Open,
    Close,
    Assign,
    /// The end of the line, after which there are only more `End`s.
    End,
}

/// A token, and the byte of the line it starts at.
#[derive(Discard, Copy)]
pub struct Token<'a> { pub tok: Tok<'a>, pub at: usize }

/// Where it's up to in a line: `rest` is what's left of it, from byte
/// `at` on. It's `Copy`, so a copy can look ahead and be thrown away.
#[derive(Discard, Copy)]
pub struct Lexer<'a> { rest: &'a str, at: usize }

impl<'a> Lexer<'a> {
    /// A lexer at the start of `line`.
    pub fn new(line: &'a str) -> Lexer<'a> { Lexer { rest: line, at: 0 } }

    /// The next token, or what's wrong with the text where it would be.
    pub fn next(&mut self) -> Result<Token<'a>, Error<'a>> with panic {
        self.skip_spaces();
        let at = self.at;
        let c = match self.rest.chars().next() {
            Option::Some(c) => c,
            Option::None => return Result::Ok(Token { tok: Tok::End, at }),
        };
        let tok = match c {
            '0'..='9' => return self.number(),
            'a'..='z' | 'A'..='Z' | '_' => Tok::Name(self.name()),
            '+' => Tok::Plus,
            '-' => Tok::Minus,
            '*' => Tok::Star,
            '/' => Tok::Slash,
            '%' => Tok::Percent,
            '(' => Tok::Open,
            ')' => Tok::Close,
            '=' => Tok::Assign,
            _ => return Result::Err(Error { what: What::UnknownChar(c), at }),
        };
        match tok {
            Tok::Name(_) => {},
            _ => self.skip(1),
        }
        Result::Ok(Token { tok, at })
    }

    /// Skips spaces and tabs.
    fn skip_spaces(&mut self) with panic {
        loop {
            match self.rest.chars().next() {
                Option::Some(' ' | '\t') => self.skip(1),
                _ => return,
            }
        }
    }

    /// Skips `n` bytes, which must end where a character does.
    fn skip(&mut self, n: usize) with panic {
        let rest = self.rest;
        self.rest = rest.split_at(n).expect("skipping whole characters").tail;
        self.at = self.at + n;
    }

    /// The decimal digits from here on, as a number.
    fn number(&mut self) -> Result<Token<'a>, Error<'a>> with panic {
        let at = self.at;
        let mut value: Option<i64> = Option::Some(0);
        loop {
            let digit = match self.rest.chars().next() {
                Option::Some(c) => match c {
                    '0'..='9' => (c as u32 - 0x30) as i64,
                    _ => break,
                },
                Option::None => break,
            };
            self.skip(1);
            // Once it's too big, it stays `None`, and the digits go on.
            value = match value {
                Option::Some(v) => match checked_mul(v, 10) {
                    Option::Some(v) => checked_add(v, digit),
                    Option::None => Option::None,
                },
                Option::None => Option::None,
            };
        }
        match value {
            Option::Some(v) => Result::Ok(Token { tok: Tok::Num(v), at }),
            Option::None => Result::Err(Error { what: What::Overflow, at }),
        }
    }

    /// The name from here on: letters, digits and `_`.
    fn name(&mut self) -> &'a str with panic {
        let start = self.rest;
        let mut n = 0usize;
        for c in start.chars() {
            match c {
                'a'..='z' | 'A'..='Z' | '0'..='9' | '_' => n = n + 1,
                _ => break,
            }
        }
        self.skip(n);
        start.split_at(n).expect("a name is ASCII").head
    }
}
