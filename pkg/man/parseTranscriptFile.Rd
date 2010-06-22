\name{parseTranscriptFile}
\alias{parseTranscriptFile}
\title{ Parse a R transcript file into blocks of commands and output }
\description{
Parse a R transcript file into blocks of commands and output.
}
\usage{
parseTranscriptFile(file, ignoreUpToRegExpr = NULL, ignoreAfterRegExpr=NULL, subst=NULL)
}
\arguments{
  \item{file}{ The name of the file containing transcripts. }
  \item{ignoreUpToRegExpr}{ If non-NULL, discard lines in the file up to and
    including the line that matches this regular expression. }
  \item{ignoreAfterRegExpr}{ If non-NULL, discard lines in the file
    including and beyond the line that matches this regular expression. }
  \item{subst}{ Provides control over whether the string "pacakge:::" is
    removed from test code.  The default value should work. }
}
\details{
  Tries to split the lines in \code{file} up into blocks with the
  following structure:
  \itemize{
    \item{commments}{: lines preceeding the test that begin with \code{> #}
    or that are empty}
    \item{command}{: line beginning with \code{>} and subsequent lines
    beginning with the continuation char \code{+}}
    \item{control}{: lines following the command that begin with \code{#@}}
    \item{output}{: other lines following the command and before the next
    comment or command, which are presumed to be output from the command}
  }
}
\value{
  A list of commands and their associated (apparent) output.
  Each element of the list is a list with the following possible components:
  \item{comment}{A character vector containing the lines that were interpreted as comments}
  \item{input}{A character vector containing the lines that were
    interpreted as commands}
  \item{expr}{The parsed input (an expression).  Will be a character
    vector containing an error message if the input could not be parsed
    as an R expression.}
  \item{control}{A character vector containing the lines that were
    interpreted as control lines}
  \item{output}{A character vector containing the lines that were
    interpreted as output lines}
}
\author{ Tony Plate }
\keyword{ misc }
