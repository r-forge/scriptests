\name{scriptests-package}
\alias{scriptests-package}
\alias{scriptests}
\docType{package}
\title{
  Support for running transcript-style tests
}
\description{
  Support for running transcript-style tests
}
\details{

Transcript-style tests are text files containing R commands and output, as
though copied verbatim from an interactive R session.  The output in the
transcript file must match the actual output from running the command
for the test to pass (with some exceptions - see "Control over matching"
below).  This testing framework is identical in concept to the standard
\code{.R/.Rout.save} tests that are run by the \code{R CMD check}, but
with some enhancements that are intended to make test development and
maintanance faster, more convenient, and easier to automate:
\itemize{
  \item Only the output file is needed - the inputs are parsed from
  the output file (i.e., \code{.Rt} file, which is analogous to an
  \code{.Rout.save} file)
  \item Test output matching is more lenient on white space differences,
  and more flexible in that some test output can be transformed by
  regular expressions prior to matching, or ignored entirely
  \item directives can specify whether a test-case output mismatch
  should be noted as an informational message, a warning, or an error
  (one or more errors results in \code{R CMD check} stopping with an
  indication of error after running all tests).  Unlike the standard
  tests in \code{R CMD check}, output mismatch detected by
  \code{scriptests} results in \code{R CMD check} stopping with an error.
  \item A concise summary of warnings and errors is given at the end
  \item Testing can continue after errors and can report multiple errors
  at the end, rather than stopping at the first error.
}
To make it so that "R CMD check" will run transcript-style tests, do the following:
\enumerate{
  \item Make sure the \code{scriptests} package is installed on your system
  \item Put a file named "runtests.R" in the "tests" directory in your
  own package with the following contents:
  \preformatted{
library(scriptests)
runScripTests() }
  \item add transcript files ending in .Rt in the "tests" directory in
  your own package, e.g.:
  \preformatted{
> 1 + 2
[1] 3
>   }
  \item add the line \code{Suggests: scriptests} to DESCRIPTION file.
  If there is an existing "Suggests:" line, just add \code{scriptests}
  to it.  (It's better to use the \code{Suggests:} than the
  \code{Depends:} fields, because packages listed in the depends field
  are loaded when the package is loaded for normal use, and the
  \code{scriptests} package is usually not needed for normal use of a package --
  the \code{scriptests} package will only be needed for testing.
}

At the end of testing, the file \code{test-summary.txt} will be left in
the \code{tests} directory.  To be entirely sure that the tests were
run, also check for the existence of \code{test-summary.txt}.

If any tests fail, the file \code{test-summary.fail} (a copy of
\code{test-summary.txt}) will also be left in the \code{tests} directory
-- the existence of this file can be used in a programmatic check for
whether all tests passed.

Tests can be run interactively using the function
\code{\link{runtests}()}.  The function \code{\link{source.pkg}()} can
be useful to quickly re-read the function definitions in a package
during code development.  See the section "Running tests" in the
documentation for \code{\link{runtests}()} for further details.

  Notes:
  \itemize{
    \item All commands in the transcript file must be prefixed with
    command or continuation prompts, exactly as they appear in a
    transcript.
    \item scriptests uses simple heuristics to identify commands, comments and
    output.  If the transcript cannot be separated into comments,
    commands and output by these heuristics (e.g., if a command prints
    out a line starting with the command prompt "> "), things will not
    work properly.
    \item When running tests in a package, scriptests uses a heuristic to
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
  }

  \emph{Control over matching}

    Actual output is matched to desired output extracted from the
    transcript file in a line-by-line fashion.  If text is wrapped
    differently over multiple lines, the tests will fail (unless
    \code{ignore-linebreaks} is used). Different output width can easily
    happen if \code{options("width")} was different in the session that
    generated the desired output. Before trying to match, scriptests
    converts all white-space to single white-space, unless a control
    line specifies otherwise.

    The following control lines can be present in the transcript
    after a command and before its output:
    \describe{
      \item{#@ignore-output}{Ignore the output of this particular
        command -- a test with this control line will always pass
        (unless it causes an R error, and \code{options(error=function()
          NULL)} was not set.)}
      \item{#@gsub(pattern, replacement, WHAT)}{where \code{WHAT} is
        \code{target}, \code{actual} or \code{both} (without quotes).
        Make a global substitution of \code{replacement} text for
        \code{pattern} text (a regular expression) in the desired
        (target) output or the actual output.}  E.g.,
      \preformatted{
> cat("The date is <", date(), ">\n", sep="")
#@gsub("<[^>]*>", "<a date>", both)
The date is <Sat Jul 10 16:20:01 2010>
> }
      \item{#@warn-only: OPTIONAL-TEXT}{A mismatch is treated as an
        "warning", not an error}
      \item{#@info-only: OPTIONAL-TEXT}{A mismatch is treated as an
        "info" event, not an error}
      \item{#@diff-msg: OPTIONAL-TEXT}{Output OPTIONAL-TEXT if the
        desired and actual output do not match}
      \item{#@keep-whitespace}{Leave the whitespace as-is in the
        desired and actual output}
      \item{#@ignore-linebreaks}{Target and actual will match even
        if wrapped differently over multiple lines}
      }

The \code{tests} directory can also contain a \code{CONFIG} file, which can
specify the functions to call for testing.  The defaults are equivalent
to the following lines in the \code{CONFIG} file:
\preformatted{
Depends: scriptests
Debug: FALSE
Rsuffix: R
StopOnError: FALSE
Initialize: scriptests:::initializeTests()
Diff: scriptests:::ScripDiff()
Finalize: scriptests:::summarizeTests() }
The \code{CONFIG} file is optional and is not needed in ordinary usage.
}
\note{

The standard Emacs ESS functions for writing out \code{".Rt"} files will strip
trailing white space, which can result in many unimportant mismatches
when using \code{ediff} to compare \code{".Rt"} and \code{".Rout"} files (e.g.,
because an R transcript will have \code{"> "} for empty command lines).
Also, \code{".Rt"} files are read-only by default, and the return key is
bound to a command to send the current line to an R interpreter.  It is more
convenient if all these special behaviors are turned off.
Put the following in your \code{.emacs} file to tell ESS not mess with
\code{".Rt"} files prior to saving them:
\preformatted{
(add-hook 'ess-transcript-mode-hook
          ;; According to the ess docs, ess-nuke-trailing-whitespace-p
          ;; is supposed to be nil by default (see the defvar in ess-utils.el).
          ;; But it gets set to t somewhere else, so disable it here for
          ;; .Rt files, and also make RET behave the regular way.
          (lambda ()
          (if (string-match ".[Rr]t$" (buffer-name))
             (progn
                (make-variable-buffer-local 'ess-nuke-trailing-whitespace-p)
                (define-key ess-transcript-mode-map (kbd "RET") 'newline)
                (toggle-read-only 0)
                (setq ess-nuke-trailing-whitespace-p nil)))) t)
}
}
\author{
  Tony Plate <tplate@acm.org>
}
\keyword{ package }
