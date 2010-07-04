\name{runtests}
\alias{runtests}
\alias{dumprout}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{ Interactively run some Rt test files in a package }
\description{
  Interactively run some Rt test files in a package
}
\usage{
runtests(pkg.dir = get("ScripTests.pkg.dir", envir = globalenv()),
         pattern = ".*",
         file = NULL,
         full = FALSE,
         dir = paste(pkg.dir, ".tests", sep=""),
         clobber = FALSE,
         output.suffix = NULL,
          ...,
         progress = TRUE,
         envir = globalenv(),
         enclos = envir,
         subst = NULL,
         path = mget("ScripTests.pkg.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]])
dumprout(res = .Last.value,
         output.suffix = ".Rout.tmp",
         verbose = TRUE,
         clobber = identical(output.suffix, ".Rout.tmp"))
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{pkg.dir}{ The directory in which the package code and tests reside.}
  \item{pattern}{ A regular expression pattern of test files to be run.
    Only one of \code{pattern} and \code{file} should be supplied.
    }
  \item{file}{ The name of the file(s) containing tests to be run.
    }
  \item{full}{ Run in full testing environment: create directory for
    tests; chdir to directory; run each test file in a child process. }
  \item{dir}{ Directory for full testing environment }
  \item{clobber}{ If the \code{dir} already exists, \code{clobber=TRUE}
    will result in replacing that directory, \code{clobber=FALSE} will
    result in stopping with an error if the directory already exists. }
  \item{output.suffix}{ File suffix for actual output files (default NULL for \code{runtests},
    meaning no output, if \code{output.suffix==TRUE}, uses suffix \code{.tmp} }
  \item{...}{ Arguments to pass on to \code{runScripTests()} }
  \item{progress}{ Should progress indications be printed? }
  \item{envir}{ The environment in which to run the tests }
  \item{enclos}{ The environment to use as the \code{enclos} argument
    for \code{eval()} when eval'ing each expression in the test file }
  \item{subst}{ Provides control over whether the string "pacakge:::" is
    removed from test code.  The default value should work. }
  \item{path}{ The path to the package in which the tests reside }
  \item{res}{ A value returned from \code{runtests()} }
  \item{verbose}{ Should messages about files being created be written
    to the console? }
}
\details{

  \code{runtests()} is intended to be most easily used in the directory that
  contains the package (e.g., if the package MyPackage is in
  \code{/home/sam/R/packages/MyPackage}, then the working directory is
  intended to be \code{/home/sam/R/packages}).  Test files (ending in
  \code{.Rt}) are looked for in
  the directory \code{MyPackage/tests/}.

  For working with a package in a different location, supply the path to
  the package directory as \code{path}.

  After either of the package or path has been specified once, it is
  remembered and will be used as the default value next time
  \code{runtests()} is called.

  \code{dumprout()} writes actual R output to temporary files.  It
  creates one file for each test run.
}
\value{
  \code{runtests()} returns an invisible list of \code{RtTestSetResults} objects (each element of
  the list is the result of running and checking the test in one file.)
  This result can be given to \code{dumprout() to write actual R output
    to temporary files for test debugging and development purposes.}.
}
\author{ Tony Plate \email{tplate@acm.org} }
}
\seealso{
  \code{\link{source.pkg}} shares the global variables
\code{ScripTests.pkg.dir} and \code{ScripTests.pkg.path} that provide
defaults for the \code{pkg.dir} and \code{path} arguments.

  For running tests in under \code{R CMD check}, use the function \code{link{runScripTests()}}.

}
\examples{
\dontrun{
> # To run like this example, set the current working directory
> # to where the package code lives.
> # source.pkg() reads in the functions -- could just as well
> # load the library, but source.pkg() can be more convenient
> # when developing a package.
> source.pkg("ScripTests")
Reading 5 .R files into env at pos 2: 'pkgcode:ScripTests'
Sourcing ScripTests/R/createRfromRt.R
Sourcing ScripTests/R/interactive.R
Sourcing ScripTests/R/oldcode.R
Sourcing ScripTests/R/plus.R
Sourcing ScripTests/R/rttests.R
list()
> runtests("simple1")
Running tests in ScripTests/tests/simple1.Rt (read 4 chunks)
....
Ran 4 tests with 0 errors and 0 warnings from ScripTests/tests/simple1.Rt
> runtests("simple2")
Running tests in ScripTests/tests/simple2.Rt (read 5 chunks)
.....
Ran 5 tests with 0 errors and 0 warnings from ScripTests/tests/simple2.Rt
> runtests("simple")
Running tests in ScripTests/tests/simple1.Rt (read 4 chunks)
....
Ran 4 tests with 0 errors and 0 warnings from ScripTests/tests/simple1.Rt
Running tests in ScripTests/tests/simple2.Rt (read 5 chunks)
.....
Ran 5 tests with 0 errors and 0 warnings from ScripTests/tests/simple2.Rt
>
}
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ misc }
