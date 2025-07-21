function data = loadDataFromFile(filename)
    if exist(filename, 'file') ~= 2
        error('Data file not found.');
    end

    loaded = load(filename);  % Load .mat file

    % Create a struct with the expected data
    data.time = loaded.time;
    data.sensor1 = loaded.sensor1;
    data.sensor2 = loaded.sensor2;
    data.sensor3 = loaded.sensor3;
end
