function models = trainModels(data)
    % Train a machine learning model using the data
    disp('Training models...');
    models = struct(); % Placeholder for trained models
    % Example: Simple linear regression (you can replace it with your own model)
    models.regression = fitlm(data(:,1), data(:,2)); 
    disp('Models trained successfully.');
end
