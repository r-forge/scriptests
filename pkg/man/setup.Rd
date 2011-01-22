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
ScripDiff(commandfile, outfile = NULL, savefile = NULL, debug = FALSE, R.suf = "R")
initializeTests(debug = FALSE, create.Rout.save = FALSE, addSelfCheck = FALSE, pattern = NULL, subst = NULL, R.suf = "R")
summarizeTests(debug = FALSE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{commandfile}{
    The name of the file containing R commands.
}
  \item{outfile}{
    The name of the file containing R output.
}
\item{savefile}{
  The name of the file containing pre-existing R output to compare against.
}
\item{debug}{
  Debugging flag.
}
\item{create.Rout.save}{
  Should a \code{.Rout.save} file be created.  Default is \code{FALSE}.
}
  \item{addSelfCheck}{
  Controls an unused an obselete feature of adding extra code to the end
  of the R commands that will check the output created.
}
\item{pattern}{
  Only process test files whose name matches \code{pattern}
}
\item{subst}{
  Substitutions to make when parsing the transcript file.
}
\item{R.suf}{
  The suffix (not including a dot) to use for auto-generated files containing R commands.
}
}
\details{
  \describe{
    \item{\code{initializeTests}}{Pre-process tests, writing commands
      to a file, and creating a file with a saved R object containing
      information to analyze the results of the test.}
    \item{\code{ScripDiff}}{Compare test output against desired output
      and summarize the differences.}
    \item{\code{summarizeTests}}{Summarize the results of all tests.}
  }
}
\value{
  Returns the value \code{0} on successful completion.
}
\author{
  Tony Plate \email{tplate@acm.org}
}
\keyword{ misc }
