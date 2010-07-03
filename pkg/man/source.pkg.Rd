\name{source.pkg}
\alias{source.pkg}
%- Also NEED an '\alias' for EACH other topic documented here.
\title{ Quickly load code and data of a package }
\description{

  \code{source()} all of the source files and data files in a package into a specially created
  environment.  It also loads DLLs if requested, and if those DLLs can
  be found.   This function is intended for use in code development,
  in situations where code from a package can be tested without worrying
  about imports, namespaces, etc.

}
\usage{
source.pkg(pkg.dir = mget("working.package.dir", envir = globalenv())[[1]],
           pattern = ".*",
           suffix = "\\\\.R$",
           dlls = c("no", "check"),
           pos = 2,
           path=mget("working.package.path", envir=globalenv(), ifnotfound=list(getwd()))[[1]])
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{pkg.dir}{ The directory where the package code lives.  This is remembered and the same
    value used as the default in subsequent invocations. This can be
    different from the package name, which is read from \code{<pkg.dir>/DESCRIPTION}.}
  \item{pattern}{ A regular expression specifying the R files to source }
  \item{suffix}{ The suffix for the R code files.  Files are sourced
    only if they match both \code{pattern} and \code{suffix}. }

  \item{dlls}{ Indicates where to look for DLLs or
    shared-objects:
    \itemize{
      \item \code{no}: don't load any DLLs
      \item \code{check}: look in \code{<pkg.dir>.Rcheck/<pkg.name>/libs}
      }
  }

  \item{pos}{ Which environment on the search path to source R code into }

  \item{path}{ The file system path to the directory in which the
    package is located.  By default, R source files are looked for as
    \code{<path>/<pkg.name>/R/*.R}. This is remembered and the same
    value used as the default in subsequent invocations.}

}
\details{

  All the objects created by the \code{.R} files are created in a
  special environment named \code{pkgcode:<pkg.name>}.  If this environment
  does not already exist, it will be created and attached to the search
  path in position \code{pos}.  If it does exist, no attempt is made to
  clean it before sourcing the \code{.R} files.  All functions and
  objects defined in the \code{.R} files will be visible -- namespaces
  are not implemented.

  The easiest way to use this function is when the working directory of
  the R session is the directory where each package lives, i.e., the R
  code for package \code{mypackage} will be in the directory
  \code{./mypackage/R} (relative to the working directory of the R
  session.)  However, if the package directory is located elsewhere,
  supply it as \code{path=}, and this will be remembered for future
  invocations of \code{source.pkg()}.

  This function does not attempt to replicate all the actions involved
  in creating and attaching a package.  It does the following:
  \itemize{
    \item creates a environment named \code{pkgcode:<pkg.name>} where
    \code{<pkg.name>} is the name of the package (if it doesn't already exist)
    \item looks for a \code{Depends} line in the \code{DESCRIPTION} file
  and loads specified packages
    \item looks for \code{.R} files in the \code{R}
    subdirectory of the package, and, as appropriate, the \code{R/windows}
    or \code{R/unix} subdirectories, and uses \code{sys.source()} to
  read these into the \code{pkgcode:<pkg.name>} environment.  If there is a
  \code{Collate} field in the \code{DESCRIPTION} files, this is used to
  sort the files before sourcing them.
    \item looks for \code{.Rdata} and \code{.rda} files in the
  \code{data} subdirectory, and uses \code{load()} to
  read these into the \code{pkgcode:<pkg.name>} environment

  \item if \code{dlls=="check"} (not the default), \code{source.pkg()}
  looks for DLLs (SO files under Unix) in the directory left by \code{R
  CMD check <pkg.dir>}, i.e., in \code{<pkg.dir>.Rcheck/<pkg.name>/libs}, and uses
  \code{dyn.load()} to load these DLLs.  If the DLL was already loaded
  (as indicated by \code{getLoadedDLLs()}), \code{dyn.unload()} is
  called first.  Be aware that unloading and reloading a DLL is not a
  reliable operation under many OS's, and even when the call completes
  without apparent error, the R session can be corrupted.

    }
}
\value{
  A list of the problems encountered when sourcing the files.
}
\references{ \itemize{
    \item Similar ideas in an R-devel post by Barry Rowlingson:
    \url{http://n4.nabble.com/Lightweight-package-idea-td924000.html#a924000}
    \item Hadley Wickham source_package() function
    \url{http://gist.github.com/180883}, reads DESCRIPTION, loads dependencies, respects
    collation order
  }
}
\author{ \email{tplate@blackmesacapital.com} }
\section{Side effects}{
  An environment is created and attached to the search path (or if it
  already exists, it is modified.)
  A variable named \code{working.package} is set in the global
  environment to the name of the package whose code was sourced.
}
\seealso{

\code{\link{runtests}} shares the global variables
\code{working.package} and \code{working.package.path} that provide
defaults for the \code{pkg.dir} and \code{path} arguments.
}

\examples{
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{ misc }