function train_neural_network()
    % Load features and labels
    load('emg_features_labels.mat', 'features', 'labels');

    % Convert labels to cell array of character vectors
    labels = cellstr(labels);

    % Convert cell array of character vectors to categorical
    labels = categorical(labels);

    % Print sizes of features and labels
    disp(['Size of features: ', num2str(size(features))]);
    disp(['Size of labels: ', num2str(size(labels))]);

    % Define neural network architecture
    inputSize = size(features, 2);  % Number of features
    layers = [
        featureInputLayer(inputSize)
        fullyConnectedLayer(64)
        reluLayer
        fullyConnectedLayer(2)
        softmaxLayer
        classificationLayer
    ];

    % Specify training options
    options = trainingOptions('adam', ...
        'MaxEpochs', 10, ...
        'MiniBatchSize', 32, ...
        'ValidationData', {features, labels}, ...
        'ValidationFrequency', 5, ...
        'Plots', 'training-progress');

    % Train neural network
    net = trainNetwork(features, labels, layers, options);

    % Save trained network
    save('trained_network.mat', 'net');
    disp('Trained network saved to trained_network.mat');
end
