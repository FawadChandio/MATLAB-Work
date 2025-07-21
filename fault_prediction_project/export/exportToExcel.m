function exportToExcel(data, filename)
    writematrix(data, filename);
    disp(['Data exported to ', filename]);
end