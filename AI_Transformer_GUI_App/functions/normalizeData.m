function [normalizedData, minVals, maxVals] = normalizeData(rawData)
    % Assumes rawData is a numeric table or matrix
    if istable(rawData)
        rawData = table2array(rawData);
    end

    % Compute min and max
    minVals = min(rawData, [], 1);
    maxVals = max(rawData, [], 1);

    % Prevent division by zero
    rangeVals = maxVals - minVals;
    rangeVals(rangeVals == 0) = 1e-6;

    % Normalize
    normalizedData = (rawData - minVals) ./ rangeVals;
end
