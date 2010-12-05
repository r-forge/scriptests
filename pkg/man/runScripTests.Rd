\name{runScripTests}
\alias{runScripTests}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{
  Run the tests in the tests directory of a package
}
\description{
  This function is not intended for interactive use, see
  \code{\link{runtests}()} for that.  This function is intended to be
  called from the file \code{runtests.R} in the \code{tests}
  subdirectory of a package.  The \code{runtests.R} file should contain
  these two lines:
  \preformatted{
    library(scriptests)
    runScripTests()
    }

}
\usage{
runScripTests(..., initializeFun = Quote(initializeTests()),
              finalizeFun = Quote(summarizeTests()),
              diffFun = Quote(ScripDiff()),
              subst = NULL, pattern = NULL, quit = TRUE)
}
\arguments{
  \item{\dots}{
}
\item{initializeFun}{
  Function for initializing tests.
}
  \item{finalizeFun}{
  Function for finalizing tests -- should compute a summary of test results.
}
\item{diffFun}{
  Function for checking differences between target output and actual
  test output.
}
  \item{subst}{
}
\item{pattern}{
  Only run tests whose filename matches this regular expression pattern.
}
\item{quit}{
  Call \code{q("no")} at the end?  Ignored in interactive sessions.
}
}
\details{
    When \code{runScripTests()} runs, it will create a \code{.R}
    file with the commands extracted from each \code{.Rt} file.  It will
    then run each \code{.R} file in a separate \code{R} session, save
    the output in a \code{.Rout} file, and compare the output with the
    \code{.Rt} file.  \code{runScripTests} will leave a summary in the
    file \code{test-summary.txt}.  If there are errors, the summary will
    be duplicated in the file \code{test-summary.fail} (the presence of
    a file ending in \code{.fail} signals an error to \code{"R CMD
    check"}.)
}
\value{
  \code{invisible(NULL)}
}
\author{ Tony Plate \email{tplate@acm.org}
}

% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ misc }
