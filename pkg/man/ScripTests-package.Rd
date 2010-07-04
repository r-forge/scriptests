\name{ScripTests-package}
\alias{ScripTests-package}
\alias{ScripTests}
\docType{package}
\title{
  Support for running transcript-style tests
}
\description{
  Support for running transcript-style tests
}
\details{
\tabular{ll}{
Package: \tab ScripTests\cr
Type: \tab Package\cr
Version: \tab 1.0\cr
Date: \tab 2007-04-10\cr
License: \tab GPL\cr
}

Transcript-style tests are files containing R commands and output, as
though copied verbatim from an interactive R session.  These are very
much like the standard \code{.R/.Rout.save} tests that are run by the
\code{R CMD check}, but with the following diferences that are intended
to make test development and maintanance faster and more convenient:
\itemize{
  \item only the output file is needed -- the inputs are deduced from
  the output file (i.e., \code{.Rt} file, which is analogous to an
  \code{.Rout.save} file)
  \item test output matching is more lenient in terms of white-space,
  and more flexible in that some test output can be transformed by
  regular expressions prior to matching, or ignored entirely
  \item directives can specify whether a test-case output mismatch
  should be noted as an informational message, a warning, or an error
  (one or more errors results in \code{R CMD check} stopping with an
  indication of error).  Unlike the standard tests in \code{R CMD check},
  output mismatch detected by \code{ScripTests} results in \code{R CMD
    check} stopping with an error.
  \item a concise summary of warnings and errors is given at the end
  \item testing can continue after errors and report multiple errors
}


To include transcript-style tests in a package so that they will be
automatically run by "R CMD check", do the following:

\enumerate{
  \item make sure the \code{ScripTests} package is installed on your system
  \item put a file named "runtests.R" in the "tests" directory in your
  own package with the following contents:
  \code{
          library(ScripTests)
          runScripTests()
    }
  \item add transcript files ending in .Rt in the "tests" directory in your own package
}

Tests can be run interactively using the function
\code{\link{runtests}()}.  The function \code{\link{source.pkg}()} can
be useful to quickly re-read the function definitions in a package
during code development.

  Notes:
  \itemize{
    \item All commands in the transcript file must be prefixed with
    command or continuation prompts, exactly as they appear in a
    transcript.
    \item ScripTests uses simple heuristics to identify commands, comments and
    output.  If the transcript cannot be separated into comments,
    commands and output by these heuristics (e.g., if a command prints
    out a line starting with the command prompt "> "), the tests will
    probably fail.
    \item When running tests in a package, ScripTests uses a heuristic to
    guess the package name and automatically include an appropriate
    \code{library(package-being-tested)} command before the tests.  If
    this heuristic fails, the functions from the package being tested
    may not be accessible.  If this problem occurs, it can be worked
    around by explicitly including a
    \code{library(package-being-tested)} command at the beginning of
    each \code{.Rt} file.
    \item To have tests continue to run after encountering an error, put
    the command \code{options(error=function() NULL)} at the beginning
    of the transcript file.  This will cause the non-interactive R
    session that runs the commands in the scripts to continue after an
    error, instead of stopping, which is the default behavior for
    non-interactive R.
    \item Actual output is matched to desired output extracted from the
    transcript file in a line-by-line fashion.  If text is wrapped
    differently over multiple lines, the tests will fail (unless
    \code{ignore-linebreaks} is used). This can happen if
    \code{options("width")} was different in the session that
    generated the desired output. All white-space is converted to
    single white-space, unless a control line specifies otherwise.
    \item The following control lines can be present in the transcript
    after a command and before its output:
    \describe{
      \item{\#@ ignore-output}{Ignore the output of this particular
        command -- a test with this control line will always pass
        (unless it causes an R error, and \code{options(error=function()
          NULL)} was not done.)}
      \item{\#@ gsub(pattern, replacement, WHAT)}{where \code{WHAT} is
        \code{target}, \code{actual} or \code{both} (without quotes).
        Make a global substitution of \code{replacement} text for
        \code{pattern} text (a regular expression) in the desired
        (target) output or the actual output.}
      \item{\#@ warn-only: OPTIONAL-TEXT}{A mismatch is treated as an
        "warning", not an error}
      \item{\#@ info-only: OPTIONAL-TEXT}{A mismatch is treated as an
        "info" event, not an error}
      \item{\#@ diff-msg: OPTIONAL-TEXT}{Output OPTIONAL-TEXT if the
        desired and actual output do not match}
      \item{\#@ keep-whitespace}{Leave the whitespace as-is in the
        desired and actual output}
      \item{\#@ ignore-linebreaks}{Target and actual will compare even
        if wrapped differently over multiple lines}
      }
    }

The \code{tests} directory can also contain a CONFIG file, which can
specify the functions to call for testing.  The defaults are equivalent
to the following lines in the CONFIG file:
\preformatted{
Depends: ScripTests
Debug: FALSE
Initialize: ScripTests:::initializeTests()
Diff: ScripTests:::ScripDiff()
Finalize: ScripTests:::summarizeTests()
}
}
\note{
The standard Emacs ESS functions for writing out \code{".Rt"} files will strip
trailing white space, which can result in many unimportant mismatches
when using \code{ediff} to compare \code{".Rt"} and \code{".Rout"} files (e.g.,
because an R transcript will have \code{"> "} for empty command lines).
Put the following in your \code{.emacs} file to tell ESS not mess with
\code{".Rt"} files prior to saving them:

\kbd{
(add-hook 'ess-transcript-mode-hook
          ;; According to the ess docs, ess-nuke-trailing-whitespace-p
          ;; is supposed to be nil by default (see the defvar in ess-utils.el).
          ;; But it gets set to t somewhere else, so disable it here.
          (lambda ()
            (make-variable-buffer-local 'ess-nuke-trailing-whitespace-p)
            (toggle-read-only 0)
            (setq ess-nuke-trailing-whitespace-p nil)))
}
\author{
  Tony Plate

Maintainer: Tony Plate <tplate@acm.org>
}
\keyword{ package }
