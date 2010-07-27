\name{scriptests.design}
\alias{scriptests.design}
\docType{package}
\title{Design considerations for package scriptests}
\description{
  Design considerations for package scriptests.  This file is a poorly
  organized collection of notes regarding the design and evolution of
  the scriptests package.
}
\details{

  "R CMD check" is (as of R-2.9.0) an R script
  \code{src/scripts/check.in}, which invokes R with the command
  \code{tools:::.runPackageTestsR($extra)} to run tests.  If this R
  session returns non-zero, the check process stops with an error,
  outputting 13 lines from the first .fail file found (if one exists).

  \code{tools:::.runPackageTestsR($extra)} invokes \code{R CMD BATCH} to
  run each .R file.  This is where the non-overrideable redirection of
  stderr to .Rout happens.

  New design for scriptests to work with R-2.9.0 in which "R CMD check"
  no longer uses Makefiles in tests directory.

  \itemize{
    \item All transcript files are stored in the \code{tests} directory
    with the file extension \code{.Rt}.

    \item There should be a file called \code{runtests.Rin}, which
    should contain the following two lines:
    \preformatted{
      library(scriptests)
      runScripTests()
    }

    \item When \code{runScripTests()} runs, it will create a \code{.R}
    file with the commands extracted from each \code{.Rt} file.  It will
    then run each \code{.R} file in a separate \code{R} session, save
    the output in a \code{.Rout} file, and compare the output with the
    \code{.Rt} file.  \code{runScripTests} will leave a summary in the
    file \code{test-summary.txt}.  If there are errors, the summary will
    be duplicated in the file \code{test-summary.fail} (the presence of
    a file ending in \code{.fail} signals an error to \code{"R CMD
    check"}.)

    }
  }
\section{Comparisons to previous scriptests designs}{

  The functionality that this design gives up over previous designs is
  immediate checking of test output.  Instead test output is checked
  after all tests are run.  This is because of the difficulty of
  controlling the execution order of different test files -- it's hard
  to create pairs of test/check files that will run in the correct order
  (order of execution depends on the order of files in the value of
  \code{dir}).

  The functionality that this design retains from previous designs (and
  from the native testing framework in R) is that each file of R
  commands to be checked in run in a new R session.  This means that
  commands in one test file cannot mess up another test file.  It also
  means that the testing framework doesn't need to mess around with
  trying to capture output.

  There are several possible methods that could be used to check output
  immediately after running each test:
  \enumerate{
    \item prepend each \code{.R} file with a function that checks output
    of all previously run tests (skipping ones already done).
    \item append to each \code{.R} file a call to a function that
    flushes stdout (\code{flush(stdout())}) and checks tests output.
    \item define a \code{.Last()} function (will be called by
    \code{q()}) that checks test output.
  }

  Hangup with the above approach: it's not possible to have output from
  the runs go to stdout -- because all the output from running a .R file
  is redirected to the corresponding .Rout file.

  Alternate approach: a setup file calls my own version of
  .runPackageTests(), which then executes an R session for each .R
  file.  Still have the problem of not getting any output to the
  console.  Can solve this by by-passing R CMD BATCH, and just invoking
  R more directly.
}

\section{Original scriptests design based on Makefiles}{

An initial design changed the default goal by assigning .DEFAULT\_GOAL in
tests/Makefile.  This works with GNU make version 3.81, which is
standard in Ubuntu Linux.  However, the Rtools set of programs for
Windows includes GNU make version 3.79, which does not appear to
recognize the .DEFAULT\_GOAL special variable.  Additionally, version
2.6.2 (2008-02-08) of "R Installation and Administration" specifically
says that GNU make version 3.81 does not work to compile under Windows.
Furthermore, Mac OS X version 10.4 (Tiger) includes GNU make version
3.80, which also does not appear to recognize the .DEFAULT\_GOAL special
variable.

Consequently, a different approach to getting R CMD check to run
additional tests is needed.

The approach implemented as of version 0.1-6 (March 2009) is to use a
"\%" target in the makefile (which is always called), with an action in
the body of the rule that invokes a 'make' recursively with the desired
target (here \code{all-Rt}).

\url{http://www.gnu.org/software/automake/manual/make/Force-Targets.html}
describes 'force targets'.

Here's the relevant section from scriptests/inst/scripts/Makefile.sub:

\preformatted{
# Use 'force' to effectively create another target, by calling
# make recursively with the target 'all-Rt'.
# Based on code at
# http://www.gnu.org/software/automake/manual/make/Overriding-Makefiles.html
# but with more levels of protection to avoid calling make with
# the target 'all-Rt' more than once, because this makefile is
# read many times.  Condition on DONEFORCE being not defined
# to avoid infinite recursion.
ifeq ($(strip $(DONEFORCE)),)
%: force
        @(if [ ! -f forceonce ] ; then \
        $(MAKE) -f $(R_SHARE_DIR)/make/$(RSHAREMAKEFILE) $(makevars) -f $(MAINTESTMAKE) DONEFORCE=TRUE all-Rt ; \
        fi )
        @touch forceonce

force: ;
endif
}

The various 'make' variables used here are defined in ...

}
\section{Not used: A Makefile framework that modifies Makevars to create a goal,
  and also uses a dummy .R file}{
This makefile does two things to try to create a goal: (1) it edits
Makevars to insert an extra goal; and (2) it uses a specific rule for a
allrt.Rin to allrt.R to run a sub-make (the rule is written to
Makevars).

Both of these approaches should work, but the whole thing does not seem
to work reliably.  In any case, the sub-make can be called directly from
the "force" block instead of using the force block to create a rule that
calls the sub-make.  This code is preserved here because it uses a
number of techniques that might come in handy somewhere else.

This framework uses three files in the tests directory:
\code{Makefile}, \code{Makefile.win} and  \code{allrt.Rin}.

\bold{Makefile}:
\preformatted{
# Redefine the default goal (a GNU make feature) so that we
# have the Rt tests as subgoals.
# Note that the default goal can contain only one target.
# .DEFAULT_GOAL := all+Rt

ifeq ($(strip $(RSHAREMAKEFILE)),)
  RSHAREMAKEFILE=tests.mk
endif

# Need MAINTESTMAKE so that when we edit Makevars we can set $makevars
# to include the same makefile as R CMD check uses (which, under Windows,
# is Makefile.win if it exists)
ifeq ($(strip $(MAINTESTMAKE)),)
  MAINTESTMAKE=Makefile
endif

# Define ScripTestsErrorAction to be 'continue' or 'stop'.
# This controls what happens running under R CMD check
# when there are errors in one of the Rt tests.
ScripTestsErrorAction=stop

# Under Unix-likes we want to run R like this:
#    @R_LIBS=$(R_LIBS) $(R) ... arguments ...
# while under Windows we want to run R like this:
#    $(R) @R_LIBS=$(R_LIBS) ... arguments ...
# So, always run R like this: $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST)
# with appropriate definitions for R_PRE and R_POST.
# If we are running under Windows, we will have already executed
# Makefile.win, which will have defined R_PRE=$(R) .
ifeq ($(strip $(R_PRE)),)
  # Unix-like
  R_PRE=
  R_POST=$(R)
endif

# If we do want to change the RDIFF command, should include
# 'changeRdiff' as the second dependency for all+Rt
all+Rt: createScripts all rt-tests ScripTests.summary
all-Rt: createScripts rt-tests ScripTests.summary
        @echo doing all-Rt

allrt := $(wildcard *.Rt)
# allrtwant := $(allrt:.Rt=.Rout.want)
# allrtout := $(allrt:.Rt=.Rout)
allrtres := $(allrt:.Rt=.Rtres)
# allrtin := $(allrt:.Rt=.R)

%: force
        @(if [ ! -f forceonce ] ; then \
        echo Modifying Makevars for rttests ; \
        sed -i 's/test-src-1 =/test-src-1 = all-Rt/' Makevars ; \
        sed -i "s/makevars =/makevars = -f $(MAINTESTMAKE)/" Makevars ; \
        fi )
        @(if [ ! -f forceonce ] ; then echo 'allrt.R: %.R: %.Rin' ; \
        echo '  @echo Using special rule $$@ to run all tests ... ' ; \
        echo '  $$(MAKE) -f $$(R_SHARE_DIR)/make/tests.mk $$(makevars) all-Rt' ; \
        echo '  @echo 1+1 > $$@' ; fi ) >> Makevars
        @touch forceonce

force: ;

# Don't need this unless we want standard .R/.Rout.save tests
# to use the modified RDIFF (not the ones run here - they use
# the commands in the .Rout.Rtres rule)

changeRdiff:
        @echo Changing Rdiff in Makevars
        echo RDIFF = echo hehehe >> Makevars

# Create scripts we will need (do this here to minimize the
# number of files needed to support scriptests in a package.)
createScripts:
        @( echo '## Run a script in the scriptests/scripts (from scriptests/inst/scripts)' ; \
        echo '## This file does not have .R suffix because if it did, R CMD check would want to run it as a test' ; \
        echo 'library(package="scriptests", char=TRUE)' ; \
        echo 'args <- commandArgs(TRUE)' ; \
        echo 'debug <- is.element("--debug", args)' ; \
        echo 'if (length(args)>0) {' ; \
        echo '    script.path <- system.file(package="scriptests", "scripts")' ; \
        echo '    if (debug) {' ; \
        echo '        cat("RtTestScript called with ", length(args), " args: ", paste("\"", args, "\"", collapse=", ", sep=""), "\n", sep="")' ; \
        echo '        cat("Looking for scripts in \"", script.path, "\"\n", sep="")' ; \
        echo '    }' ; \
        echo '    source(file.path(script.path, args[1]))' ; \
        echo '}' ) > RunScripTestsScript

# Don't need the following because we can run and check the tests
# with out needing a sub-make.  If we do use a sub-make, then we
# need to put rules used in 'Makevars'.
#       echo .SUFFIXES: .R .Rin .Rout .Rt >> Makevars
#       echo .Rt.R: >> Makevars
#       echo '  echo Creating $$@ from $$<' >> Makevars
#       echo '  sed -n "s/^[>+] //p" $$< > $$@' >> Makevars
#       echo '  cat $$< > $$@out.save' >> Makevars

#  This suffix list and rule for .Rt.R needs to go in Makevars

.SUFFIXES: .R .Rin .Rout .Rt .Rtres

# Files:
#   .Rt: a transcript, with both commands and desired output, & possibly directives
#   .R: R commands generated from .Rt
#   .Rout.want: desired transcript output generated from .Rt (maybe don't need this)
#   .Rt.save: the processed Rt script as an R object
#   .Rout: the output from R when given the commands in .R
#   .Rtres: summary of results from comparing .Rout and .Rout.want

.Rt.R:
        @echo '**' Creating $@ and $@out.want from $<
        $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST) $(R_OPTS) --vanilla --slave --args prepin.R $< $@ $@out.want $<.save < RunScripTestsScript

# Preserve intermediate .R and .Rout files - the user might want to inspect them
# (the .R file to see exactly what the R commands were, and the .Rout file to
#  see what output was actually produced)
.PRECIOUS: %.R %.Rout

# Diff the output
# Need to have R_LIBS & R round the other way for Windows
.Rout.Rtres:
        @echo '**' Creating $@ from $< and $<.want
        $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST) $(R_OPTS) --vanilla --slave --args diffout.R $< $(@:Rtres=Rt.save) $@ < RunScripTestsScript

rt-tests: $(allrtres)

# Method for using a 'make' sub process to run tests (will use a chained rule
# for X.Rout: X.Rt -> X.R -> X.Rout if we put the rule .Rt.R in Makevars
# (needs to go there because this Makefile is not read by the sub-make).
rt-tests2:
        echo Making target rt-tests
        (out=`echo *.Rt | sed 's/\\.Rt\\( \\|$\\)/.Rout /g'`; \
          if test -n "$${out}"; then \
            $(MAKE) -f $(R_SHARE_DIR)/make/$(RSHAREMAKEFILE) $(makevars) $${out}; \
          fi)

ScripTests.summary: $(allrtres)
        @echo '**' Creating summary of tests in $@
        $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST) $(R_OPTS) --vanilla --slave --args summary.R $@ $(allrtres) < RunScripTestsScript
        @(if [ "$(ScripTestsErrorAction)" = stop -a -f ScripTests.haserrors ] ; then \
            echo "Stopping because tests had errors and ScripTestsErrorAction=stop in Makefile" ; \
            exit 1 ; \
        fi)
}
\bold{Makefile.win}:
\preformatted{
RSHAREMAKEFILE=wintests.mk
# R_SHARE_DIR is defined when running under Linux, but not Windows...
R_SHARE_DIR=$(R_HOME)/share
MAINTESTMAKE=Makefile.win
# Under Windows we want to run R like this: $(R) R_LIBS=$(R_LIBS)
# Seems that don't need this anymore, at least as of R 2.6.1
# R_PRE=$(R)
# R_POST=
include Makefile
}
\bold{allrt.Rin}:
\preformatted{
cat("1\n", file="allrt.R")
}
}

\section{A Makefile framework using .DEFAULT\_GOAL}{
This framework requires two files in the tests directory:
\code{Makefile} and \code{Makefile.win}.  Note that some of the code in
here is unnecessary (e.g., the R\_PRE and R\_POST stuff -- this was used
to put VAR=VALUE before or after the name of the R program on a command
line depending on whether Windows or Unix was being used.

\bold{Makefile}:
\preformatted{
# Redefine the default goal (a GNU make feature) so that we
# have the Rt tests as subgoals.
# Note that the default goal can contain only one target.
.DEFAULT_GOAL := all+Rt

ifeq ($(strip $(RSHAREMAKEFILE)),)
  RSHAREMAKEFILE=tests.mk
endif

# Define ScripTestsErrorAction to be 'continue' or 'stop'.
# This controls what happens running under R CMD check
# when there are errors in one of the Rt tests.
ScripTestsErrorAction=stop

# Under Unix-likes we want to run R like this:
#    @R_LIBS=$(R_LIBS) $(R) ... arguments ...
# while under Windows we want to run R like this:
#    $(R) @R_LIBS=$(R_LIBS) ... arguments ...
# So, always run R like this: $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST)
# with appropriate definitions for R_PRE and R_POST.
# If we are running under Windows, we will have already executed
# Makefile.win, which will have defined R_PRE=$(R) .
ifeq ($(strip $(R_PRE)),)
  # Unix-like
  R_PRE=
  R_POST=$(R)
endif

# If we do want to change the RDIFF command, should include
# 'changeRdiff' as the second dependency for all+Rt
all+Rt: createScripts all rt-tests ScripTests.summary

allrt := $(wildcard *.Rt)
allrtwant := $(allrt:.Rt=.Rout.want)
allrtout := $(allrt:.Rt=.Rout)
allrtres := $(allrt:.Rt=.Rtres)
# allrtin := $(allrt:.Rt=.R)

# Don't need this unless we want standard .R/.Rout.save tests
# to use the modified RDIFF (not the ones run here - they use
# the commands in the .Rout.Rtres rule)

changeRdiff:
        @echo Changing Rdiff in Makevars
        echo RDIFF = echo hehehe >> Makevars

# Create scripts we will need (do this here to minimize the
# number of files needed to support scriptests in a package.)
createScripts:
        @( echo '## Run a script in the scriptests/scripts (from scriptests/inst/scripts)' ; \
        echo '## This file does not have .R suffix because if it did, R CMD check would want to run it as a test' ; \
        echo 'library(package="scriptests", char=TRUE)' ; \
        echo 'args <- commandArgs(TRUE)' ; \
        echo 'debug <- is.element("--debug", args)' ; \
        echo 'if (length(args)>0) {' ; \
        echo '    script.path <- system.file(package="scriptests", "scripts")' ; \
        echo '    if (debug) {' ; \
        echo '        cat("RtTestScript called with ", length(args), " args: ", paste("\"", args, "\"", collapse=", ", sep=""), "\n", sep="")' ; \
        echo '        cat("Looking for scripts in \"", script.path, "\"\n", sep="")' ; \
        echo '    }' ; \
        echo '    source(file.path(script.path, args[1]))' ; \
        echo '}' ) > RunScripTestsScript


# Don't need the following because we can run and check the tests
# with out needing a sub-make.  If we do use a sub-make, then we
# need to put rules used in 'Makevars'.
#       echo .SUFFIXES: .R .Rin .Rout .Rt >> Makevars
#       echo .Rt.R: >> Makevars
#       echo '  echo Creating $$@ from $$<' >> Makevars
#       echo '  sed -n "s/^[>+] //p" $$< > $$@' >> Makevars
#       echo '  cat $$< > $$@out.save' >> Makevars

#  This suffix list and rule for .Rt.R needs to go in Makevars

.SUFFIXES: .R .Rin .Rout .Rt .Rtres

# Files:
#   .Rt: a transcript, with both commands and desired output, & possibly directives
#   .R: R commands generated from .Rt
#   .Rout.want: desired transcript output generated from .Rt (maybe don't need this)
#   .Rt.save: the processed Rt script as an R object
#   .Rout: the output from R when given the commands in .R
#   .Rtres: summary of results from comparing .Rout and .Rout.want

.Rt.R:
        @echo '**' Creating $@ and $@out.want from $<
        $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST) $(R_OPTS) --vanilla --slave --args prepin.R $< $@ $@out.want $<.save < RunScripTestsScript

# Preserve intermediate .R and .Rout files - the user might want to inspect them
# (the .R file to see exactly what the R commands were, and the .Rout file to
#  see what output was actually produced)
.PRECIOUS: %.R %.Rout

# Diff the output
# Need to have R_LIBS & R round the other way for Windows
.Rout.Rtres:
        @echo '**' Creating $@ from $< and $<.want
        $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST) $(R_OPTS) --vanilla --slave --args diffout.R $< $(@:Rtres=Rt.save) $@ < RunScripTestsScript

rt-tests: $(allrtres)

# Method for using a 'make' sub process to run tests (will use a chained rule
# for X.Rout: X.Rt -> X.R -> X.Rout if we put the rule .Rt.R in Makevars
# (needs to go there because this Makefile is not read by the sub-make).
rt-tests2:
        echo Making target rt-tests
        (out=`echo *.Rt | sed 's/\\.Rt\\( \\|$\\)/.Rout /g'`; \
          if test -n "$${out}"; then \
            $(MAKE) -f $(R_SHARE_DIR)/make/$(RSHAREMAKEFILE) $(makevars) $${out}; \
          fi)

ScripTests.summary: $(allrtres)
        @echo '**' Creating summary of tests in $@
        $(R_PRE) @R_LIBS=$(R_LIBS) $(R_POST) $(R_OPTS) --vanilla --slave --args summary.R $@ $(allrtres) < RunScripTestsScript
        @(if [ "$(ScripTestsErrorAction)" = stop -a -f ScripTests.haserrors ] ; then \
            echo "Stopping because tests had errors and ScripTests ErrorAction=stop in Makefile" ; \
            exit 1 ; \
        fi)
}
\bold{Makefile.win}:
\preformatted{
RSHAREMAKEFILE=wintests.mk
# Under Windows we want to run R like this: $(R) @R_LIBS=$(R_LIBS)
R_PRE=$(R)
R_POST=
include Makefile
}
}

\keyword{misc}
