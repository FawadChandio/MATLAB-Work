function [sensorData, success] = parseSensorData(rawString)
    % Initialize output
    sensorData = table('Size', [1 10], ...
        'VariableTypes', repmat({'double'}, 1, 10), ...
        'VariableNames', {'h2', 'ch4', 'c2h6', 'c2h4', 'c2h2', 'co', 'co2', 'h2o', 'temperature', 'load'});
    success = false;
    
    try
        % Clean input
        cleanString = regexprep(rawString, '[^ -~]', '');
        pairs = split(cleanString, ',');
        
        % Parse each key-value pair
        for i = 1:length(pairs)
            kv = split(pairs{i}, ':');
            if numel(kv) == 2
                key = lower(strtrim(kv{1}));
                value = str2double(kv{2});
                
                switch key
                    case 'h2', sensorData.h2 = value;
                    case 'ch4', sensorData.ch4 = value;
                    case 'c2h6', sensorData.c2h6 = value;
                    case 'c2h4', sensorData.c2h4 = value;
                    case 'c2h2', sensorData.c2h2 = value;
                    case 'co', sensorData.co = value;
                    case 'co2', sensorData.co2 = value;
                    case 'h2o', sensorData.h2o = value;
                    case 'temp', sensorData.temperature = value;
                    case 'load', sensorData.load = value;
                end
            end
        end
        
        % Add timestamp
        sensorData.Time = datetime('now');
        success = true;
        
    catch
        sensorData = [];
    end
end