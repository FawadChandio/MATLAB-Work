function [prediction, confidence, diagnosisText] = predictFaultFromGases(app, gasValues)
    %PREDICTFAULTFROMGASES Predict transformer fault from gas values including CO
    %   Input: [H2, CH4, C2H6, C2H4, C2H2, CO, temperature, load]
    %
    % Outputs:
    %   prediction - Predicted fault type (e.g., 'PD', 'T1', 'D2')
    %   confidence - Confidence score (0-100%)
    %   diagnosisText - Detailed analysis report

    % Default outputs if model not trained
    prediction = 'Unknown';
    confidence = 0;
    diagnosisText = 'Model not trained or invalid input';

    % Validate input (8 values expected: 6 gases + temp + load)
    if numel(gasValues) ~= 8
        diagnosisText = 'Input must be [H2,CH4,C2H6,C2H4,C2H2,CO,temp,load]';
        return;
    end

    % Extract values for readability
    H2  = gasValues(1);
    CH4 = gasValues(2);
    C2H6 = gasValues(3);
    C2H4 = gasValues(4);
    C2H2 = gasValues(5);
    CO  = gasValues(6);
    temp = gasValues(7);
    load = gasValues(8);

    % Check if model exists
    modelType = app.ModelSelectionDropDown.Value;
    if ~isfield(app.TrainedModels, modelType)
        return;
    end

    try
        % Prepare input data (CO included if model supports it)
        X = [H2, CH4, C2H6, C2H4, C2H2, temp, load]; % Default (original format)
        
        % For models trained with CO (modify if needed)
        if isfield(app.TrainedModels.(modelType), 'UsesCO') && ...
           app.TrainedModels.(modelType).UsesCO
            X = [H2, CH4, C2H6, C2H4, C2H2, CO, temp, load];
        end

        % --- Model Prediction Logic (same as before) ---
        modelInfo = app.TrainedModels.(modelType);
        [YPred, scores] = classifyModel(app, modelType, modelInfo, X);
        % ----------------------------------------------

        % Get confidence and prediction
        [maxScore, ~] = max(scores);
        confidence = maxScore * 100;
        prediction = char(YPred);

        % Build detailed diagnosis
        diagnosisText = sprintf([...
            '=== AI Fault Diagnosis ===\n'...
            'Model: %s\nConfidence: %.1f%%\n\n'...
            'Gas Concentrations (ppm):\n'...
            '  H₂: %.2f\n  CH₄: %.2f\n  C₂H₆: %.2f\n'...
            '  C₂H₄: %.2f\n  C₂H₂: %.2f\n  CO: %.2f\n\n'...
            'Conditions:\n  Temp: %.1f°C\n  Load: %.1f%%'], ...
            modelType, confidence, H2, CH4, C2H6, C2H4, C2H2, CO, temp, load);

        % Add fault-specific recommendations
        switch prediction
            case 'Normal'
                diagnosisText = [diagnosisText '\n\nRecommendation: Normal operation'];
            case {'D1','D2'}
                diagnosisText = [diagnosisText '\n\n⚠️ WARNING: Electrical discharge detected'];
            case {'T1','T2','T3'}
                diagnosisText = [diagnosisText '\n\n🔥 Thermal fault suspected'];
            case 'PD'
                diagnosisText = [diagnosisText '\n\n⚡ Partial discharge activity'];
        end

    catch ME
        diagnosisText = sprintf('Prediction error:\n%s', ME.message);
    end
end

% Helper function for model-specific prediction
function [YPred, scores] = classifyModel(app, modelType, modelInfo, X)
    switch modelType
        case 'LSTM'
            XNorm = mapminmax('apply', X', modelInfo.normParams)';
            XTest = reshape(XNorm, [1, 1, numel(XNorm)]);
            [YPred, scores] = classify(modelInfo.net, XTest);
            
        case 'SVM'
            XStd = (X - app.SVM_Mean) ./ app.SVM_Std;
            [YPred, ~, ~, decisionValues] = predict(modelInfo.model, XStd);
            scores = 1./(1+exp(-decisionValues));
            scores = scores ./ sum(scores, 2);
            
        case 'CNN'
            XNorm = (X - modelInfo.min) ./ (modelInfo.max - modelInfo.min);
            XTest = permute(reshape(XNorm, [1, numel(XNorm), 1, 1]), [1 2 4 3]);
            [YPred, scores] = classify(modelInfo.net, XTest);
    end
end