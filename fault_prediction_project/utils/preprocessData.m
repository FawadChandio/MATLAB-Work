function processedData = preprocessData(data)
    % Preprocess data (this could include filtering, normalizing, etc.)
    % Example: Normalize data to range [0,1]
    processedData = (data - min(data)) / (max(data) - min(data));
    disp('Data preprocessing completed.');
end
