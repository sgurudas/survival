# SCCS @(#)model.frame.survreg.s	1.1 11/25/98
model.frame.survreg <- function(formula, ...) {
    Call <- formula$call
    Call[[1]] <- as.name("model.frame")
    Call <- Call[match(c("", "formula", "data", "weights", "subset",
			   "na.action"), names(Call), 0)]
    dots <- list(...)
    nargs <- dots[match(c("data", "na.action", "subset"), names(dots), 0)]
    Call[names(nargs)] <- nargs
    env<-environment(formula$terms)
    if (is.null(env)) env<-parent.frame()
    eval(Call, env)
    }
