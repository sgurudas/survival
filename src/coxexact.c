/* Automatically generated from the noweb directory */
#include <math.h>
#include "survS.h"
#include "survproto.h"
#include <R_ext/Utils.h>

double coxd0(int d, int n, double *score, double *dmat,
             int dmax) {
    double *dn;
    
    if (d==0) return(1.0);
    dn = dmat + (n-1)*dmax + d -1;  /* pointer to dmat[d,n] */

    if (*dn ==0) {  /* still to be computed */
        *dn = score[n-1]* coxd0(d-1, n-1, score, dmat, dmax);
            if (d<n) *dn += coxd0(d, n-1, score, dmat, dmax);
    }
    return(*dn);
}
double coxd1(int d, int n, double *score, double *dmat, double *d1,
             double *covar, int dmax) {
    int indx;
    
    indx = (n-1)*dmax + d -1;  /*index to the current array member d1[d.n]*/
    if (d1[indx] ==0) { /* still to be computed */
        d1[indx] = score[n-1]* covar[n-1]* coxd0(d-1, n-1, score, dmat, dmax);
        if (d<n) d1[indx] += coxd1(d, n-1, score, dmat, d1, covar, dmax);
        if (d>1) d1[indx] += score[n-1]*
                        coxd1(d-1, n-1, score, dmat, d1, covar, dmax);
    }
    return(d1[indx]);
}

double coxd2(int d, int n, double *score, double *dmat, double *d1j,
             double *d1k, double *d2, double *covarj, double *covark,
             int dmax) {
    int indx;
    
    indx = (n-1)*dmax + d -1;  /*index to the current array member d1[d,n]*/
    if (d2[indx] ==0) { /*still to be computed */
        d2[indx] = coxd0(d-1, n-1, score, dmat, dmax)*score[n-1] *
            covarj[n-1]* covark[n-1];
        if (d<n) d2[indx] += coxd2(d, n-1, score, dmat, d1j, d1k, d2, covarj, 
                                  covark, dmax);
        if (d>1) d2[indx] += score[n-1] * (
            coxd2(d-1, n-1, score, dmat, d1j, d1k, d2, covarj, covark, dmax) +
            covarj[n-1] * coxd1(d-1, n-1, score, dmat, d1k, covark, dmax) +
            covark[n-1] * coxd1(d-1, n-1, score, dmat, d1j, covarj, dmax));
        }
    return(d2[indx]);
}

SEXP coxexact(SEXP maxiter2,  SEXP y2, 
              SEXP covar2,    SEXP offset2, SEXP strata2,
              SEXP ibeta,     SEXP eps2,    SEXP toler2) {
    int i,j,k;
    int     iter;
    
    double **covar, **imat;  /*ragged arrays */
    double *time, *status;   /* input data */
    double *offset;
    int    *strata;
    int    sstart;   /* starting obs of current strata */
    double *score;
    double *oldbeta;
    double  zbeta;
    double  newlk=0;
    double  temp;
    int     halving;    /*are we doing step halving at the moment? */
    int     nrisk;   /* number of subjects in the current risk set */
    int dsize,       /* memory needed for one coxc0, coxc1, or coxd2 array */
        dmemtot,     /* amount needed for all arrays */
        ndeath;      /* number of deaths at the current time point */
    double maxdeath;    /* max tied deaths within a strata */

    double dtime;    /* time value under current examiniation */
    double *dmem0, **dmem1, *dmem2; /* pointers to memory */
    double *dtemp;   /* used for zeroing the memory */
    double *d1;     /* current first derivatives from coxd1 */
    double d0;      /* global sum from coxc0 */
        
    /* copies of scalar input arguments */
    int     nused, nvar, maxiter;
    double  eps, toler;
    
    /* returned objects */
    SEXP imat2, beta2, u2, loglik2;
    double *beta, *u, *loglik;
    SEXP rlist, rlistnames;
    int nprotect;  /* number of protect calls I have issued */
    
    nused = LENGTH(offset2);
    nvar  = ncols(covar2);
    maxiter = asInteger(maxiter2);
    eps  = asReal(eps2);     /* convergence criteria */
    toler = asReal(toler2);  /* tolerance for cholesky */

    /*
    **  Set up the ragged array pointer to the X matrix,
    **    and pointers to time and status
    */
    covar= dmatrix(REAL(covar2), nused, nvar);
    time = REAL(y2);
    status = time +nused;
    strata = INTEGER(PROTECT(duplicate(strata2)));
    offset = REAL(offset2);

    /* temporary vectors */
    score = (double *) R_alloc(nused+nvar, sizeof(double));
    oldbeta = score + nused;

    /* 
    ** create output variables
    */ 
    PROTECT(beta2 = duplicate(ibeta));
    beta = REAL(beta2);
    PROTECT(u2 = allocVector(REALSXP, nvar));
    u = REAL(u2);
    PROTECT(imat2 = allocVector(REALSXP, nvar*nvar)); 
    imat = dmatrix(REAL(imat2),  nvar, nvar);
    PROTECT(loglik2 = allocVector(REALSXP, 5)); /* loglik, sctest, flag,maxiter*/
    loglik = REAL(loglik2);
    nprotect = 5;
    strata[0] =1;  /* in case the parent forgot */
    temp = 0;      /* temp variable for dsize */

    maxdeath =0;
    j=0;   /* start of the strata */
    for (i=0; i<nused;) {
      if (strata[i]==1) { /* first obs of a new strata */
          if (i>0) {
              /* If maxdeath <2 leave the strata alone at it's current value of 1 */
              if (maxdeath >1) strata[j] = maxdeath;
              j = i;
              if (maxdeath*nrisk > temp) temp = maxdeath*nrisk;
              }
          maxdeath =0;  /* max tied deaths at any time in this strata */
          nrisk=0;
          ndeath =0;
          }
      dtime = time[i];
      ndeath =0;  /*number tied here */
      while (time[i] ==dtime) {
          nrisk++;
          ndeath += status[i];
          i++;
          if (i>=nused || strata[i] >0) break;  /*tied deaths don't cross strata */
          }
      if (ndeath > maxdeath) maxdeath=ndeath;
      }
    if (maxdeath*nrisk > temp) temp = maxdeath*nrisk;
    if (maxdeath >1) strata[j] = maxdeath;

    /* Now allocate memory for the scratch arrays 
       Each per-variable slice is of size dsize 
    */
    dsize = temp;
    temp    = temp * ((nvar*(nvar+1))/2 + nvar + 1);
    dmemtot = dsize * ((nvar*(nvar+1))/2 + nvar + 1);
    if (temp != dmemtot) { /* the subscripts will overflow */
        error("(number at risk) * (number tied deaths) is too large");
    }
    dmem0 = (double *) R_alloc(dmemtot, sizeof(double)); /*pointer to memory */
    dmem1 = (double **) R_alloc(nvar, sizeof(double*));
    dmem1[0] = dmem0 + dsize; /*points to the first derivative memory */
    for (i=1; i<nvar; i++) dmem1[i] = dmem1[i-1] + dsize;
    d1 = (double *) R_alloc(nvar, sizeof(double)); /*first deriv results */
    /*
    ** do the initial iteration step
    */
    newlk =0;
    for (i=0; i<nvar; i++) {
        u[i] =0;
        for (j=0; j<nvar; j++)
            imat[i][j] =0 ;
        }
    for (i=0; i<nused; ) {
        if (strata[i] >0) { /* first obs of a new strata */
            maxdeath= strata[i];
            dtemp = dmem0;
            for (j=0; j<dmemtot; j++) *dtemp++ =0.0;
            sstart =i;
            nrisk =0;
        }
        
        dtime = time[i];  /*current unique time */
        ndeath =0;
        while (time[i] == dtime) {
            zbeta= offset[i];
            for (j=0; j<nvar; j++) zbeta += covar[j][i] * beta[j];
            score[i] = exp(zbeta);
            if (status[i]==1) {
                newlk += zbeta;
                for (j=0; j<nvar; j++) u[j] += covar[j][i];
                ndeath++;
            }
            nrisk++;
            i++;
            if (i>=nused || strata[i] >0) break; 
        }

        /* We have added up over the death time, now process it */
        if (ndeath >0) { /* Add to the loglik */
            d0 = coxd0(ndeath, nrisk, score+sstart, dmem0, maxdeath);
            R_CheckUserInterrupt();
            newlk -= log(d0);
            dmem2 = dmem0 + (nvar+1)*dsize;  /*start for the second deriv memory */
            for (j=0; j<nvar; j++) { /* for each covariate */
                d1[j] = coxd1(ndeath, nrisk, score+sstart, dmem0, dmem1[j], 
                              covar[j]+sstart, maxdeath) / d0;
                if (ndeath > 3) R_CheckUserInterrupt();
                u[j] -= d1[j];
                for (k=0; k<= j; k++) {  /* second derivative*/
                    temp = coxd2(ndeath, nrisk, score+sstart, dmem0, dmem1[j],
                                 dmem1[k], dmem2, covar[j] + sstart, 
                                 covar[k] + sstart, maxdeath);
                    if (ndeath > 5) R_CheckUserInterrupt();
                    imat[k][j] += temp/d0 - d1[j]*d1[k];
                    dmem2 += dsize;
                }
            }
        }
     }

    loglik[0] = newlk;   /* save the loglik for iteration zero  */
    loglik[1] = newlk;  /* and it is our current best guess */
    /* 
    **   update the betas and compute the score test 
    */
    for (i=0; i<nvar; i++) /*use 'd1' as a temp to save u0, for the score test*/
        d1[i] = u[i];

    loglik[3] = cholesky2(imat, nvar, toler);
    chsolve2(imat,nvar, u);        /* u replaced by  u *inverse(imat) */

    loglik[2] =0;                  /* score test stored here */
    for (i=0; i<nvar; i++)
        loglik[2] +=  u[i]*d1[i];

    if (maxiter==0) {
        iter =0;  /*number of iterations */
        loglik[4] = iter;
        chinv2(imat, nvar);
        for (i=1; i<nvar; i++)
            for (j=0; j<i; j++)  imat[i][j] = imat[j][i];

        /* assemble the return objects as a list */
        PROTECT(rlist= allocVector(VECSXP, 4));
        SET_VECTOR_ELT(rlist, 0, beta2);
        SET_VECTOR_ELT(rlist, 1, u2);
        SET_VECTOR_ELT(rlist, 2, imat2);
        SET_VECTOR_ELT(rlist, 3, loglik2);

        /* add names to the list elements */
        PROTECT(rlistnames = allocVector(STRSXP, 4));
        SET_STRING_ELT(rlistnames, 0, mkChar("coef"));
        SET_STRING_ELT(rlistnames, 1, mkChar("u"));
        SET_STRING_ELT(rlistnames, 2, mkChar("imat"));
        SET_STRING_ELT(rlistnames, 3, mkChar("loglik"));
        setAttrib(rlist, R_NamesSymbol, rlistnames);

        unprotect(nprotect+2);
        return(rlist);
        }

    /*
    **  Never, never complain about convergence on the first step.  That way,
    **  if someone has to they can force one iter at a time.
    */
    for (i=0; i<nvar; i++) {
        oldbeta[i] = beta[i];
        beta[i] = beta[i] + u[i];
        }
    halving =0 ;             /* =1 when in the midst of "step halving" */
    for (iter=1; iter<=maxiter; iter++) {
        newlk =0;
        for (i=0; i<nvar; i++) {
            u[i] =0;
            for (j=0; j<nvar; j++)
                    imat[i][j] =0;
            }
        for (i=0; i<nused; ) {
            if (strata[i] >0) { /* first obs of a new strata */
                maxdeath= strata[i];
                dtemp = dmem0;
                for (j=0; j<dmemtot; j++) *dtemp++ =0.0;
                sstart =i;
                nrisk =0;
            }
            
            dtime = time[i];  /*current unique time */
            ndeath =0;
            while (time[i] == dtime) {
                zbeta= offset[i];
                for (j=0; j<nvar; j++) zbeta += covar[j][i] * beta[j];
                score[i] = exp(zbeta);
                if (status[i]==1) {
                    newlk += zbeta;
                    for (j=0; j<nvar; j++) u[j] += covar[j][i];
                    ndeath++;
                }
                nrisk++;
                i++;
                if (i>=nused || strata[i] >0) break; 
            }

            /* We have added up over the death time, now process it */
            if (ndeath >0) { /* Add to the loglik */
                d0 = coxd0(ndeath, nrisk, score+sstart, dmem0, maxdeath);
                R_CheckUserInterrupt();
                newlk -= log(d0);
                dmem2 = dmem0 + (nvar+1)*dsize;  /*start for the second deriv memory */
                for (j=0; j<nvar; j++) { /* for each covariate */
                    d1[j] = coxd1(ndeath, nrisk, score+sstart, dmem0, dmem1[j], 
                                  covar[j]+sstart, maxdeath) / d0;
                    if (ndeath > 3) R_CheckUserInterrupt();
                    u[j] -= d1[j];
                    for (k=0; k<= j; k++) {  /* second derivative*/
                        temp = coxd2(ndeath, nrisk, score+sstart, dmem0, dmem1[j],
                                     dmem1[k], dmem2, covar[j] + sstart, 
                                     covar[k] + sstart, maxdeath);
                        if (ndeath > 5) R_CheckUserInterrupt();
                        imat[k][j] += temp/d0 - d1[j]*d1[k];
                        dmem2 += dsize;
                    }
                }
            }
         }
                   
        /* am I done?
        **   update the betas and test for convergence
        */
        loglik[3] = cholesky2(imat, nvar, toler); 

        if (fabs(1-(loglik[1]/newlk))<= eps && halving==0) { /* all done */
            loglik[1] = newlk;
           loglik[4] = iter;
           chinv2(imat, nvar);
           for (i=1; i<nvar; i++)
               for (j=0; j<i; j++)  imat[i][j] = imat[j][i];

           /* assemble the return objects as a list */
           PROTECT(rlist= allocVector(VECSXP, 4));
           SET_VECTOR_ELT(rlist, 0, beta2);
           SET_VECTOR_ELT(rlist, 1, u2);
           SET_VECTOR_ELT(rlist, 2, imat2);
           SET_VECTOR_ELT(rlist, 3, loglik2);

           /* add names to the list elements */
           PROTECT(rlistnames = allocVector(STRSXP, 4));
           SET_STRING_ELT(rlistnames, 0, mkChar("coef"));
           SET_STRING_ELT(rlistnames, 1, mkChar("u"));
           SET_STRING_ELT(rlistnames, 2, mkChar("imat"));
           SET_STRING_ELT(rlistnames, 3, mkChar("loglik"));
           setAttrib(rlist, R_NamesSymbol, rlistnames);

           unprotect(nprotect+2);
           return(rlist);
            }

        if (iter==maxiter) break;  /*skip the step halving and etc */

        if (newlk < loglik[1])   {    /*it is not converging ! */
                halving =1;
                for (i=0; i<nvar; i++)
                    beta[i] = (oldbeta[i] + beta[i]) /2; /*half of old increment */
                }
        else {
                halving=0;
                loglik[1] = newlk;
                chsolve2(imat,nvar,u);

                for (i=0; i<nvar; i++) {
                    oldbeta[i] = beta[i];
                    beta[i] = beta[i] +  u[i];
                    }
                }
        }   /* return for another iteration */


    /*
    ** Ran out of iterations 
    */
    loglik[1] = newlk;
    loglik[3] = 1000;  /* signal no convergence */
    loglik[4] = iter;
    chinv2(imat, nvar);
    for (i=1; i<nvar; i++)
        for (j=0; j<i; j++)  imat[i][j] = imat[j][i];

    /* assemble the return objects as a list */
    PROTECT(rlist= allocVector(VECSXP, 4));
    SET_VECTOR_ELT(rlist, 0, beta2);
    SET_VECTOR_ELT(rlist, 1, u2);
    SET_VECTOR_ELT(rlist, 2, imat2);
    SET_VECTOR_ELT(rlist, 3, loglik2);

    /* add names to the list elements */
    PROTECT(rlistnames = allocVector(STRSXP, 4));
    SET_STRING_ELT(rlistnames, 0, mkChar("coef"));
    SET_STRING_ELT(rlistnames, 1, mkChar("u"));
    SET_STRING_ELT(rlistnames, 2, mkChar("imat"));
    SET_STRING_ELT(rlistnames, 3, mkChar("loglik"));
    setAttrib(rlist, R_NamesSymbol, rlistnames);

    unprotect(nprotect+2);
    return(rlist);
    }
