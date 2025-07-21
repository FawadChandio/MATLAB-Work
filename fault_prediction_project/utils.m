function data = preprocessData(data)
    % Preprocess input data
    disp('Preprocessing data...');
    data = fillmissing(data, 'linear');
end