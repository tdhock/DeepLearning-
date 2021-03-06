# libraries
library(data.table)
library(ggplot2)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


# functions
n_net_one_split <- function (x_mat, y_vec, step_size, max_epochs,
                            n_hidden_units, is_subtrain) {

    # split data
    x_sub <- x_mat[is_subtrain, ]
    x_vali <- x_mat[!is_subtrain, ]

    y_sub <- y_vec[is_subtrain]
    y_vali <- y_vec[!is_subtrain]
    y_tilde <- ifelse(y_vec == 1, 1, -1)
    y_sub_tilde <- ifelse(y_sub == 1, 1, -1)
    y_vali_tilde <- ifelse(y_vali == 1, 1, -1)
    
    # initialize weights
    weight_mat <- matrix(rnorm(ncol(x_mat)*n_hidden_units), nrow = ncol(x_mat), ncol = as.numeric(n_hidden_units))
    weight_vec <- vector(length = as.numeric(n_hidden_units))

    # lists for storing and returning
    weight_mat_list <- list()
    weight_vec_list <- list()
    accuracy_list <- list()
    loss_list <- list()
    
    for( epoch in 1:max_epochs ) {
        for( obs in 1:nrow(x_sub)) {
            #step in negative gradient for weight_mat and weight_vec
            hidden_units <-   x_sub[obs, ] %*% weight_mat
            predictions <- hidden_units %*% weight_vec
            
            gradient <- -as.numeric(y_sub_tilde[obs])*x_sub[obs, ] / as.numeric(1+exp((predictions)*y_sub_tilde[obs]))

            weight_mat = weight_mat - step_size * gradient
            weight_vec = weight_vec - step_size * gradient
            
            
        }
        # store weights for later
        weight_mat_list[[epoch]] <- weight_mat
        weight_vec_list[[epoch]] <- weight_vec
        
        # make a prediction and calc loss
        hidden_units <-   x_mat %*% weight_mat
        predictions <- hidden_units %*% weight_vec
        loss_values <-  log(1+exp(-y_tilde*predictions))
        
        # calc accuracy
        predictions <- ifelse(predictions > 0, 1, 0)
        accuracy_list[[epoch]] <- 1 - mean(predictions[!is_subtrain] == y_vali_tilde)
        
        # create data table for plotting
        loss_list[[epoch]] <- data.table(
            epoch,
            loss=loss_values,
            set=ifelse(is_subtrain, "train", "validation")
        )
        
    }

    return (list("loss" = loss_list, "weight_mats" = weight_mat_list, "weight_vecs" = weight_vec_list, "accuracy" = accuracy_list))
}

# start data analysis
#---------------------------------------------------------
spam_datatable <- data.table::fread("spam.data.txt")

x <- spam_datatable[, -58]
x_scale <- scale(x)

y <- spam_datatable[, 58]

is_train <- vector(mode = "logical", length = nrow(x))
is_train <- sample(c(TRUE, FALSE), nrow(x), replace = TRUE, prob = c(0.8, 0.2))


is_subtrain <- vector(mode = "logical", length = nrow(x[is_train]))
is_subtrain <- sample(c(TRUE,FALSE), nrow(x[is_train]), replace = TRUE, prob = c(0.6, 0.4))

# test parameters
max_epoch <- 100
h_layer <- 64
step_size <- 0.1

# run test
results <- n_net_one_split(x_scale[is_train,], y[is_train], step_size, max_epoch, h_layer, is_subtrain)

# analyze results
loss <- results[["loss"]]

best_epoch <- which.min(results[["accuracy"]])
best_weight_matrix <- results[["weight_mats"]][[best_epoch]]
best_weight_vec <- results[["weight_vecs"]][[best_epoch]]

best_epoch_run <- n_net_one_split(x_scale[is_train, ], y[is_train], step_size, best_epoch, h_layer, is_subtrain = TRUE)

best_hidden_units <-   x_scale[!is_train, ] %*% best_weight_matrix
best_predictions <- best_hidden_units %*% best_weight_vec

best_predictions <- ifelse(best_predictions > 0, 1, 0)

accuracy <- mean(best_predictions == y[!is_train])

baseline <- which.max( c(length(y[ ,y == 0]), length(y[ ,y == 1])) )
baseline_accuracy <- 1 - mean(baseline == y[!is_train])
