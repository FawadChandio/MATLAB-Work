function exportResults(results)
    % Export results to a file
    disp('Exporting results...');
    save('results.mat', 'results');
end