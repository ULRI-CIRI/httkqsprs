#' Random Forest model for Clint from Dawson et al. 2021
#' 
#' This is a classification random forest model that predicts intrinsic hepatic clearance as occurring at one of three rates: slow, medium, or fast.
#'
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"ClintClass3Mod"

#' List of specific descriptors needed for the Clint and Fup QSPRS
#' 
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"Descriptors"

#' Random Forest model for Fup from Dawson et al. 2021
#' This is a regression random forest model that predicts the fraction unbound in plasma (Fup) for organic chemicals.
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"RF.fit"

#' The mean value for each bin in the Dawson 2021 Clint model
#' 
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"tmeanagtable"

#' The standard deviation of the values in each bin for the Dawson 2021 Clint model
#' 
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"tsdagtable"

#' The mean and standard deviation of the descriptors in the training set for the Dawson 2021 Fup Model
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"fup.msd"

#' The mean and standard deviation of the descriptors in the training set for the Dawson 2021 Clint Model
#' @docType data
#' @references
#' Dawson, J. S., Wambaugh, J. F., Isaacs, K. K., & Setzer, R. W. (2021). A random forest model for predicting intrinsic hepatic clearance of organic chemicals. Environmental Science & Technology, 55(8), 4979-4988.
"clint.msd"