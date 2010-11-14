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

    \item \code{full=FALSE}: Running tests within the current R session,
    which can change existing R variables, and create new ones.

    \item \code{full=TRUE}: Running tests by creating a new R session
    for each test file.  This is safer, but slower, and also requires an
    installed version of the package in a local directory, such as one
    created by running \code{R CMD check} at the command line.

  }
}
\usage{
runtests(pkg.dir = getOption("scriptests.pkg.dir"),
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
         path = getOption("scriptests.pkg.path", default=getwd()))

dumprout(res = .Last.value,
         output.suffix = ".Rout.tmp",
         verbose = TRUE,
         console = FALSE,
         files = !console,
         clobber = identical(output.suffix, ".Rout.tmp"),
         level=c("error", "all", "info", "warning"))
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{pkg.dir}{ The directory in which the package code and tests reside.}
  \item{path}{ The path to the package in which the tests reside.  If
        \code{path} contains \code{$PKG}, the value of \code{pkg.dir}
         will be substituted for \code{$PKG}, otherwise the value of
         \code{pkg.dir} will be appended to \code{pkg.dir} to give the
         location of the pacakge. }
  \item{pattern}{ A regular expression pattern of test files to be run.
    Only one of \code{pattern} and \code{file} should be supplied.}
  \item{file}{ The name of the file(s) containing tests to be run.}
  \item{full}{ If \code{TRUE} run in full testing environment: create directory for
    tests; copy tests to that directory; chdir to directory; run each
    test file in a newly created R session. }
  \item{dir}{ Directory where tests will be run.  The default is usually
         satisfactory.  This can be important if
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
  \item{clobber}{ Should existing output files or directories be
         clobbered?  For safety, the default is \code{FALSE}.  For
         \code{runtests()}, if the \code{dir} already exists, \code{clobber=TRUE}
    will result in replacing that directory, \code{clobber=FALSE} will
    result in stopping with an error if the directory already exists. }
  \item{output.suffix}{ File suffix for actual output transcript files (default NULL for \code{runtests},
    meaning no files written), if \code{output.suffix==TRUE}, uses suffix \code{.Rout.tmp} }
  \item{level}{ Skip files unless they have notifications at the
    specified level or above.}
  \item{...}{ Arguments to pass on to \code{runScripTests()}.  Only
         relevant when \code{full=TRUE}. (Ignored
    with a warning message otherwise.)}
  \item{verbose}{ Should progress indications be printed? }
  \item{envir}{ The environment in which to run the tests. }
  \item{enclos}{ The environment to use as the \code{enclos} argument
    for \code{eval()} when eval'ing each expression in the test file. }
  \item{subst}{ Provides control over whether the string \code{"package:::"} is
    removed from test code.  Supply \code{subst=FALSE} to prevent any
    substitution.  The default value will remove \code{"package:::"}
    when appropriate. }
  \item{res}{ A value returned from \code{runtests()}. }
}
\details{

  \code{runtests()} runs some or all of the tests (in \code{.Rt} files)
  found in the \code{tests} directory of a package.  The arguments
  \code{pkg.dir} and \code{path} are used to specify the location of the
  package (see the section \bold{Running tests} below for further
  details).  \code{runtests()} is designed to be used in conjunction
  with \code{source.pkg()}, which reads all the R code in a package into
  a special environment on the search path.  With the default argument
  \code{full=FALSE}, \code{runtests()} will run the tests in the same R
  session, though it will create a special directory which will be used
  as the working directory while running the tests.  In this mode of
  operation, output from tests is not is not written to files (unless
  \code{output.suffix} is supplied with a value), though tests may
  create or modify files themselves.

  Supplying \code{runtests(..., full=TRUE)} will run each test file in a new
  R session - the way tests are run under \code{R CMD check}.  When run
  like this, the package must be installed in the
  location \code{<pkg.dir>.Rcheck} or or \code{<pkg.name>.Rcheck},
  relative to the working directory of the current R session.  This can
  be accomplished by running the shell command
  \preformatted{R CMD check --no-codoc --no-examples --no-tests --no-vignettes --no-latex <pkg.dir>}
  in the same directory as the R session is running in.

  For working with a package in a different location relative to the
  working directory of the R session, supply the path to the package
  directory as \code{path} (can be either a relative or absolute path.)

  After either of the package or path has been specified once, it is
  remembered and will be used as the default value next time either of
  \code{runtests()} or \code{source.pkg()} is called.

  \code{dumprout()} writes actual R output to the console or to files.
  It creates one file for each test run.  Specifying \code{level=} skips
  files that have no notification at the given level or above.  With a
  missing first argument, \code{dumprout()} uses the value of the
  previously run command, which allows it to be meaningfully used
  directly after a \code{runtests()} command.
}
\value{
  \code{runtests()} returns an invisible list of \code{RtTestSetResults} objects (each element of
  the list is the result of running and checking the test in one file.)
  This result can be given to \code{dumprout()} to write actual R output
    to temporary files for test debugging and development purposes.
  \code{dumprout()} returns its first argument (whose default value is
  \code{.Last.value}), allowing it to be run several times in a row
  without having to supply any arguments
}
\section{Running tests}{

  \code{runtests()} is intended to be used in an R session while
  developing and/or maintaining code and/or tests.  It is designed to
  work together with \code{\link{source.pkg}()}, which rapidly reads the
  R code in a package..  The arguments given to \code{runtests()} will
  depend on how package directories are organized, and the working
  directory for the R session used for code and test development.

  \bold{Scenario 1: working directory of R session contains the package
  source code}

  The package source code
  \code{mynewpkg} is in
\preformatted{
  /home/tap/R/packages/mynewpkg/DESCRIPTION
  /home/tap/R/packages/mynewpkg/R
  /home/tap/R/packages/mynewpkg/tests
... etc ...
} and the working directory for the R session is
\preformatted{
  /home/tap/R/packages
}  To read package R code and run some tests, do:
\preformatted{
  > source.pkg(pkg.dir="mynewpkg")
  > res <- runtests(pkg.dir="mynewpkg", pattern="testfile1", clobber=T)
}
This will create a directory \code{/home/tap/R/packages/mynewpkg.tests},
copy all tests to it, and run the tests whose name matches
\code{testfile1} (to run all the tests, omit the argument
\code{pattern=}).

Test files (ending in \code{.Rt}) will be looked for in the directory
\code{mynewpkg/tests/}, and various output files could be created in
\code{/home/tap/R/packages} (such as those created by the tests, and
also some created by runtests).
If there are errors or warnings in matching actual and desired output, a
brief description and summary will be printed.  A transcript of the
actual output from running the tests can be printed by
\preformatted{
  > dumprout(res)
}  The default is to print transcripts only of tests that had warnings
or errors.  To write the transcripts to files, do:
\preformatted{
  > dumprout(res, file=T)
}  This will create files like \code{testfile1.Rout.tmp} in the working
directory of the R session.
These functions remember the most recent \code{pkg.dir} argument, and
  \code{dumprout()} will use a \code{.Last.value} left by
  \code{runtests()}, so it is possible to omit various arguments in the
  above commands, e.g.:
\preformatted{
  > source.pkg(pkg.dir="mynewpkg")
  > runtests(pattern="testfile1", clobber=T)
  > dumprout(file=T)
}
Note that the name of the directory where the package lives (here
\code{mynewpkg}) may be the same as or different from the name of the package.

  \bold{Scenario 2: working directory of R session is in a different
    filesystem branch to package source code}

  The package code
  \code{mynewpkg} is in
\preformatted{
  /home/tap/R/packages/mynewpkg/DESCRIPTION
  /home/tap/R/packages/mynewpkg/R
  /home/tap/R/packages/mynewpkg/tests
... etc ...
} and the working directory for the R session is
\preformatted{
  /home/tap/R/sandbox
}  To read package R code and run some tests, do:
\preformatted{
  > source.pkg(pkg.dir="mynewpkg", path="/home/tap/R/packages")
  > res <- runtests(pkg.dir="mynewpkg", pattern="testfile1", clobber=T)
} and proceed as above.  The directory
  \code{/home/tap/R/sandbox/mynewpkg.tests} will be created and used as
  the working directory for running tests.

  \bold{Scenario 3: deeper directory structure for package source code}

  In an R-forge-like directory structure, the package files and
  directories may be in
\preformatted{
  /home/tap/R/rforge/projectname/pkg/DESCRIPTION
  /home/tap/R/rforge/projectname/pkg/R/
  /home/tap/R/rforge/projectname/pkg/tests/
  ... etc ...
} and the working directory could be
\preformatted{
  /home/tap/R/rforge/projectname
}

To conveniently source R code and run tests in this directory organization, do this
\preformatted{
  > source.pkg(pkg.dir="projectname", path="/home/tap/R/rforge/$DIR/pkg")
  > res <- runtests(pkg.dir="projectname", pattern="testfile1", clobber=T)
}  Tests will be run in the directory
\preformatted{
  /home/tap/R/rforge/projectname/projectname.tests
}

}
\author{ Tony Plate \email{tplate@acm.org} }
\seealso{

  \code{\link{source.pkg}()} shares the options
  \code{scriptests.pkg.dir} and \code{scriptests.pkg.path} that provide
  defaults for the \code{pkg.dir} and \code{path} arguments.

  For running tests in under \code{R CMD check}, use the function
  \code{\link{runScripTests}()} in the file \code{tests/runtests.R} in
  the package.

  For an overview and for more details of how tests are run, inlcuding
  how to make test output matching more flexible, see \link{scriptests}.

}
\examples{
\dontrun{
> # To run like this example, set the current working directory
> # to where the package code lives.
> # source.pkg() reads in the functions -- could just as well
> # load the library, but source.pkg() can be more convenient
> # when developing a package.
> source.pkg("scriptests")
Reading 5 .R files into env at pos 2: 'pkgcode:scriptests'
Sourcing scriptests/R/createRfromRt.R
Sourcing scriptests/R/interactive.R
Sourcing scriptests/R/oldcode.R
Sourcing scriptests/R/plus.R
Sourcing scriptests/R/rttests.R
list()
> runtests("simple1")
Running tests in scriptests/tests/simple1.Rt (read 4 chunks)
....
Ran 4 tests with 0 errors and 0 warnings from scriptests/tests/simple1.Rt
> runtests("simple2")
Running tests in scriptests/tests/simple2.Rt (read 5 chunks)
.....
Ran 5 tests with 0 errors and 0 warnings from scriptests/tests/simple2.Rt
> runtests("simple")
Running tests in scriptests/tests/simple1.Rt (read 4 chunks)
....
Ran 4 tests with 0 errors and 0 warnings from scriptests/tests/simple1.Rt
Running tests in scriptests/tests/simple2.Rt (read 5 chunks)
.....
Ran 5 tests with 0 errors and 0 warnings from scriptests/tests/simple2.Rt
>
}
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ misc }
