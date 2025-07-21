function [predictions, model] = runCNNModel(trainingData, ~)
    % Example function to train and predict using CNN
    layers = [
        imageInputLayer([size(trainingData, 1), size(trainingData, 2), 1])
        convolution2dLayer(3, 8, 'Padding', 'same')
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer];
    
    options = trainingOptions('adam', 'MaxEpochs',
