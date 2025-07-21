function saveModel(model, filePath)
    % Save the trained model to a .mat file
    save(filePath, 'model');
    disp(['Model saved to ' filePath]);
end
