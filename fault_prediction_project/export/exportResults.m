function exportResults(results, filePath)
    % Export results to a CSV file
    writetable(results, filePath);
    disp(['Results exported to ' filePath]);
end
