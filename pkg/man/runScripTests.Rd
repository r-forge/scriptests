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
    library(ScripTests)
    runScripTests()
    }

}
\usage{
runScripTests(..., initializeFun = Quote(initializeTests()), finalizeFun = Quote(summarizeTests()), diffFun = Quote(ScripDiff()), subst = NULL, quit = TRUE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{\dots}{
%%     ~~Describe \code{\dots} here~~
}
  \item{initializeFun}{
%%     ~~Describe \code{initializeFun} here~~
}
  \item{finalizeFun}{
%%     ~~Describe \code{finalizeFun} here~~
}
  \item{diffFun}{
%%     ~~Describe \code{diffFun} here~~
}
  \item{subst}{
%%     ~~Describe \code{subst} here~~
}
  \item{quit}{
%%     ~~Describe \code{quit} here~~
}
}
\details{
%%  ~~ If necessary, more details than the description above ~~
}
\value{
%%  ~Describe the value returned
%%  If it is a LIST, use
%%  \item{comp1 }{Description of 'comp1'}
%%  \item{comp2 }{Description of 'comp2'}
%% ...
}
\references{
%% ~put references to the literature/web site here ~
}
\author{
%%  ~~who you are~~
}
\note{
%%  ~~further notes~~
}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
%% ~~objects to See Also as \code{\link{help}}, ~~~
}
\examples{
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ misc }
