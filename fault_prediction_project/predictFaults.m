function results = predictFaults(models, data)
    % Simulate fault prediction
    disp('Predicting faults...');
    results = data > models.dummyModel;
end