% Load dataset 
load('emg_features_labels.mat');

% Define the neural network architecture
hiddenLayerSize = 10;
net = feedforwardnet(hiddenLayerSize);

% Set training parameters
net.trainParam.epochs = 100;
net.trainParam.lr = 0.01;

% Train the neural network
net = train(net, X_train', y_train');

% Evaluate the trained network on the test set
y_pred = net(X_test');

% Calculate performance metrics (e.g., accuracy, MSE, etc.)
performance_metric = perform(net, y_test', y_pred);

% Display results
disp(['Performance metric: ', num2str(performance_metric)]);
