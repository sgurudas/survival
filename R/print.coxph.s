# $Id: print.coxph.S 11059 2008-10-23 12:32:50Z therneau $
print.coxph <-
 function(x, digits=max(options()$digits - 4, 3), ...)
    {
    if (!is.null(cl<- x$call)) {
	cat("Call:\n")
	dput(cl)
	cat("\n")
	}
    if (!is.null(x$fail)) {
	cat(" Coxph failed.", x$fail, "\n")
	return()
	}
    savedig <- options(digits = digits)
    on.exit(options(savedig))

    coef <- x$coefficients
    se <- sqrt(diag(x$var))
    if(is.null(coef) | is.null(se))
        stop("Input is not valid")

    if (is.null(x$naive.var)) {
	tmp <- cbind(coef, exp(coef), se, coef/se,
	       signif(1 - pchisq((coef/ se)^2, 1), digits -1))
	dimnames(tmp) <- list(names(coef), c("coef", "exp(coef)",
	    "se(coef)", "z", "p"))
	}
    else {
	nse <- sqrt(diag(x$naive.var))
	tmp <- cbind(coef, exp(coef), nse, se, coef/se,
	       signif(1 - pchisq((coef/se)^2, 1), digits -1))
	dimnames(tmp) <- list(names(coef), c("coef", "exp(coef)",
	    "se(coef)", "robust se", "z", "p"))
	}
    cat("\n")
    prmatrix(tmp)

    logtest <- -2 * (x$loglik[1] - x$loglik[2])
    if (is.null(x$df)) df <- sum(!is.na(coef))
    else  df <- round(sum(x$df),2)
    cat("\n")
    cat("Likelihood ratio test=", format(round(logtest, 2)), "  on ",
	df, " df,", " p=", format(1 - pchisq(logtest, df)),  sep="")
    omit <- x$na.action
    if (length(omit))
	cat("  n=", x$n, " (", naprint(omit), ")\n", sep="")
    else cat("  n=", x$n, "\n")
    if (length(x$icc))
	cat("   number of clusters=", x$icc[1],
	    "    ICC=", format(x$icc[2:3]), "\n")
    invisible()
    }
