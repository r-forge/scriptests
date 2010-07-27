\name{ScripDiff}
\alias{ScripDiff}
\alias{initializeTests}
\alias{summarizeTests}
\title{
  Support functions for package scriptests
}
\description{
  These are support functions for package scriptests.  They are called
  to prepare a test directory for running tests, compare the output of
  each test with target out, and summarize test results.
}
\usage{
ScripDiff(commandfile, outfile = gsub("\\\\.R$", ".Rout", commandfile, perl = TRUE), savefile = paste(outfile, ".save", sep = ""), debug = FALSE)
initializeTests(debug = FALSE, create.Rout.save = FALSE, addSelfCheck = FALSE, pattern = NULL, subst = NULL)
summarizeTests(debug = FALSE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{commandfile}{
%%     ~~Describe \code{commandfile} here~~
}
  \item{outfile}{
%%     ~~Describe \code{outfile} here~~
}
  \item{savefile}{
%%     ~~Describe \code{savefile} here~~
}
  \item{debug}{
%%     ~~Describe \code{debug} here~~
}
  \item{create.Rout.save}{
}
  \item{addSelfCheck}{
}
  \item{pattern}{
}
  \item{subst}{
}
}
\details{
  \describe{
    \item{\code{initializeTests}}{ }
    \item{\code{ScripDiff}}{ }
    \item{\code{summarizeTests}}{ }
  }
}
\value{
  Returns the value \code{0} on successful completion.
}
\author{
  Tony Plate \email{tplate@acm.org}
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\keyword{ misc }
