function data = loadDataFromFile(filePath)
    % Load sensor data from the specified .mat file
    try
        data = load(filePath);
        disp('Data loaded successfully.');
    catch
        error('Error loading the data file.');
    end
end
