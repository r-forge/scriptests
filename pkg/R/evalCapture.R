evalCapture <- function(expr, envir=globalenv(), enclos=envir) {
    ## Try to return the output that is returned at an interactive prompt
    ## when given the contents of 'text', including error messages
    ## (only the value from the last expression in text is printed)
    ## A zero-length character vector is returned when the result is invisible.
    ## Constructed this definition of eval.with.vis() based on code in source()
    ##
    ## See also https://github.com/hadley/evaluate which does similar things, esp
    ## if there are changes in R that make this code stop working.
    if (is.null(expr))
        return(character(0))
    withWarnings <- function(expr) {
        ## Note that capturing warnings in the way done here bypasses the standard
        ## warning handling mechanisms, so options(warn=) makes no difference to
        ## how the code behaves here.  Rather than try to reproduce all the behaviors,
        ## settle for simulating options(warn=1) (i.e., print warnings immediately)
        ## The standard warnings handling code is in
        ##   static void vwarningcall_dflt(SEXP call, const char *format, va_list ap)
        ## in src/main/errors.c
        ## TODO: make this code handle truncation of long warnings correctly
        ## (cf options("warning.length"))
        wHandler <- function(w) {
            ## Try to format the message in the same way as is done
            ## for standard warning messages. (see vwarningcall_dflt() in src/main/errors.c)
            dcall <- deparse(w$call, nlines=1)
            if (sum(nchar(dcall)) + sum(nchar(w$message)) + 18 <= 75)
                cat("Warning in ", dcall, " : ", w$message, "\n", sep="")
            else
                cat("Warning in ", dcall, " :\n  ", w$message, "\n", sep="")
            invokeRestart("muffleWarning")
        }
        withCallingHandlers(expr, warning = wHandler)
    }
    ## Constructed this definition of eval.with.vis() based on code in source()
    ## and added the withWarnings() stuff to capture the warnings as well
    eval.with.vis <- function(expr, envir = envir, enclos = envir) {
        output <- capture.output(withWarnings(res <- .Internal(eval.with.vis(expr, envir, enclos))))
        res$output <- output
        res
    }
    res <- try(eval.with.vis(expr, envir, enclos), silent=TRUE)
    if (is(res, "try-error")) {
        res[1] <- sub("^Error in eval.with.vis\\(expr, envir, enclos\\) :", "Error:", res[1], perl=TRUE)
        res <- sub("\n$", "", res)
        # Split line at embedded newlines, important for "Error: in f(...) : \n ..."
        res <- unlist(strsplit(res, "\n"))
        return(as.character(res))
    }
    if (res$visible) {
        res2 <- try(capture.output(print(res$value)), silent=TRUE)
        return(c(res$output, as.character(res2)))
    } else {
        return(res$output)
    }
}

