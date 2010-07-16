\name{runtests}
\alias{runtests}
\alias{dumprout}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{ Interactively run some Rt test files in a package }
\description{
  Run some Rt test files in a package from within an interactive R
  session.
  There are two major modes in which \code{runtests()} can be used:
  \itemize{
    \item \code{full=FALSE}: Running tests within the current R session, which can change
    existing R variables, and create new ones
    \item \code{full=TRUE}: Running tests by creating a new R session for each test file.  This is safer, but slower.
  }
}
\usage{
runtests(pkg.dir = get("ScripTests.pkg.dir", envir = globalenv()),
         pattern = ".*",
         file = NULL,
         full = FALSE,
         dir = TRUE,
         clobber = FALSE,
         output.suffix = NULL,
         console = FALSE,
         ...,
         verbose = TRUE,
         envir = globalenv(),
         enclos = envir,
         subst = NULL,
         path = mget("ScripTests.pkg.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]])
dumprout(res = .Last.value,
         output.suffix = ".Rout.tmp",
         verbose = TRUE,
         console = TRUE,
         files = !console,
         clobber = identical(output.suffix, ".Rout.tmp"),
         level=c("all", "info", "warning", "error"))
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{pkg.dir}{ The directory in which the package code and tests reside.}
  \item{pattern}{ A regular expression pattern of test files to be run.
    Only one of \code{pattern} and \code{file} should be supplied.}
  \item{file}{ The name of the file(s) containing tests to be run.}
  \item{full}{ Run in full testing environment: create directory for
    tests; copy tests to that directory; chdir to directory; run each
    test file in a newly created R session. }
  \item{dir}{ Directory where tests will be run.  This is important if
    the files access and/or create any files or directories.  The
    default value depends on \code{full}: if \code{full=FALSE} the
    default value is \code{paste(pkg.dir, ".tests", sep=""}; if \code{full=TRUE} the
    default value is \code{paste(pkg.dir, ".Rcheck/tests", sep=""}.
    Supply \code{dir=FALSE} to run tests in the current directory.}
  \item{console}{ If \code{TRUE}, output from the test will be written
    as output from this function.  The default is \code{FALSE} for
    \code{runtests()} and \code{TRUE} for \code{dumprout()}.}
  \item{files}{ Opposite of \code{console} (specify just
    \code{console=TRUE} or \code{file=TRUE})}
  \item{clobber}{ If the \code{dir} already exists, \code{clobber=TRUE}
    will result in replacing that directory, \code{clobber=FALSE} will
    result in stopping with an error if the directory already exists. }
  \item{output.suffix}{ File suffix for actual output files (default NULL for \code{runtests},
    meaning no output, if \code{output.suffix==TRUE}, uses suffix \code{.tmp} }
  \item{level}{ Skip files unless they have notifications at the
    specified level or above.}
  \item{...}{ Arguments to pass on to \code{runScripTests()}.  Ignored
    with a warning message unless \code{full=TRUE}. }
  \item{verbose}{ Should progress indications be printed? }
  \item{envir}{ The environment in which to run the tests }
  \item{enclos}{ The environment to use as the \code{enclos} argument
    for \code{eval()} when eval'ing each expression in the test file }
  \item{subst}{ Provides control over whether the string \code{"package:::"} is
    removed from test code.  Supply \code{subst=FALSE} to prevent any
    substitution.  The default value will remove \code{"package:::"}
    when appropriate. }
  \item{path}{ The path to the package in which the tests reside }
  \item{res}{ A value returned from \code{runtests()} }
}
\details{

  \code{runtests()} is intended to be easily used in the directory that
  contains the package (e.g., if the package \code{<MyPackage>} is in
  \code{/home/sam/R/packages/<MyPackage>} (so that package files and
  directories are in
  \code{/home/sam/R/packages/<MyPackage>/\{DESCRIPTION,R,man,tests\}},
  then the working directory is intended to be
  \code{/home/sam/R/packages}).  Test files (ending in \code{.Rt}) are
  looked for in the directory \code{<MyPackage>/tests/}.  Alternatively,
  in an R-forge-like directory structure, the package files and
  directories are in
  \code{/home/sam/R/packages/<pkg-unix-name>/pkg/\{DESCRIPTION,R,man,tests\}},
  and the working directory should be
  \code{/home/sam/R/packages/<pkg-unix-name>}.

  Supplying \code{full=TRUE} will run each test file in a newly created
  R sessions.  When run like this, package should be installed in the
  directory \code{<pkg.dir>.Rcheck} or \code{<pkg.name>.Rcheck} (run
  \code{R CMD check <MyPackage>} or \code{R CMD check pkg} in a shell in
  the same directory to install a copy of the package in this location).

  For working with a package in a different location relative to the
  working directory of the R session, supply the path to the package
  directory as \code{path} (can be either a relative or absolute path.)

  After either of the package or path has been specified once, it is
  remembered and will be used as the default value next time
  \code{runtests()} is called.

  \code{dumprout()} writes actual R output to temporary files.  It
  creates one file for each test run.  With no arguments, it uses the
  value of the previously run command, which allows it to be
  meaningfully used directly after a \code{runtests()} command.

  When running with \code{full=TRUE} (i.e., with each test run in a
  separate R session), the package is assumed to be installed in the
  location \code{<pkg.dir>.Rcheck}, relative to the working directory of
  the current R session.  This can be accomplished by running the shell
  command
  \preformatted{R CMD check --no-codoc --no-examples --no-tests
    --no-vignettes --no-latex <pkg.dir>}
  in the current working directory of the R session.
}
\value{
  \code{runtests()} returns an invisible list of \code{RtTestSetResults} objects (each element of
  the list is the result of running and checking the test in one file.)
  This result can be given to \code{dumprout()} to write actual R output
    to temporary files for test debugging and development purposes.
}
\author{ Tony Plate \email{tplate@acm.org} }
\seealso{
  \code{\link{source.pkg}()} shares the global variables
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
