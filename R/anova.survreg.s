# SCCS @(#)anova.survreg.s	1.1 01/18/99
anova.survreg <- function(object, ..., test = c("Chisq", "none")) {
    test <- match.arg(test)
    margs <- function(...)
	    nargs()
    if(margs(...))
	    return(anova.survreglist(list(object, ...), test = test))
    Terms <- object$terms
    term.labels <- attr(Terms, "term.labels")
    nt <- length(term.labels)
    m <- model.frame(object)
    family.obj <- object$family
    y <- model.extract(m, "response")
    if(!inherits(y, "Surv"))
	    stop("Response must be a survival object")
    loglik <- double(nt + 1)
    df.res <- loglik
    if(nt) {
	loglik[nt + 1] <- -2 * object$loglik[2]
	df.res[nt + 1] <- sum(object$df)
	fit <- object
	for(iterm in seq(from = nt, to = 1, by = -1)) {
	    argslist <- list(object = fit, 
			     formula = eval(parse(text = paste("~ . -", 
						    term.labels[iterm]))))
	    fit <- do.call("update", argslist)
	    loglik[iterm] <- -2 * fit$loglik[2]
	    df.res[iterm] <- sum(fit$df)
	    }
	dev <- c(NA,  - diff(loglik))
        df <- c(NA,  diff(df.res)) 
	}
    else {
	loglik[1] <- -2 * object$loglik[2]
	df.res[1] <- dim(y)[1] - attr(Terms, "intercept")
	dev <- df <- as.numeric(NA)
	}
    heading <- c("Analysis of Deviance Table\n", 
		 paste(family.obj[1], "distribution with", family.obj[2], 
		       "link\n"), 
		 paste("Response: ", as.character(formula(object))[2], 
		       "\n", sep = ""),
		 "Terms added sequentially (first to last)")
    aod <- data.frame(Df = df, Deviance = dev, "Resid. Df" = df.res, 
		      "-2*LL" = loglik, row.names = c("NULL", term.labels), 
		      check.names = FALSE)
    attr(aod, "heading") <- heading
    class(aod) <- c("anova", "data.frame")
    if(test == "none")
	    return(aod)
    else stat.anova(aod, test, scale=1,n = nrow(y))
    }
