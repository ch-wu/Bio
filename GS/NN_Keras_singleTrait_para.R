# Build NN regressor, parallel. 
# activations : relu | elu | selu | hard_sigmoid | sigmoid | linear | softmax | softplus | softsign | tanh | exponential
# optimizer: adam | adamax | adadelta | adagrad | nadam | rmsprop 
Keras_singleTrait_para <- function(feed_set,
                                   batch_size=256, epochs=200,
                                   patience=NULL,
                                   modelIn=NULL,
                                   activation='relu',
                                   optimizer=optimizer_rmsprop(),
                                   include_env=TRUE,
                                   usePCinsteadSNP=FALSE,
                                   isScale=TRUE,
                                   isScaleSNP=TRUE) {
  library(dplyr)
  library(parallel)
  library(foreach)
  library(doParallel)
  
  #num_cg <- ncol(feed_set$train[[1]]$pheno)
  nam_ph <- colnames(feed_set[[1]][[1]][[1]][[1]][[2]])
  num_tt <- length(feed_set)
  num_cv <- length(feed_set[[1]][[1]])
  num_ph <- length(nam_ph)
  result <- list()
  
  for (p in 1:num_ph) {
    cores <- detectCores() - 2
    if (num_tt < cores) { cores = num_tt }
    cl <- makeCluster(cores)
    registerDoParallel(cl)
    tmp_tt <- foreach(t = 1:num_tt) %dopar% {
      library(magrittr)
      library(keras)
      library(dplyr)
      library(parallel)
      library(foreach)
      library(doParallel)
      # Test set
      if(isScale) {
        test__envi = scale(feed_set[[t]][[2]][[4]])
        test__phen = scale(as.matrix(feed_set[[t]][[2]][[2]][ , p]))
      } else {
        test__envi = feed_set[[t]][[2]][[4]]
        test__phen = as.matrix(feed_set[[t]][[2]][[2]][ , p])
      }
      if (!usePCinsteadSNP) {
        if (isScaleSNP) {
          test__geno = scale(feed_set[[t]][[2]][[1]], center = FALSE)
        } else {
          test__geno = feed_set[[t]][[2]][[1]]
        }
      } else {
        test__geno = feed_set[[t]][[2]][[3]][,grep("PC", colnames(feed_set[[t]][[2]][[3]]))] %>% as.numeric(as.character())
      }
      if (include_env) {
        x_test  = as.matrix(cbind(test__envi, test__geno))
      } else {
        x_test  = as.matrix(test__geno)
      }
      
      y_test  = as.matrix(test__phen)
      input_shape = ncol(x_test)
      
      # CV
      history_list <- list()
      #train_loss <- c()
      #train_mean_absolute_error <- c()
      test_loss <- c()
      test_mae <- c()
      test_cor <- c()
      test_prediction <- list()
      #loss_and_metrics_list <- list()
      #scores_list <- c()
      for (c in 1:num_cv) {
        if(isScale) {
          train_envi = scale(feed_set[[t]][[1]][[c]][[1]][[4]])
          train_phen = scale(as.matrix(feed_set[[t]][[1]][[c]][[1]][[2]][ , p]))
          valid_envi = scale(feed_set[[t]][[1]][[c]][[2]][[4]])
          valid_phen = scale(as.matrix(feed_set[[t]][[1]][[c]][[2]][[2]][ , p]))
        } else {
          train_envi = feed_set[[t]][[1]][[c]][[1]][[4]]
          train_phen = as.matrix(feed_set[[t]][[1]][[c]][[1]][[2]][ ,p])
          valid_envi = feed_set[[t]][[1]][[c]][[2]][[4]]
          valid_phen = as.matrix(feed_set[[t]][[1]][[c]][[2]][[2]][ ,p])
        }
        
        if (!usePCinsteadSNP) {
          if (isScaleSNP) {
            train_geno = scale(feed_set[[t]][[1]][[c]][[1]][[1]], center = FALSE)
            valid_geno = scale(feed_set[[t]][[1]][[c]][[2]][[1]], center = FALSE)
          } else {
            train_geno = feed_set[[t]][[1]][[c]][[1]][[1]]
            valid_geno = feed_set[[t]][[1]][[c]][[2]][[1]]
          }
        } else {
          train_geno = feed_set[[t]][[1]][[c]][[1]][[3]][,grep("PC", colnames(feed_set[[t]][[1]][[c]][[1]][[3]]))] %>% as.numeric(as.character())
          valid_geno = feed_set[[t]][[1]][[c]][[2]][[3]][,grep("PC", colnames(feed_set[[t]][[1]][[c]][[2]][[3]]))] %>% as.numeric(as.character())
        }
        
        if (include_env) {
          x_train = as.matrix(cbind(train_envi, train_geno))
          x_valid = as.matrix(cbind(valid_envi, valid_geno))
        } else {
          x_train = as.matrix(train_geno)
          x_valid = as.matrix(valid_geno)
        }
        y_train = as.matrix(train_phen)
        y_valid = as.matrix(valid_phen)
        
        # Define and Refresh NN for CV
        if (is.null(modelIn)) {
          if (usePCinsteadSNP) {
            model = keras_model_sequential() %>%
              layer_dense(units = 8, activation = activation, input_shape = input_shape) %>% 
              #layer_dropout(rate = 0.6) %>% 
              layer_dense(units = 4, activation = activation) %>%
              #layer_dropout(rate = 0.5) %>%
              ##layer_dense(units = 256, activation = activation) %>%
              #layer_dropout(rate = 0.4) %>%
              layer_dense(units = 2, activation = activation) %>%
              #layer_dropout(rate = 0.3) %>%
              layer_dense(units = 1)
          } else {
            model = keras_model_sequential() %>%
              layer_dense(units = 256, activation = activation, input_shape = input_shape) %>% 
              #layer_dropout(rate = 0.6) %>% 
              layer_dense(units = 128, activation = activation) %>%
              #layer_dropout(rate = 0.5) %>%
              ##layer_dense(units = 256, activation = activation) %>%
              #layer_dropout(rate = 0.4) %>%
              layer_dense(units = 32, activation = activation) %>%
              #layer_dropout(rate = 0.3) %>%
              layer_dense(units = 1)
          }
        } else {
          model = modelIn
        }
        
        model %>% compile(
          loss = "mse",
          #loss = "categorical_crossentropy",
          optimizer = optimizer_rmsprop(),
          metrics = list("mean_absolute_error")
        )
        
        model %>% summary()
        
        if (!is.null(patience)) {
          early_stop <- callback_early_stopping(monitor = "val_loss", patience = patience)
          history_list[[c]] <- model %>% fit(
            x_train, y_train,
            batch_size = batch_size,
            epochs = epochs,
            verbose = 0,
            validation_data = list(x_valid, y_valid),
            callbacks = list(early_stop)
          )
        } else {
          history_list[[c]] <- model %>% fit(
            x_train, y_train,
            batch_size = batch_size,
            epochs = epochs,
            verbose = 0,
            validation_data = list(x_valid, y_valid),
          )
        }
        #scores = model %>% evaluate(x_train, y_train, verbose = 0)
        #print(scores)
        #train_loss <- c(train_loss, scores[[1]])
        #train_mean_absolute_error <- c(train_mean_absolute_error, scores[[2]])
        c(loss, mae) %<-% (model %>% evaluate(x_test, y_test))
        test_loss <- c(test_loss, loss)
        test_mae <- c(test_mae, mae)
        test_prediction[[c]] <- model %>% predict(x_test)
        test_cor <- c(test_cor, cor(test_prediction[[c]], y_test))
        print(paste(c("loss: ", loss, ";  ", "MAE: ", mae, "Cor: ", test_cor[c]), collapse = ""))
      }
      list(history=history_list,
           loss=test_loss,
           MAE=test_mae,
           Cor=test_cor,
           test_prediction=list(y_pred=test_prediction, y_test=y_test))
    }
    stopCluster(cl)
    #save(list=c("tmp_tt"), file = paste(c("tmp_tt_p", p, ".RData"), collapse = ""))
    result_t_mx <- matrix(NA, num_tt, 5,
                          dimnames = list(seq(1:num_tt), c("MAE_min","MAE_mean","loss_min","loss_mean","Cor_mean")))
    nam_tt <- c()
    for (rtt in 1:num_tt) {
      result_t_mx[rtt, ] <- c(min(tmp_tt[[rtt]][[3]]), mean(tmp_tt[[rtt]][[3]]),
                              min(tmp_tt[[rtt]][[2]]), mean(tmp_tt[[rtt]][[2]]),
                              mean(tmp_tt[[rtt]][[4]]))
      nam_tt <- c(nam_tt, paste("random_tt_", rtt, sep = ""))
    }
    #nam_tt <- names(tmp_tt)
    tmp_tt[[length(tmp_tt)+1]] <- result_t_mx
    tmp_tt[[length(tmp_tt)+1]] <- list(MAE_min=(t.test(result_t_mx[, 1], alternative = "two.sided"))$p.value,
                                       MAE_mean=(t.test(result_t_mx[, 2], alternative = "two.sided"))$p.value,
                                       loss_min=(t.test(result_t_mx[, 3], alternative = "two.sided"))$p.value,
                                       loss_mean=(t.test(result_t_mx[, 4], alternative = "two.sided"))$p.value,
                                       Cor_mean=(t.test(result_t_mx[, 5], alternative = "two.sided"))$p.value)
    names(tmp_tt) <- c(nam_tt, "resultMLC", "p_value")
    result[[p]] <- tmp_tt
  }
  names(result) = nam_ph[1:num_ph]
  return(result)
}