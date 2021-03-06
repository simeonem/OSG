#!/usr/bin/env Rscript
# args = commandArgs(trailingOnly=TRUE)
# print(args)
# arg_file = as.array(args[1])
# print(arg_file)
# j_global=as.numeric(args[2])
# dataset_file = as.array(args[3])
# workspace_directory=as.array(args[4])
# i_exp=as.numeric(args[5])

i_exp=1
j_global=1
workspace_directory <- getwd()
#workspace_directory <-setwd("C:/Users/simeonem/Documents/CBDA-SL/Cranium/")
ADNI = read.csv("ADNI_dataset.txt",header = TRUE)
arg_file = c("arg_ADNI.txt")
eval(parse(text=paste0("arguments = read.table(arg_file, header = TRUE)")))

# label to append to the RData workspaces as soon as they are created
label=c("ADNI_dataset")
# /ifshome/pipelnvt/ # home directory as aguest on LONI Pipeline on "Cranium"

#Set the list of packages/libraries to install/include (done through the ipak.R function)

# Full package list
#packages <- c("ggplot2", "plyr", "colorspace","grid","data.table","VIM","MASS","Matrix",
#              "lme4","arm","foreach","glmnet","class","nnet","mice","missForest",
#              "calibrate","nnls","SuperLearner","plotrix","TeachingDemos","plotmo",
#              "earth","parallel","splines","gam","mi",
#              "BayesTree","e1071","randomForest", "Hmisc","dplyr","Amelia","bartMachine","knockoff")

# Restricted package list - only packages that successfully install with R
# 3.2.2. No VIM, Amelia, bartMachine.
#
# Need to update the Superlearner call to reflect this.
packages <- c("ggplot2", "plyr", "colorspace","grid","data.table","MASS","Matrix",
              "lme4","arm","foreach","glmnet","class","nnet","mice","missForest",
              "calibrate","nnls","SuperLearner","plotrix","TeachingDemos","plotmo",
              "earth","parallel","splines","gam","mi",
              "BayesTree","e1071","randomForest", "Hmisc","dplyr","knockoff")
## ipak function below: load multiple R packages, don't install.
ipak <- function(packages){
	result = TRUE
	for (package in packages) {
		cat(sprintf("\n%s: Loading ===========\n", package))

		if (require(package, character.only=T, quietly=T)) {
			cat(sprintf("%s load succeeded ===========\n", package))
		}
		else {
			result = FALSE     
			cat(sprintf("%s load failed ===========\n", package))
		}	
	}  

	cat(sprintf("\nFinished loading packages ============\n"))

	return(result)
}

result = ipak(packages)
if(!result) {

	cat(sprintf("\n\nPackage load failures !!!!!!!!!!!!\n"))
	stop()
} else
{
	cat(sprintf("\n\nPackage load successful ============\n\n"))
}

# Reads the dataset to be processed as passed from the input argument
#eval(parse(text=paste0("ADNI = read.csv(dataset_file, header = TRUE)")))
#print('1')
names(ADNI)[8]<- "subjectinfo"
#names(ADNI)[9]<- "subjectinfo_A1"
#names(ADNI)[10]<- "subjectinfo_A2"
#print("adni")
#ADNI <- ADNI[,-c(2:6,11,20)]
## columns to eliminate --> c(1:6,9:11,17,20)
ADNI <- ADNI[,-c(1:6,9:11,17,20:22)]
#transfer sex to binomial variables
ADNI$subjectSex <- ifelse(ADNI$subjectSex == 'F',0,1)
ADNI1_Final_Normal = ADNI[ADNI$subjectinfo == "Normal",]
ADNI1_Final_AD = ADNI[ADNI$subjectinfo == "AD",]
ADNI1_Final_MCI = ADNI[ADNI$subjectinfo == "MCI",]
ADNI1_Final_LMCI = ADNI[ADNI$subjectinfo == "LMCI",]


# Merge the datasets for training. I am defining 3 datsets here to be used for training
# since the SuperLearner function only works with binomial outcomes (for now).
# We will test SL comparing AD vs NC
ADNI1_Final_Normal_vs_AD_training = rbind(ADNI1_Final_Normal,ADNI1_Final_AD) # This is our aggregated dataset !!

# Labels the columns of the new matrices
names(ADNI1_Final_Normal_vs_AD_training) <- c(names(ADNI1_Final_Normal_vs_AD_training))

# Defining and recasting the binary variable Group for each dataset
ADNI1_Final_Normal_vs_AD_training$subjectinfo <- ifelse(ADNI1_Final_Normal_vs_AD_training$subjectinfo=="AD",1,0)


# Define the temporary output [Ytemp] and input [Xtemp] matrices for the SuperLearner call
#Xtemp = ADNI1_Final_Normal_vs_AD_training[,-3]; # temporary X-->Xtemp to modify and pass to SuperLearner
Xtemp = ADNI1_Final_Normal_vs_AD_training[,-2]; # temporary X-->Xtemp to modify and pass to SuperLearner

# Assign the Group column to the output Y
Ytemp = ADNI1_Final_Normal_vs_AD_training$subjectinfo; # Output Matrix Y for SuperLearner

# SET THE SAME NAMES/LABELS FOR THE X dataset
original_names <- names(Xtemp)
names(Xtemp) <- 1:dim(Xtemp)[2]

# # Sets the nonzero features [only used for testing]
# p = 100;   # number of variables
# nonzero=c(1,seq(10,p,10)); # variables with nonzero coefficients

## IMPUTATION AND NORMALIZATION STEP (OFFLINE ON THE WHOLE DATASET)
## DATA IMPUTATION
# Xtemp is the dataset to be imputed before the SL-LOOP
# Here I first replace % (i.e., misValperc) of the data with missing data (i.e., NA)
eval(parse(text=paste0("arguments = read.table(arg_file, header = TRUE)")))
misValperc <- arguments[i_exp,2]
# For real datasets, there's no need to pass the missValperc, because 
# we will impute whatever the missing values are

#Xtemp_mis <- prodNA(Xtemp, noNA = misValperc/100)
Xtemp_mis <- Xtemp
# Here I impute the missing data in Xtemp.mis with the function missForest
Xtemp_imp <- missForest(Xtemp_mis, maxiter = 5)

## DATA NORMALIZATION of the sampled matrix without Group and Sex
## This step can be generalized if the data is formatted RAW,
# with categorical variables as binary or strings (see commented out example below)
# a1 = which(names(Xtemp_imp$ximp) == "Group")
# a2 = which(names(Xtemp_imp$ximp) == "Sex")
# cont = 1:length(Xtemp_imp$ximp)
# cont <- cont[-1*c(a1,a2)]
# # DATA NORMALIZATION if IMPUTATION IS PERFORMED
Xnorm_ALL <- as.data.frame(scale(Xtemp_imp$ximp))

## SAMPLE THE PREDICTION DATASET -- THIS STEP IS DATA INDEPENDENT
## The fraction alpha of data/patients to use for prediction could be passed as an input argument as well
## Below the sampling is balanced
## Eliminating q subjects for prediction, in a BALANCED WAY
alpha = 0.30; # % of the initial subjects to set aside for prediction
## Subjects to sample in a balanced way from 0-1 outcomes
a0 = round(alpha*dim(Xtemp)[1]/2)
# Randomly select patients for prediction
q1 = sample(which(Ytemp==1),a0)
q2 = sample(which(Ytemp==0),a0)
q <- c(q1 , q2)
# q <- round(length(Ytemp)*alpha); 
# q <- sample(length(Ytemp),q) # sampling the q patients from the dataset
Xpred <- Xnorm_ALL[q,]
Xnorm_sub <- Xnorm_ALL[-1*q,]  # eliminate the q patients from the "training/learning" matrix of features (renamed as Xnorm) [not used in the training]
Ypred <- Ytemp[q] # define the output for prediction (renamed Ypred) [not used in the training/learning]
Ytemp_sub <- Ytemp[-1*q] # define the output for learning by eliminating the q subjects that are not used in the training/learning



# STEPS 5 and 6 ADD LIBRARIES
# Specify new SL prediction algorithm wrappers 
SL.glmnet.0 <- function(..., alpha = 0){
  SL.glmnet(..., alpha = alpha)
} # ridge penalty

SL.glmnet.0.25 <- function(..., alpha = 0.25){
  SL.glmnet(..., alpha = alpha)
}

SL.glmnet.0.50 <- function(..., alpha = 0.50){
  SL.glmnet(..., alpha = alpha)
}

SL.glmnet.0.75 <- function(..., alpha = 0.75){
  SL.glmnet(..., alpha = alpha)
}

SL.gam.1<-function(...,control=gam.control(deg.gam=1)){
  SL.gam(...,control=control)
}
SL.gam.3<-function(...,control=gam.control(deg.gam=3)){
  SL.gam(...,control=control)
}
SL.gam.4<-function(...,control=gam.control(deg.gam=4)){
  SL.gam(...,control=control)
}
SL.gam.5<-function(...,control=gam.control(deg.gam=5)){
  SL.gam(...,control=control)
}

create.SL.glmnet.alpha<-function(...,alpha=c(0.25,0.5,0.75))
{
  SL.glmnet(..., alpha=alpha)
}

## The bartMachine wrapper won't be necessary with the latest release of the SL.bartMachine.
## It's not properly installed yet.

#' Wrapper for bartMachine learner
#'
#' Support bayesian additive regression trees via the bartMachine package.
#'
#' @param Y Outcome variable
#' @param X Covariate dataframe
#' @param newX Optional dataframe to predict the outcome
#' @param obsWeights Optional observation-level weights (supported but not tested)
#' @param id Optional id to group observations from the same unit (not used
#'   currently).
#' @param family "gaussian" for regression, "binomial" for binary
#'   classification
#' @param num_trees The number of trees to be grown in the sum-of-trees model.
#' @param num_burn_in Number of MCMC samples to be discarded as "burn-in".
#' @param num_iterations_after_burn_in Number of MCMC samples to draw from the
#'   posterior distribution of f(x).
#' @param alpha Base hyperparameter in tree prior for whether a node is
#'   nonterminal or not.
#' @param beta Power hyperparameter in tree prior for whether a node is
#'   nonterminal or not.
#' @param k For regression, k determines the prior probability that E(Y|X) is
#'   contained in the interval (y_{min}, y_{max}), based on a normal
#'   distribution. For example, when k=2, the prior probability is 95\%. For
#'   classification, k determines the prior probability that E(Y|X) is between
#'   (-3,3). Note that a larger value of k results in more shrinkage and a more
#'   conservative fit.
#' @param q Quantile of the prior on the error variance at which the data-based
#'   estimate is placed. Note that the larger the value of q, the more
#'   aggressive the fit as you are placing more prior weight on values lower
#'   than the data-based estimate. Not used for classification.
#' @param nu Degrees of freedom for the inverse chi^2 prior. Not used for
#'   classification.
#' @param verbose Prints information about progress of the algorithm to the
#'   screen.
#' @param ... Additional arguments (not used)
#'
#' @encoding utf-8
#' @export
SL.bartMachine <- function(Y, X, newX, family, obsWeights, id,
                           num_trees = 50, num_burn_in = 250, verbose = F,
                           alpha = 0.95, beta = 2, k = 2, q = 0.9, nu = 3,
                           num_iterations_after_burn_in = 1000,
                           ...) {
  #.SL.require("bartMachine")
  model = bartMachine::bartMachine(X, Y, num_trees = num_trees,
                                   num_burn_in = num_burn_in, verbose = verbose,
                                   alpha = alpha, beta = beta, k = k, q = q, nu = nu,
                                   num_iterations_after_burn_in = num_iterations_after_burn_in)
  # pred returns predicted responses (on the scale of the outcome)
  pred <- predict(model, newX)
  # fit returns all objects needed for predict.SL.template
  fit <- list(object = model)
  #fit <- vector("list", length=0)
  class(fit) <- c("SL.bartMachine")
  out <- list(pred = pred, fit = fit)
  return(out)
}

#' bartMachine prediction
#' @param object SuperLearner object
#' @param newdata Dataframe to predict the outcome
#' @param family "gaussian" for regression, "binomial" for binary
#'   classification. (Not used)
#' @param Y Outcome variable (not used)
#' @param X Covariate dataframe (not used)
#' @param ... Additional arguments (not used)
#'
#' @export
predict.SL.bartMachine <- function(object, newdata, family, X = NULL, Y = NULL,...) {
  pred <- predict(object$object, newdata)
  return(pred)
}
# SL.library <- c("SL.glm","SL.gam","SL.gam.1","SL.gam.3","SL.gam.4","SL.gam.5",
#                 "SL.glmnet","SL.glmnet.0","SL.glmnet.0.25","SL.glmnet.0.50","SL.glmnet.0.75",
#                 "SL.svm",
#                 "SL.randomForest","SL.bartMachine")
#SL.library <- c("SL.glm",
#                "SL.glmnet","SL.glmnet.0","SL.glmnet.0.25","SL.glmnet.0.50","SL.glmnet.0.75",
#                "SL.svm","SL.randomForest","SL.bartMachine")

# Don't include bartMachine, since the R packages it needs aren't included in
# the package load above.
SL.library <- c("SL.glm",
                "SL.glmnet","SL.glmnet.0","SL.glmnet.0.25","SL.glmnet.0.50","SL.glmnet.0.75",
                "SL.svm","SL.randomForest")

## Assess the dimensions of the normalized data matrix
coordSL=dim(Xnorm_sub)
N=coordSL[1]
K=coordSL[2]


## INITIALIZATION BEFORE THE SUPERLEARNER LOOP
M <-arguments[i_exp,1]
print(misValperc)
Kcol_min <- arguments[i_exp,3]
Kcol_max <- arguments[i_exp,4]
Nrow_min <- arguments[i_exp,5]
Nrow_max <- arguments[i_exp,6]
range_n <- eval(parse(text=paste0("c(\"",Nrow_min,"_",Nrow_max,"\")")))
range_k <- eval(parse(text=paste0("c(\"",Kcol_min,"_",Kcol_max,"\")")))

Kcol <- round(dim(Xnorm_sub)[2]*(runif(1,Kcol_min/100,Kcol_max/100))) # sample a value from a uniform distribution within 0.6 and 0.8 [number of rows/subjects between 60-80% of the big dataset]
eval(parse(text=paste0("k <- sample(1:length(Xnorm_sub),Kcol)")))
Nrow <- round(dim(Xnorm_sub)[1]*(runif(1,Nrow_min/100,Nrow_max/100))) # sample a value from a uniform distribution within 0.6 and 0.8 [number of rows/subjects between 60-80% of the big dataset]
eval(parse(text=paste0("n <- sample(1:length(Ytemp_sub),Nrow)")))



print(c(j_global,i_exp))
k <- sample(1:dim(Xtemp)[2],Kcol) # this is where I generate the sample of columns
#k <- sample(1:K,Kcol)
n <- 1:length(Ytemp)
n <- n[-q]
n <- sample(n,Nrow) # this is where I generate the sample of rows
#n <- 1:N # this is where I generate the sample of rows
# Automated labeling of sub-matrices, assigned to X
eval(parse(text=paste0("X",j_global," <- Xnorm_ALL[n,k]")))
eval(parse(text=paste0("X <- as.data.frame(X",j_global,")")))
eval(parse(text=paste0("Y",j_global," <- Ytemp[n]")))
eval(parse(text=paste0("Y <- Y",j_global)))
eval(parse(text=paste0("k",j_global," <- k")))
eval(parse(text=paste0("n",j_global," <- n")))


## KNOCKOFF FILTER IMPLEMENTATION  
## IMPORTANT  --> subjects # >> features # !!!
## It creates KO_result_j objects with all the stats, results, FDR proportion,...
# knockoff.filter(X, Y, fdr = 0.2, statistic = NULL,
# threshold = c("knockoff", "knockoff+"), knockoffs = c("equicorrelated","sdp"),
#               normalize = TRUE, randomize = FALSE)

#eval(parse(text=paste0("KO_result_",j_global," = knockoff.filter(Xnorm_sub[n",j_global,",k",j_global,"], Ytemp_sub[n",j_global,"],fdr = 0.05)")))
eval(parse(text=paste0("KO_result_",j_global," = knockoff.filter(X, Y,fdr = 0.05)")))

eval(parse(text=paste0("KO_selected_",j_global," <- as.numeric(sub(\"V\",\"\",names(KO_result_",j_global,"$selected)))")))
eval(parse(text=paste0("print(KO_selected_",j_global,")")))

## SUPERLEARNER LOOP
# SUPERLEARNER-SL FUNCTION CALL that generates SL objects
## Superlearner Function ##
SL <- try(SuperLearner(Y,X,
                       family=binomial(),
                       SL.library=SL.library,
                       method="method.NNLS",
                       verbose = FALSE,
                       control = list(saveFitLibrary = TRUE),
                       cvControl = list(V=10)));
eval(parse(text=paste0("SL_",j_global," <- SL")));
eval(parse(text=paste0("SL_",j_global)))

# STEP 7 - GENERATING PREDICTIONS ON THE PREDICTION DATASET
# Generates SL_Pred object using the predict function on the prediction 
# dataset with the SL object as the predictive model.
# SL_Pred returns both the SuperLearner predictions ("pred") and 
# predictions for each algorithm in the library (SL.library above)
eval(parse(text=paste0("try(SL_Pred_",j_global," <- predict(SL_",j_global,", Xpred[,k",j_global,"]))")))

# This checks if the SL_Pred object was successfully generated (i.e., if it exists)
# If it does not exist, it is set to a double equal to 100
eval(parse(text=paste0("ifelse(exists(\"SL_Pred_",j_global,"\"),'OK',
                   SL_Pred_",j_global," <- 100)")))

# GENERATE THE LIGHT DATASET BY DELETING THE SL OBJECT
eval(parse(text=paste0("rm(SL_",j_global,")")))
nonzero=0;
# SAVE THE RDATA WORKSPACE WITH THE ALL DATA
eval(parse(text=paste0("save(Xpred,label, Xnorm_ALL, Xnorm_sub, q, Ypred, M, Ytemp, Ytemp_sub, SL_Pred_",j_global,
                       ",nonzero,n",j_global,",k",j_global,",KO_selected_",j_global,",
                       file= \"",workspace_directory,"/CBDA_SL_M",M,"_miss",misValperc,"_n",range_n,"_k"
                       ,range_k,"_Light_",j_global,"_",label,".RData\")")))
#eval(parse(text=paste0("save(arguments,label,workspace_directory,i_exp,file= \"temp_data_info_",label,".RData\")")))
eval(parse(text=paste0("save(arguments,label,workspace_directory,i_exp,file= \"temp_data_info_ADNI.RData\")")))

#CV Superlearner function application [NOT TESTED YET]
# CV_SL <- try(CV.SuperLearner(Y,
#                              X,
#                              V=10, family=gaussian(),
#                              SL.library=SL.library,
#                              method="method.NNLS",
#                              verbose = TRUE,
#                              control = list(saveFitLibrary = TRUE),
#                              cvControl = list(V=10), saveAll = TRUE));#,
#                              #parallel = 'multicore'));
# 
# eval(parse(text=paste0("CV_SL_",j_global,"_KO <- CV_SL")));
# 
# eval(parse(text=paste0("ifelse(exists(\"CV_SL_",j_global,"_KO\"),'OK',
#                        CV_SL_",j_global,"_KO <- 1)")))
# 
# eval(parse(text=paste0("save(Xnew,Ynew,CV_SL_",j_global,"_KO,k",j_global,",n",j_global,",file= \"",
#                        workspace_directory,"CBDA_CV_SL_M",M,"_miss",misValperc,"_n",range_n,"_k",range_k,"_",j_global,"_KO.RData\")")))
