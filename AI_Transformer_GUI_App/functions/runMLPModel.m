function [predictions, model] = runMLPModel(trainingData, labels)
    % Example function to train and predict using MLP
    layers = [
        featureInputLayer(size(trainingData, 2))
        fullyConnectedLayer(100)
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer];
    
    options = trainingOptions('adam', 'MaxEpochs', 100, 'Verbose', false);
    model = trainNetwork(trainingData, labels, layers, options);
    
    predictions = predict(model, trainingData);
end
