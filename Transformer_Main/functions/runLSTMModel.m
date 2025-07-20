function [predictions, model] = runLSTMModel(trainingData, labels)
    % Example function to train and predict using LSTM
    layers = [
        sequenceInputLayer(1)
        lstmLayer(50, 'OutputMode', 'last')
        fullyConnectedLayer(1)
        regressionLayer];
    
    options = trainingOptions('adam', 'MaxEpochs', 100, 'GradientThreshold', 1, 'Verbose', false);
    model = trainNetwork(trainingData, labels, layers, options);
    
    predictions = predict(model, trainingData);
end
