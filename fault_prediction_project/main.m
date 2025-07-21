% main.m

% Add paths for utils, cloud, and export functions
addpath('utils');
addpath('cloud');
addpath('export');
addpath('models');

% Load sensor data from file
data = loadDataFromFile('data/sensor_data.mat');

% Preprocess the data
processedData = preprocessData(data);

% Train models
models = trainModels(processedData);

% Predict faults using the trained models
faults = predictFaults(models, processedData);

% Display results (you can use UI or console-based here)
disp('Predicted Faults:');
disp(faults);

% Optionally save the model and results
saveModel(models, 'models/trained_model.mat');
exportResults(faults, 'results/fault_predictions.csv');

% Optionally upload data to cloud
uploadData('cloud_url', 'data/sensor_data.mat');
