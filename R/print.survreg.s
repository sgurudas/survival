print.survreg <- function(x, ...)
{
    if(!is.null(cl <- x$call)) {
        cat("Call:\n")
        dput(cl)
        }
    if (!is.null(x$fail)) {
	cat(" Survreg failed.", x$fail, "\n")
	return(invisible(x))
	}
    coef <- x$coef
    if(any(nas <- is.na(coef))) {
	if(is.null(names(coef))) names(coef) <- paste("b", 1:length(coef), sep = "")
        cat("\nCoefficients: (", sum(nas), 
            " not defined because of singularities)\n", sep = "")
        }
    else cat("\nCoefficients:\n")
    print(coef, ...)
    
    if (nrow(x$var)==length(coef)) 
	    cat("\nScale fixed at",format(x$scale),"\n") 
    else if (length(x$scale)==1) cat ("\nScale=", format(x$scale), "\n")
    else {
	cat("\nScale:\n")
	print(x$scale, ...)
	}

    pdig <- max(1, getOption("digits")-4)  # default it too high IMO
    nobs <- length(x$linear)
    chi <- 2*diff(x$loglik)
    df  <- sum(x$df) - x$idf   # The sum is for penalized models
    cat("\nLoglik(model)=", format(round(x$loglik[2],1)),
	"  Loglik(intercept only)=", format(round(x$loglik[1],1)))
    if (df > 0)
	    cat("\n\tChisq=", format(round(chi,2)), "on", round(df,1),
		"degrees of freedom, p=", 
		format.pval(pchisq(chi, df, lower.tail=FALSE), digits=pdig), 
                "\n")
    else cat("\n")

    omit <- x$na.action
    if (length(omit))
	cat("n=", nobs, " (", naprint(omit), ")\n", sep="")
    else cat("n=", nobs, "\n")
    invisible(x)
    }
