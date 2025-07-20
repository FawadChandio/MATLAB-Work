function features = extractFeatures(timeSeriesData)
    % Example of feature extraction: mean, std, max, min
    features.mean = mean(timeSeriesData);
    features.std = std(timeSeriesData);
    features.max = max(timeSeriesData);
    features.min = min(timeSeriesData);
    features.range = features.max - features.min;
    features.trend = polyfit(1:length(timeSeriesData), timeSeriesData', 1);
end
