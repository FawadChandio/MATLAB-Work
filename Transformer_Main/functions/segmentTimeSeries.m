function [segments, labels] = segmentTimeSeries(timeSeriesData, windowSize, overlap)
    numWindows = floor((length(timeSeriesData) - windowSize) / (windowSize - overlap)) + 1;
    segments = zeros(windowSize, numWindows);
    labels = zeros(numWindows, 1);
    
    for i = 1:numWindows
        startIdx = (i-1) * (windowSize - overlap) + 1;
        endIdx = startIdx + windowSize - 1;
        segments(:,i) = timeSeriesData(startIdx:endIdx);
        % Label assignment based on your criteria, e.g., for faults
        labels(i) = 1; % Example: Assign all as faulty for illustration
    end
end
