// What can go wrong with a line, and where.

use crate::lexer::Tok;

/// Why a line has no value.
#[derive(Discard, Copy)]
pub enum What<'a> {
    /// A character that starts no token.
    UnknownChar(char),
    /// A token where it can't be: `End` for the end of the line.
    Unexpected(Tok<'a>),
    /// A name nothing has been bound to.
    UnknownVar(&'a str),
    /// `/` or `%` by zero.
    DivByZero,
    /// A number that doesn't fit in an `i64`, written or worked out.
    Overflow,
}

/// What went wrong, and at which byte of the line.
#[derive(Discard, Copy)]
pub struct Error<'a> { pub what: What<'a>, pub at: usize }
