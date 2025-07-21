function faults = predictFaults(models, data)
    % Predict faults based on the trained models
    disp('Predicting faults...');
    faults = predict(models.regression, data(:,1)); % Simple prediction example
end
