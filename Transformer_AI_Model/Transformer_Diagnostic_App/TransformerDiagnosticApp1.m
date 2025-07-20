classdef TransformerDiagnosticApp1 < matlab.apps.AppBase
    % Main application class for Transformer Diagnostic System
    
    properties (Access = public)
        % Main window components
        UIFigure                matlab.ui.Figure
        TabGroup                matlab.ui.container.TabGroup
        TrainingFigure          % Handle for training progress figure
        TrainingAxes1           % Handle for first training axes
        TrainingAxes2           % Handle for second training axes
        SVM_Mean               double
        SVM_Std                double
        
            
        % Data Tab components
        DataTab                 matlab.ui.container.Tab
        DataGrid                matlab.ui.control.Table
        LoadDataButton          matlab.ui.control.Button
        ClearDataButton         matlab.ui.control.Button
        TransformerInfoPanel    matlab.ui.container.Panel
        DataFormatDropDown      matlab.ui.control.DropDown
        LiveDataButton         matlab.ui.control.Button % New button for live data
        
        % Visualization Tab components
        VisualizationTab        matlab.ui.container.Tab
        TimeSeriesAxes          matlab.ui.control.UIAxes
        GasConcentrationAxes    matlab.ui.control.UIAxes
        CorrelationHeatmapAxes  matlab.ui.control.UIAxes
        
        % Fault Detection Tab components
        FaultDetectionTab       matlab.ui.container.Tab
        DuvalTriangleAxes       matlab.ui.control.UIAxes
        RogersRatioPanel        matlab.ui.container.Panel
        KeyGasPanel             matlab.ui.container.Panel
        FaultTypeLabel          matlab.ui.control.Label
        
        % AI Analysis Tab components
        AITab                   matlab.ui.container.Tab
        ModelSelectionDropDown  matlab.ui.control.DropDown
        TrainModelButton        matlab.ui.control.Button
        PredictButton           matlab.ui.control.Button
        PerformanceAxes         matlab.ui.control.UIAxes
        FeatureImportanceAxes   matlab.ui.control.UIAxes
        AIDiagnosisTextArea     matlab.ui.control.TextArea
       % ConfusionMatrixAxes      matlab.ui.control.UIAxes
      
        % Cloud Integration Tab components
        CloudTab                matlab.ui.container.Tab
        CloudConnectButton      matlab.ui.control.Button
        SaveToCloudButton       matlab.ui.control.Button
        RealTimeDataSwitch      matlab.ui.control.ToggleSwitch
        CloudStatusLamp         matlab.ui.control.Lamp
        CloudURLEditField       matlab.ui.control.EditField
        APIKeyEditField         matlab.ui.control.EditField
        
        % Status bar components
        StatusText              matlab.ui.control.Label
        StatusLamp              matlab.ui.control.Lamp
        ProgressBar             matlab.ui.control.LinearGauge

        % Report
        ReportTab                matlab.ui.container.Tab
        GenerateReportButton    matlab.ui.control.Button
        ReportPreviewArea       matlab.ui.control.TextArea
           %Prediction
        ManualPredictButton     matlab.ui.control.Button

       LiveDataSourceDropDown     matlab.ui.control.DropDown
       LiveDataSourceLabel       matlab.ui.control.Label
       % Cloud UI Components
        ThingSpeakChannelEdit    matlab.ui.control.NumericEditField
        ThingSpeakWriteKeyEdit   matlab.ui.control.EditField
        ThingSpeakReadKeyEdit    matlab.ui.control.EditField
        SecondThingSpeakChannelEdit     matlab.ui.control.NumericEditField
        SecondThingSpeakReadKeyEdit     matlab.ui.control.EditField
        
        
    end
    
    properties (Access = private)
        TransformerData table              
        TrainedModels struct              
        CloudConnected logical = false      
        LastDataPath char                   
      %  PlotLimits struct                   % Stores plot axis limits
        CloudEndpoint = 'http://localhost:8000';
        APIKey char = 'sk-proj-t8E6ZiVlOHTUM_GIi3vTyFqfIsCnOqBbfZz3dllZYBmhxiUR'                    % API key storage
        TrainingProgress struct             
        SerialObj = []      
        
       % Clould intigration 

        ThingSpeakChannelID      double = 0  % Store as numeric
        ThingSpeakWriteAPIKey    char = ''
        ThingSpeakReadAPIKey     char = ''    
        %ThingSpeakTimer          timer 
        ThingSpeakTimer          timer = timer.empty
        %ThingSpeakTimer          matlab.ui.control.Timer
        SecondThingSpeakChannelID double = 0       % Secondary channel ID (initialize to 0)
        SecondThingSpeakReadAPIKey char = '' 
        
    end
    
     methods (Access = private)
       function openManualPredictor(app, ~, ~)
    % Check if model is trained
    modelType = app.ModelSelectionDropDown.Value;
    if ~isfield(app.TrainedModels, modelType)
        uialert(app.UIFigure, ['Please train the ' modelType ' model first'], 'Model Not Trained');
        return;
    end
    
    % Create input figure with adjusted size for additional gases
    fig = uifigure('Name', 'Gas Concentration Input', ...
                  'Position', [100 100 350 550], ... % Increased height
                  'Color', [0.96 0.96 0.98]);
    movegui(fig, 'center');
    
    % Default values for all gases (including CO2 and H2O)
    defaultValues = [50 120 66 80 5 360 25 15 75 85]; % [H2 CH4 C2H6 C2H4 C2H2 CO CO2 H2O Temp Load]
    
    % Gas data configuration - now includes all 8 gases
    gases = {
        'H2',   'Hydrogen';
        'CH4',  'Methane';
        'C2H6', 'Ethane'; 
        'C2H4', 'Ethylene';
        'C2H2', 'Acetylene';
        'CO',   'Carbon Monoxide';
        'CO2',  'Carbon Dioxide';
        'H2O',  'Water'
    };
    
    % Create input fields for all 8 gases
    editFields = gobjects(8,1); % Now 8 fields for gases
    for i = 1:8
        uilabel(fig, ...
               'Text', sprintf('%s (%s):', gases{i,1}, gases{i,2}), ...
               'Position', [20 500-35*i 120 22], ... % Adjusted vertical position
               'FontWeight', 'bold');
        
        editFields(i) = uieditfield(fig, 'numeric', ...
                                  'Position', [150 500-35*i 150 25], ...
                                  'Value', defaultValues(i));
                                 % 'Limits', [0 1000], ...
                                 % 'ValueDisplayFormat', '%.1f ppm');
    end
    
    % Temperature and Load (positioned below gases)
    uilabel(fig, 'Text', 'Temp (°C):', ...
           'Position', [20 500-35*9 120 22], ...
           'FontWeight', 'bold');
    
    tempField = uieditfield(fig, 'numeric', ...
                          'Position', [150 500-35*9 150 25], ...
                          'Value', defaultValues(9));
                          %Limits', [0 200]);
    
    uilabel(fig, 'Text', 'Load (%):', ...
           'Position', [20 500-35*10 120 22], ...
           'FontWeight', 'bold');
    
    loadField = uieditfield(fig, 'numeric', ...
                          'Position', [150 500-35*10 150 25], ...
                          'Value', defaultValues(10));
                          %'Limits', [0 100]);
    
    % Prediction button (still only uses original 6 gases for prediction)
    uibutton(fig, 'push', ...
            'Text', 'PREDICT', ...
            'Position', [150 30 150 35], ...
            'ButtonPushedFcn', @(btn,event) app.manualPredictCallback(fig, editFields, tempField, loadField), ...
            'BackgroundColor', [0.15 0.35 0.65], ...
            'FontColor', 'white');
    
    % Note about unused gases (optional)
    uilabel(fig, 'Text', 'Note: Limits remove in prediction', ...
           'Position', [20 10 310 20], ...
           'FontSize', 9, ...
           'FontAngle', 'italic', ...
           'HorizontalAlignment', 'center');
end

     function manualPredictCallback(app, fig, gasFields, tempField, loadField)
    try
        % Validate inputs
       % gasLimits = [0 1000; 0 500; 0 300; 0 400; 0 100; 0 1000]; 
       % for i = 1:6
          %  if gasFields(i).Value < gasLimits(i,1) || gasFields(i).Value > gasLimits(i,2)
            %    error('%s value out of range (%.1f-%.1f ppm)', ...
          %          gasFields(i).Tooltip, gasLimits(i,1), gasLimits(i,2));
           % end
       % end

        % Prepare input data [H2, CH4, C2H6, C2H4, C2H2, CO, CO2, H2O, Temp, Load]
      inputData = [
                        gasFields(1).Value, ... % H2
                        gasFields(2).Value, ... % CH4
                        gasFields(3).Value, ... % C2H6
                        gasFields(4).Value, ... % C2H4
                        gasFields(5).Value, ... % C2H2
                        gasFields(6).Value, ... % CO
                        gasFields(7).Value, ... % CO2
                        gasFields(8).Value, ... % H2O
                        tempField.Value, ...
                        loadField.Value ...
                    ];


        % Get prediction
       shortInput = inputData([1:5 9 10]);  % For model
            [prediction, confidence, reportText] = app.predictFaultFromGases(shortInput, inputData);  


        % Add gas concentrations section
                    gasReport = sprintf([
                'GAS CONCENTRATIONS:\n' ...
                'H2:   %.1f ppm\n' ...
                'CH4:  %.1f ppm\n' ...
                'C2H6: %.1f ppm\n' ...
                'C2H4: %.1f ppm\n' ...
                'C2H2: %.1f ppm\n' ...
                'CO:   %.1f ppm\n' ...
                'CO2:  %.1f ppm\n' ...
                'H2O:  %.1f ppm\n' ...
                'Temp: %.1f °C\n' ...
                'Load: %.1f %%\n\n'], ...
                inputData(1), inputData(2), inputData(3), inputData(4), inputData(5), ...
                inputData(6), inputData(7), inputData(8), ...
                inputData(9), inputData(10));

        % Combine full report
        fullReport = sprintf('%s%s', gasReport, reportText);

        % Update UI
        app.AIDiagnosisTextArea.Value = fullReport;
        app.FaultTypeLabel.Text = sprintf('%s (%.1f%%)', prediction, confidence);

        % Color setting
        if contains(prediction, 'Normal')
            app.FaultTypeLabel.FontColor = [0 0.5 0]; % Green
        else
            app.FaultTypeLabel.FontColor = [0.8 0 0]; % Red
        end

    catch ME
        app.AIDiagnosisTextArea.Value = sprintf('Prediction Error:\n%s', ME.message);
        app.FaultTypeLabel.Text = 'Prediction Failed';
        app.FaultTypeLabel.FontColor = 'red';
    end

    if isvalid(fig)
        uistack(fig, 'top');
    end
end


     function [prediction, confidence, report] = predictFaultFromGases(app, shortInput, fullInput)
    % Validate input
    if numel(shortInput) ~= 7
        error('Input must contain exactly 7 values');
    end
    
    modelType = app.ModelSelectionDropDown.Value;
    modelField = regexprep(modelType, '\s*\(Built-in\)', '');
    
    % Check model exists
    if ~isfield(app.TrainedModels, modelField)
        error('%s model not trained', modelType);
    end
    
    % Initialize outputs
    prediction = 'Unknown';
    confidence = 0;
    report = '';
    
    try
        switch modelType
            case 'SVM'
                % Standardize input
                X = (shortInput - app.SVM_Mean) ./ app.SVM_Std;
                
                % Predict
                [pred, ~, ~, decisionValues] = predict(app.TrainedModels.SVM.model, X);
                scores = 1./(1+exp(-decisionValues));
                confidence = max(scores) * 100;
                prediction = char(pred);
                
            case 'LSTM'
                % Normalize and format for LSTM
                XNorm = mapminmax('apply', shortInput', app.TrainedModels.LSTM.normParams)';
                XCell = {XNorm'}; % Convert to cell with column vector
                
                % Predict
                [pred, scores] = classify(app.TrainedModels.LSTM.net, XCell);
                confidence = max(scores) * 100;
                prediction = char(pred);
                
            case 'CNN'
                % Normalize and reshape for CNN
                XNorm = (shortInput - app.TrainedModels.CNN.min) ./ ...
                       (app.TrainedModels.CNN.max - app.TrainedModels.CNN.min);
                XCNN = reshape(XNorm, [1, numel(XNorm), 1, 1]);
                
                % Predict
                [pred, scores] = classify(app.TrainedModels.CNN.net, XCNN);
                confidence = max(scores) * 100;
                prediction = char(pred);
                
            otherwise
                error('Unsupported model type: %s', modelType);
        end
        
        % Generate detailed report
        report = generateDiagnosisReport(app, prediction, confidence, fullInput);
        
    catch ME
        prediction = 'Error';
        report = sprintf('Prediction failed:\n%s\n\nTechnical Details:\n%s', ...
            ME.message, getReport(ME, 'extended', 'hyperlinks', 'off'));
    end
end
   
     function report = generateDiagnosisReport(app, prediction, confidence, inputData)
    % Header
    report = sprintf('%s DIAGNOSIS REPORT\n\n', app.ModelSelectionDropDown.Value);
    report = [report sprintf('Predicted Fault: %s (%.1f%% confidence)\n', prediction, confidence)];
    
    % Gas concentrations
    gases = {'H2','CH4','C2H6','C2H4','C2H2','CO','CO2','H2O'};
    report = [report sprintf('\nGAS CONCENTRATIONS:\n')];
    for i = 1:8
        [normalRange, interpretation] = app.getGasInterpretation(gases{i}, inputData(i));
        report = [report sprintf('  %-5s: %6.1f ppm (Normal: %-10s %s)\n', ...
            gases{i}, inputData(i), normalRange, interpretation)];
    end
    
    % Operating conditions
    report = [report sprintf('\nOPERATING CONDITIONS:\n')];
    report = [report sprintf('  Temperature: %.1f°C\n', inputData(6))];
    report = [report sprintf('  Load:        %.1f%%\n', inputData(7))];
    
    % Recommendations
    report = [report sprintf('\nRECOMMENDED ACTIONS:\n')];
    switch prediction
        case 'Normal'
            report = [report '  - Continue regular monitoring'];
        case {'PD', 'D1', 'D2'}
            report = [report '  - Inspect for partial discharge\n' ...
                      '  - Check bushings and tap changers\n' ...
                      '  - Consider oil filtration'];
        case {'T1', 'T2'}
            report = [report '  - Check for overheating\n' ...
                      '  - Inspect cooling system\n' ...
                      '  - Monitor load conditions'];
        otherwise
            report = [report '  - Conduct comprehensive inspection'];
    end
    end


        function [normalRange, interpretation] = getGasInterpretation(~, gas, value)
    switch lower(gas)
        case 'h2'
            normalRange = '10-100 ppm';
            if value < 10 interpretation = 'Normal';
            elseif value < 100
                interpretation = 'Elevated';
            else
                interpretation = 'High (Possible PD)';
            end

        case 'ch4'
            normalRange = '10-50 ppm';
            if value < 10
                interpretation = 'Normal';
            elseif value < 50
                interpretation = 'Elevated';
            else
                interpretation = 'High (Possible T1/T2)';
            end

        case 'c2h6'
            normalRange = '5-30 ppm';
            if value < 5
                interpretation = 'Normal';
            elseif value < 30
                interpretation = 'Elevated';
            else
                interpretation = 'High (Possible T1)';
            end

        case 'c2h4'
            normalRange = '5-50 ppm';
            if value < 5
                interpretation = 'Normal';
            elseif value < 50
                interpretation = 'Elevated';
            else
                interpretation = 'High (Possible T2/T3)';
            end

        case 'c2h2'
            normalRange = '0-5 ppm';
            if value < 1
                interpretation = 'Normal';
            elseif value < 5
                interpretation = 'Trace (Monitor)';
            else
                interpretation = 'High (Possible D1/D2)';
            end

        % ==== NEW CASES ADDED BELOW ====

        case 'co'
            normalRange = '0-350 ppm';
            if value < 100
                interpretation = 'Normal';
            elseif value < 350
                interpretation = 'Elevated (Possible Aging)';
            else
                interpretation = 'High (Paper Decomposition)';
            end

        case 'co2'
            normalRange = '0-5000 ppm';
            if value < 2000
                interpretation = 'Normal';
            elseif value < 5000
                interpretation = 'Elevated (Monitor)';
            else
                interpretation = 'High (Thermal Stress on Insulation)';
            end

        case 'h2o'
            normalRange = '0-30 ppm';
            if value < 10
                interpretation = 'Normal';
            elseif value < 30
                interpretation = 'Elevated (Moisture Present)';
            else
                interpretation = 'High (Risk of Bubble Formation)';
            end

        otherwise
            normalRange = 'N/A';
            interpretation = 'N/A';
    end
end


        function updateStatus(app, message, color)
    % Update status bar with message and color
    try
        if isvalid(app.UIFigure) && isvalid(app.StatusText)
            app.StatusText.Text = message;
            app.StatusLamp.Color = color;
            drawnow;
        end
    catch ME
        % Silently fail if components are destroyed
        disp(['Status update failed: ' ME.message]);
    end
end
        function loadDataFromFile(app, ~, ~)
            % Load transformer data from file with improved file selection
            fileFormats = {
                '*.csv', 'CSV Files (*.csv)';
                '*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)';
                '*.mat', 'MAT Files (*.mat)';
                '*.*', 'All Files (*.*)'
                };
            
            [file, path] = uigetfile(...
                fileFormats,...
                'Select Transformer Data File',...
                app.LastDataPath,...
                'MultiSelect', 'off');
            
            if isequal(file, 0)
                app.updateStatus('File selection cancelled', 'yellow');
                return;
            end
            
            app.LastDataPath = path;
            app.updateStatus('Loading data...', 'yellow');
            app.ProgressBar.Value = 10;
            
            try
                fullPath = fullfile(path, file);
                [~, ~, ext] = fileparts(fullPath);
                
                % Load data based on file type
                switch lower(ext)
                    case '.csv'
                        opts = detectImportOptions(fullPath);
                        % Configure import options based on selected format
                        switch app.DataFormatDropDown.Value
                            case 'Standard DGA'
                                opts.VariableNames = {'H2','CH4','C2H6','C2H4','C2H2','Temperature','Load'};
                                opts.VariableTypes = repmat({'double'}, 1, 7);
                            case 'IEEE Format'
                                opts.VariableNames = {'Date','H2','CH4','C2H6','C2H4','C2H2','CO','CO2','Temperature','Load'};
                                opts.VariableTypes = {'datetime','double','double','double','double','double','double','double','double','double'};
                            case 'Custom'
                                % Use detected import options
                        end
                        data = readtable(fullPath, opts);
                        
                    case {'.xlsx', '.xls'}
                        data = readtable(fullPath);
                        
                    case '.mat'
                        loaded = load(fullPath);
                        if isfield(loaded, 'transformerData')
                            data = loaded.transformerData;
                        else
                            error('MAT file must contain a variable named "transformerData"');
                        end
                end
                
                % Standardize column names (case insensitive)
                data.Properties.VariableNames = lower(data.Properties.VariableNames);
                
                % Validate required columns
                requiredCols = {'h2','ch4','c2h6','c2h4','c2h2','temperature','load'};
                optionalCols = {'co','co2','h2o'};
                missingCols = setdiff(requiredCols, data.Properties.VariableNames);
                if ~isempty(missingCols)
                    error('Missing required columns: %s', strjoin(missingCols, ', '));
                end
                  % Set missing optional gases 
                for gas = optionalCols
                    if ~ismember(gas{1}, data.Properties.VariableNames)
                        data.(gas{1}) = nan(height(data), 1);
                    end
                end
                
                % Clean data - replace invalid values with median
                for col = requiredCols
                    colData = data.(col{1});
                    invalid = colData < 0 | isnan(colData);
                    if any(invalid)
                        medianVal = median(colData(~invalid), 'omitnan');
                        data.(col{1})(invalid) = medianVal;
                        app.updateStatus(sprintf('Replaced %d invalid values in %s', sum(invalid), col{1}), 'yellow');
                    end
                end
                
                % Calculate gas ratios if not present
                if ~ismember('ratio_ch4_h2', data.Properties.VariableNames)
                    data.ratio_ch4_h2 = data.ch4 ./ data.h2;
                end
                if ~ismember('ratio_c2h4_c2h6', data.Properties.VariableNames)
                    data.ratio_c2h4_c2h6 = data.c2h4 ./ data.c2h6;
                end
                if ~ismember('ratio_c2h2_c2h4', data.Properties.VariableNames)
                    data.ratio_c2h2_c2h4 = data.c2h2 ./ data.c2h4;
                end
                
                % Store data and update UI
                app.TransformerData = data;
                app.DataGrid.Data = data;
                
                % Update visualizations
                app.updateVisualizations();
                
                % Enable AI and cloud features now that we have data
                app.TrainModelButton.Enable = 'on';
                app.PredictButton.Enable = 'on';
                app.SaveToCloudButton.Enable = 'on';
                app.GenerateReportButton.Enable = 'on';
                
                app.ProgressBar.Value = 100;
                app.updateStatus(sprintf('Successfully loaded %d samples from %s', height(data), file), 'green');
                
            catch ME
                app.ProgressBar.Value = 0;
                app.updateStatus(sprintf('Error: %s', ME.message), 'red');
                uialert(app.UIFigure, ME.message, 'Data Loading Error');
            end
        end
        
        function clearData(app, ~, ~)
            % Clear all loaded data and reset visualizations
            app.TransformerData = table();
            app.DataGrid.Data = table();
            app.ReportPreviewArea.Value = 'Report preview will appear here after generation';
            
            % Clear plots
            cla(app.TimeSeriesAxes);
            cla(app.GasConcentrationAxes);
            cla(app.CorrelationHeatmapAxes);
            cla(app.DuvalTriangleAxes);
            cla(app.PerformanceAxes);
            cla(app.FeatureImportanceAxes);
            
            % Reset status
            app.FaultTypeLabel.Text = 'No fault detected';
            app.FaultTypeLabel.FontColor = 'black';
            app.AIDiagnosisTextArea.Value = '';
            
            % Clear trained models
            app.TrainedModels = struct();
            
            % Disable dependent features
            app.TrainModelButton.Enable = 'off';
            app.PredictButton.Enable = 'off';
            app.SaveToCloudButton.Enable = 'off';
            app.GenerateReportButton.Enable = 'off';
            
            app.updateStatus('Data cleared', 'green');
        end
    
       function connectLiveData(app, ~)
    % First check if UI is still valid
    if ~isvalid(app.UIFigure)
        return;
    end
    
    % Check if we should disconnect
    if contains(app.LiveDataButton.Text, 'Disconnect')
        app.disconnectLiveData();
        return;
    end
    
    try
        % Validate both channels
        if app.ThingSpeakChannelID == 0 || isempty(app.ThingSpeakReadAPIKey)
            error('Primary Cloud channel not configured');
        end
        if app.SecondThingSpeakChannelID == 0 || isempty(app.SecondThingSpeakReadAPIKey)
            error('Secondary Cloud channel not configured');
        end
        
        % Initialize data structure with all required variables
        app.TransformerData = table('Size', [0 11], ...
            'VariableTypes', {'double','double','double','double','double','double','double','double','double','double','datetime'}, ...
            'VariableNames', {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load','Time'});
        
        % Start 1-second polling
        app.startThingSpeakPolling();
        
        % Update UI if still valid
        if isvalid(app.UIFigure)
            app.LiveDataButton.Text = 'Disconnect Cloud';
            app.LiveDataButton.BackgroundColor = [0.85, 0.33, 0.1];
            app.CloudStatusLamp.Color = 'green';
            app.updateStatus('Live data streaming started (1s updates)', 'green');
            
            % Initialize training button state
            app.TrainModelButton.Enable = 'off';
            app.TrainModelButton.Text = 'Waiting for data...';
            app.TrainModelButton.FontColor = [0.5 0.5 0.5];
        end
        
    catch ME
        if isvalid(app.UIFigure)
            app.handleConnectionError(ME);
        end
    end
end
       
       function liveDataSourceChanged(app, ~)
    % Enable connect button when valid source is selected
    if ~strcmp(app.LiveDataSourceDropDown.Value, 'Select source')
        app.LiveDataButton.Enable = 'on';
        
        % Update button text based on selection
        if strcmp(app.LiveDataSourceDropDown.Value, 'Local Arduino')
            app.LiveDataButton.Text = 'Connect to Arduino';
        else
            app.LiveDataButton.Text = 'Connect to Cloud';
            % Open cloud dialog when selected
            if strcmp(app.LiveDataSourceDropDown.Value, 'Connect Cloud')
                app.openThingSpeakDialog();
            end
        end
    else
        app.LiveDataButton.Enable = 'off';
        app.LiveDataButton.Text = 'Connect';
    end
end      

       function updateSecondChannelID(app, src)
    % Callback for second channel ID edit field
    try
        app.SecondThingSpeakChannelID = src.Value;
        app.updateStatus(sprintf('Second channel ID set to %d', src.Value), 'blue');
    catch ME
        app.updateStatus(sprintf('Error setting channel ID: %s', ME.message), 'red');
    end
end

        function updateSecondReadKey(app, src)
            % Callback for second channel read key edit field
            try
                app.SecondThingSpeakReadAPIKey = src.Value;
                app.updateStatus('Second channel read key updated', 'blue');
            catch ME
                app.updateStatus(sprintf('Error setting read key: %s', ME.message), 'red');
            end
        end
        
       function disconnectLiveData(app)
    try
        % Clean up timer
        if ~isempty(app.ThingSpeakTimer) && isvalid(app.ThingSpeakTimer)
            stop(app.ThingSpeakTimer);
            delete(app.ThingSpeakTimer);
            app.ThingSpeakTimer = [];
        end
        
        % Only update UI if figure still exists
        if isvalid(app.UIFigure)
            app.LiveDataButton.Text = 'Connect to Cloud';
            app.LiveDataButton.BackgroundColor = [0.47, 0.67, 0.19];
            app.CloudStatusLamp.Color = 'red';
            app.updateStatus('Live data streaming stopped', 'yellow');
        end
        
    catch ME
        if isvalid(app.UIFigure)
            app.updateStatus(['Disconnect error: ' ME.message], 'red');
        end
    end
end
       function startThingSpeakPolling(app)
    % Stop any existing timer
    if ~isempty(app.ThingSpeakTimer) && isvalid(app.ThingSpeakTimer)
        stop(app.ThingSpeakTimer);
        delete(app.ThingSpeakTimer);
    end
    
    % Create new timer with 1-second interval
    app.ThingSpeakTimer = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period', 1, ... % 1 second interval
        'TimerFcn', @(~,~)app.fetchThingSpeakData(), ...
        'ErrorFcn', @(~,~)app.handleThingSpeakError(), ...
        'Name', 'ThingSpeakPolling');
    
    start(app.ThingSpeakTimer);
    app.updateStatus('Started 1-second polling of Cloud channels', 'green');
end     
       
       function checkTrainingReadiness(app)
    % Check if we have the minimum required data for training
    requiredVars = {'h2','ch4','c2h6','c2h4','c2h2','temperature','load'};
    
    if ~isvalid(app.UIFigure)
        return;  % Skip if figure is closed
    end
    
    if isempty(app.TransformerData)
        app.TrainModelButton.Enable = 'off';
        app.TrainModelButton.Tooltip = 'Load data first';
        return;
    end
    
    if ~all(ismember(requiredVars, app.TransformerData.Properties.VariableNames))
        missingVars = setdiff(requiredVars, app.TransformerData.Properties.VariableNames);
        app.TrainModelButton.Enable = 'off';
        app.TrainModelButton.Tooltip = sprintf('Missing data: %s', strjoin(missingVars, ', '));
        return;
    end
    
    % Check for NaN/inf values
    X = table2array(app.TransformerData(:, requiredVars));
    if any(~isfinite(X(:)))
        app.TrainModelButton.Enable = 'off';
        app.TrainModelButton.Tooltip = 'Data contains invalid values (NaN/Inf)';
        return;
    end
    
    % If we got here, enable the button
    app.TrainModelButton.Enable = 'on';
    app.TrainModelButton.Tooltip = 'Ready to train model';
    app.TrainModelButton.FontColor = [0 0 0]; % Black text
end     

       function readLiveData(app, src)
    try
        rawData = readline(src);
        [newData, success] = parseSensorData(rawData); % Use your function
        
        if success
            % Store data
            if isempty(app.TransformerData)
                app.TransformerData = newData;
            else
                app.TransformerData = [app.TransformerData; newData];
            end
            
            % Update UI
            app.updateDataDisplay();
            app.updateStatus(sprintf('Data received at %s', datestr(newData.Time)), 'green');
        end
        
    catch ME
        app.updateStatus(['Data read error: ' ME.message], 'red');
        app.disconnectLiveData();
    end
end
     
      function fetchThingSpeakData(app)
    persistent lastUpdateTime
    if isempty(lastUpdateTime)
        lastUpdateTime = datetime('now') - seconds(2);
    end
    
    try
        % --- Read Channel 1 (Gases) ---
        data1 = thingSpeakRead(app.ThingSpeakChannelID, ...
            'Fields', [1, 2, 3, 4, 5, 6, 7, 8], ... % H2, CH4, C2H6, C2H4, C2H2, CO, CO2, H2O
            'NumPoints', 1, ...
            'ReadKey', app.ThingSpeakReadAPIKey, ...
            'OutputFormat', 'table');
        
        % --- Read Channel 2 (Load & Temperature) ---
        data2 = thingSpeakRead(app.SecondThingSpeakChannelID, ...
            'Fields', [1, 2], ... % Field1: Load, Field2: Temperature
            'NumPoints', 1, ...
            'ReadKey', app.SecondThingSpeakReadAPIKey, ...
            'OutputFormat', 'table');
        
        % Create new data row with current timestamp
        newTime = datetime('now');
        newRow = {...
            data1.H2Hydrogen, ...
            data1.CH4Methane, ...
            data1.C2H6Ethane, ...
            data1.C2H4Ethylene, ...
            data1.C2H2Acetylene, ...
            data1.COCarbonMonoxide, ...
            data1.CO2CarbonDioxide, ...
            data1.H2OWater, ...
            data2.temperature, ... % Temperature
            data2.load, ... % Load
            newTime};
        
        % Update data table
        if isempty(app.TransformerData)
            app.TransformerData = cell2table(newRow, ...
                'VariableNames', {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load','Time'});
        else
            % Only add new data if timestamp is newer than last update
            if newTime > lastUpdateTime
                newData = cell2table(newRow, ...
                    'VariableNames', {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load','Time'});
                app.TransformerData = [app.TransformerData; newData];
                lastUpdateTime = newTime;
                
                % Update UI
                app.DataGrid.Data = app.TransformerData;
                app.updateVisualizations();
                
                % Auto-scroll to latest data
                scroll(app.DataGrid, 'bottom');
                
                % Update status with latest values
                statusText = sprintf('Updated: H2=%.1f, CH4=%.1f, C2H2=%.1f, Temp=%.1f°C, Load=%.1f%%', ...
                    data1.H2Hydrogen, data1.CH4Methane, data1.C2H2Acetylene, data2.temperature, data2.load);
                app.updateStatus(statusText, 'green');
                
                % Enable training button if we have required data
                app.checkTrainingReadiness();
            end
        end
        
    catch ME
        app.updateStatus(sprintf('Update error: %s', ME.message), 'red');
    end
end
      
       function updateDataDisplay(app)
    % Update table display
    app.DataGrid.Data = app.TransformerData;
    
    % Update visualizations
    app.updateVisualizations();

     % Check if we can enable training
     app.checkTrainingReadiness();
    
    % Enable analysis buttons if first data point
    if height(app.TransformerData) == 1
        app.TrainModelButton.Enable = 'on';
        app.PredictButton.Enable = 'on';
        app.GenerateReportButton.Enable = 'on';
    end
end

       function openThingSpeakDialog(app)
    % Create a dialog figure
    dlg = uifigure('Name', 'Cloud Configuration', ...
                  'Position', [100 100 400 400], ...
                  'Color', [0.96 0.96 0.98]);
    movegui(dlg, 'center');
    
    % Create input fields for primary channel
    uilabel(dlg, 'Text', 'Primary Channel Settings', ...
           'Position', [20 350 200 22], 'FontWeight', 'bold');
    
    uilabel(dlg, 'Text', 'Channel ID:', 'Position', [20 310 100 22]);
    channelEdit = uieditfield(dlg, 'numeric', 'Position', [150 310 200 22], ...
                            'Value', app.ThingSpeakChannelID);
    
    uilabel(dlg, 'Text', 'Write API Key:', 'Position', [20 270 100 22]);
    writeKeyEdit = uieditfield(dlg, 'text', 'Position', [150 270 200 22], ...
                             'Value', app.ThingSpeakWriteAPIKey);
    
    uilabel(dlg, 'Text', 'Read API Key:', 'Position', [20 230 100 22]);
    readKeyEdit = uieditfield(dlg, 'text', 'Position', [150 230 200 22], ...
                            'Value', app.ThingSpeakReadAPIKey);
    
    % Create input fields for secondary channel
    uilabel(dlg, 'Text', 'Secondary Channel Settings', ...
           'Position', [20 190 200 22], 'FontWeight', 'bold');
    
    uilabel(dlg, 'Text', 'Channel ID:', 'Position', [20 150 100 22]);
    secondChannelEdit = uieditfield(dlg, 'numeric', 'Position', [150 150 200 22], ...
                                  'Value', app.SecondThingSpeakChannelID);
    
    uilabel(dlg, 'Text', 'Read API Key:', 'Position', [20 110 100 22]);
    secondReadKeyEdit = uieditfield(dlg, 'text', 'Position', [150 110 200 22], ...
                                  'Value', app.SecondThingSpeakReadAPIKey);
    
    % Add save button
    uibutton(dlg, 'push', 'Text', 'Save Configuration', ...
            'Position', [150 40 150 35], ...
            'ButtonPushedFcn', @(btn,event) app.saveThingSpeakConfig(dlg, ...
                channelEdit, writeKeyEdit, readKeyEdit, ...
                secondChannelEdit, secondReadKeyEdit), ...
            'BackgroundColor', [0.15 0.35 0.65], ...
            'FontColor', 'white');
end       

      function saveThingSpeakConfig(app, dlg, channelEdit, writeKeyEdit, readKeyEdit, ...
                            secondChannelEdit, secondReadKeyEdit)
    % Save the configuration from the dialog
    try
        app.ThingSpeakChannelID = channelEdit.Value;
        app.ThingSpeakWriteAPIKey = writeKeyEdit.Value;
        app.ThingSpeakReadAPIKey = readKeyEdit.Value;
        app.SecondThingSpeakChannelID = secondChannelEdit.Value;
        app.SecondThingSpeakReadAPIKey = secondReadKeyEdit.Value;
        
        % Update the edit fields in the main CloudTab
        app.ThingSpeakChannelEdit.Value = channelEdit.Value;
        app.ThingSpeakWriteKeyEdit.Value = writeKeyEdit.Value;
        app.ThingSpeakReadKeyEdit.Value = readKeyEdit.Value;
        app.SecondThingSpeakChannelEdit.Value = secondChannelEdit.Value;
        app.SecondThingSpeakReadKeyEdit.Value = secondReadKeyEdit.Value;
        
        app.updateStatus('Cloud configuration saved', 'green');
        delete(dlg);
    catch ME
        app.updateStatus(['Error saving config: ' ME.message], 'red');
    end
end       

      function generateReport(app, ~, ~)
    app.updateStatus('Starting report generation...', [0 0.45 0.74]);
    app.ReportPreviewArea.Value = 'Initializing report generation...';
    drawnow;

    try
        fig = figure('Visible', 'off', 'Units', 'inches', ...
                     'Position', [0 0 8.5 11], 'Color', 'w', ...
                     'PaperPositionMode', 'auto');

        %% === UPDATED SECTION POSITIONS ===
        headerPos   = [0.1 0.89 0.8 0.05];
        statusPos   = [0.1 0.80 0.8 0.08];
        faultPos    = [0.1 0.70 0.8 0.08];
        gasPos      = [0.1 0.52 0.8 0.16];  % taller for gas list
        aiDiagPos   = [0.7 0.37 0.8 0.12];  % extra space
        perfPos     = [0.1 0.24 0.8 0.10];
        footerPos   = [0.1 0.02 0.8 0.05];

        %% === 1. HEADER ===
        headerAx = axes(fig, 'Position', headerPos, 'Visible', 'off');
        text(headerAx, 0.5, 0.5, 'TRANSFORMER DIAGNOSTIC REPORT', ...
             'FontSize', 18, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'Color', [0 0.45 0.74]);
        line(headerAx, [0 1], [0.1 0.1], 'Color', [0 0.45 0.74], 'LineWidth', 2);

        %% === 2. SYSTEM STATUS ===
        sectionAx = axes(fig, 'Position', statusPos, 'Visible', 'off');
        text(sectionAx, 0, 0.9, '1. SYSTEM STATUS', ...
             'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

        cloudStatus = 'Offline';
        if isprop(app, 'CloudConnected') && app.CloudConnected
            cloudStatus = 'Connected';
        end

        overviewText = {
            sprintf('• Generated: %s', datestr(now, 'dd-mmm-yyyy HH:MM'));
            sprintf('• Model Used: %s', app.ModelSelectionDropDown.Value);
            sprintf('• Cloud Status: %s', cloudStatus)
        };
        text(sectionAx, 0, 0.4, overviewText, 'FontSize', 11, 'VerticalAlignment', 'top');

        %% === 3. FAULT ANALYSIS ===
        sectionAx = axes(fig, 'Position', faultPos, 'Visible', 'off');
        text(sectionAx, 0, 0.8, '2. FAULT ANALYSIS', ...
             'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

        faultText = '• No faults detected';
        if isprop(app, 'FaultTypeLabel') && ~isempty(app.FaultTypeLabel.Text)
            faultText = ['• Detected: ' app.FaultTypeLabel.Text];
        end
        text(sectionAx, 0, 0.5, faultText, 'FontSize', 11, 'VerticalAlignment', 'top');

        %% === 4. GAS ANALYSIS ===
        sectionAx = axes(fig, 'Position', gasPos, 'Visible', 'off');
        text(sectionAx, 0, 0.9, '3. GAS ANALYSIS (ppm)', ...
             'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

        if ~isempty(app.TransformerData)
            gases = {
                'H₂',   'Hydrogen';
                'CH₄',  'Methane';
                'C₂H₆', 'Ethane';
                'C₂H₄', 'Ethylene';
                'C₂H₂', 'Acetylene';
                'CO',   'Carbon Monoxide';
                'CO₂',  'Carbon Dioxide';
                'H₂O',  'Water'
            };
            vars = {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o'};
            validVars = vars(ismember(vars, app.TransformerData.Properties.VariableNames));
            gasText = {};

            for i = 1:length(vars)
                gasName = gases{i,1};
                if ismember(vars{i}, validVars)
                    val = app.TransformerData.(vars{i})(end);
                    gasText{end+1} = sprintf('%-6s: %6.2f ppm', gasName, val);
                else
                    gasText{end+1} = sprintf('%-6s: %6s ppm', gasName, 'N/A');
                end
            end

            gasText{end+1} = '';
           % gasText{end+1} = 'Note: Analysis uses H₂, CH₄, C₂H₆, C₂H₄, C₂H₂, CO';

            text(sectionAx, 0, 0.4, gasText, ...
                 'FontSize', 11, 'FontName', 'FixedWidth', 'VerticalAlignment', 'top');
        else
            text(sectionAx, 0, 0.5, 'No gas data available', 'FontSize', 11, 'VerticalAlignment', 'top');
        end

        %% === 5. AI DIAGNOSIS ===
        sectionAx = axes(fig, 'Position', aiDiagPos, 'Visible', 'off');
        text(sectionAx, 0, 0.8, '4. AI DIAGNOSIS', ...
             'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

        if ~isempty(app.AIDiagnosisTextArea.Value)
            diagnosisText = strrep(app.AIDiagnosisTextArea.Value, '\n', newline);
            text(sectionAx, 0, 0.4, diagnosisText, 'FontSize', 11, 'VerticalAlignment', 'top');
        else
            text(sectionAx, 0, 0.5, 'No AI diagnosis available', 'FontSize', 11, 'VerticalAlignment', 'top');
        end

        %% === 6. MODEL PERFORMANCE ===
        sectionAx = axes(fig, 'Position', perfPos, 'Visible', 'off');
        text(sectionAx, 0, 0.9, '5. MODEL PERFORMANCE', ...
             'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

        modelKey = regexprep(app.ModelSelectionDropDown.Value, '\s*\(Built-in\)', '');
        if isfield(app.TrainedModels, modelKey)
            model = app.TrainedModels.(modelKey);
            perfText = {
                sprintf('Model Type: %s', app.ModelSelectionDropDown.Value);
                sprintf('Validation Accuracy: %.1f%%', model.Accuracy * 100);
                sprintf('Training Date: %s', datestr(now, 'dd-mmm-yyyy'))
            };
            text(sectionAx, 0, 0.5, perfText, 'FontSize', 11, 'VerticalAlignment', 'top');
        else
            text(sectionAx, 0, 0.5, 'No trained model available', 'FontSize', 11, 'VerticalAlignment', 'top');
        end

        %% === FOOTER ===
        footerAx = axes(fig, 'Position', footerPos, 'Visible', 'off');
        text(footerAx, 0.5, 0.5, 'Confidential - Transformer Diagnostics System', ...
             'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);

        %% === EXPORT TO PDF ===
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        reportFile = fullfile(pwd, ['Transformer_Report_' timestamp '.pdf']);
        exportgraphics(fig, reportFile, 'ContentType', 'vector', 'Resolution', 300);
        close(fig);

        %% === OPEN PDF ===
        app.updateStatus('Report generated - opening...', 'green');
        app.ReportPreviewArea.Value = sprintf('REPORT SUCCESSFUL\n\nFile: %s\nLocation: %s', ...
                                               ['Transformer_Report_' timestamp '.pdf'], pwd);

        if ispc
            system(['start "" "' reportFile '"']);
        else
            web(reportFile, '-browser');
        end

    catch ME
        if exist('fig', 'var') && ishandle(fig)
            close(fig);
        end
        app.updateStatus('Report generation failed', 'red');
        app.ReportPreviewArea.Value = sprintf('Error: %s\nLine: %d', ...
                                               ME.message, ME.stack(1).line);
    end
end


       function updateDuvalTriangle(app)
            % Update Duval triangle visualization
            data = app.TransformerData;
            
            if isempty(data) || ~all(ismember({'h2','ch4','c2h2'}, data.Properties.VariableNames))
                return;
            end
            
            % Use latest sample
            sample = data(end, :);
            total = sample.h2 + sample.ch4 + sample.c2h2;
            
            if total == 0
                app.FaultTypeLabel.Text = 'Insufficient gas data for analysis';
                app.FaultTypeLabel.FontColor = 'black';
                cla(app.DuvalTriangleAxes);
                title(app.DuvalTriangleAxes, 'Duval Triangle Analysis');
                return;
            end
            
            p_H2 = (sample.h2 / total) * 100;
            p_CH4 = (sample.ch4 / total) * 100;
            p_C2H2 = (sample.c2h2 / total) * 100;
            
            % Convert to triangle coordinates
            x = p_CH4 + p_C2H2 * cosd(60);
            y = p_C2H2 * sind(60);
            
            % Plot triangle
            cla(app.DuvalTriangleAxes);
            hold(app.DuvalTriangleAxes, 'on');
            
            % Triangle outline
            plot(app.DuvalTriangleAxes, [0 100 50 0], [0 0 100*sind(60) 0], 'k-', 'LineWidth', 2);
            
            % Fault zones with transparency
            patch(app.DuvalTriangleAxes, [0 50 0], [0 50*sind(60) 0], [1 0.8 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none'); % PD zone
            patch(app.DuvalTriangleAxes, [50 100 50], [0 0 50*sind(60)], [0.8 1 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none'); % T zone
            patch(app.DuvalTriangleAxes, [0 50 25], [50*sind(60) 50*sind(60) 100*sind(60)], [0.8 0.8 1], 'FaceAlpha', 0.3, 'EdgeColor', 'none'); % D zone
            
            % Zone labels
            text(app.DuvalTriangleAxes, 15, 15, 'PD', 'FontWeight', 'bold', 'Color', 'r', 'FontSize', 10);
            text(app.DuvalTriangleAxes, 65, 15, 'T1/T2', 'FontWeight', 'bold', 'Color', 'g', 'FontSize', 10);
            text(app.DuvalTriangleAxes, 25, 70, 'D1/D2', 'FontWeight', 'bold', 'Color', 'b', 'FontSize', 10);
            
            % Plot sample point
            plot(app.DuvalTriangleAxes, x, y, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
            
            % Determine fault type with more detailed thresholds
            if p_C2H2 > 23 % More precise threshold for discharge faults
                if p_CH4 < 23
                    faultType = 'D1 (Partial Discharge)';
                    color = [0 0 0.8]; % Dark blue
                elseif p_CH4 < 40
                    faultType = 'D2 (Discharge of High Energy)';
                    color = [0.2 0.2 1]; % Medium blue
                else
                    faultType = 'D2 (Discharge of Low Energy)';
                    color = [0.4 0.4 1]; % Light blue
                end
            elseif p_CH4 > 98
                faultType = 'T3 (Thermal >700°C)';
                color = [0 0.5 0]; % Dark green
            elseif p_CH4 > 50
                if p_H2 < 15
                    faultType = 'T2 (Thermal 700°C < T ≤ 700°C)';
                    color = [0 0.7 0]; % Medium green
                else
                    faultType = 'T2 (Thermal with H2)';
                    color = [0.2 0.8 0.2]; % Light green
                end
            elseif p_CH4 > 25
                faultType = 'T1 (Thermal <300°C)';
                color = [0.93 0.69 0.13]; % Orange
            elseif p_H2 > 98
                faultType = 'PD (Partial Discharge)';
                color = [0.8 0 0]; % Dark red
            elseif p_H2 > 50
                faultType = 'PD (Partial Discharge with CH4)';
                color = [1 0.2 0.2]; % Medium red
            else
                faultType = 'Normal Operation';
                color = 'black';
            end
            
            app.FaultTypeLabel.Text = ['Detected Fault: ' faultType];
            app.FaultTypeLabel.FontColor = color;
            app.FaultTypeLabel.FontSize = 16;
            
            % Add more detailed information
            infoText = sprintf(['Gas Ratios:\n' ...
                               '  H2: %.1f%%\n' ...
                               '  CH4: %.1f%%\n' ...
                               '  C2H2: %.1f%%\n\n' ...
                               'Coordinates:\n' ...
                               '  X: %.1f\n' ...
                               '  Y: %.1f'], ...
                               p_H2, p_CH4, p_C2H2, x, y);
            
            text(app.DuvalTriangleAxes, 600, 200, infoText, ...
                'FontSize', 10, 'VerticalAlignment', 'top');
            
            hold(app.DuvalTriangleAxes, 'off');
            axis(app.DuvalTriangleAxes, 'equal');
            axis(app.DuvalTriangleAxes, 'off');
            title(app.DuvalTriangleAxes, 'Duval Triangle Analysis', 'FontSize', 12);
        end
        
        function updateCorrelationHeatmap(app)
                data = app.TransformerData;
                
                if isempty(data)
                    cla(app.CorrelationHeatmapAxes);
                    title(app.CorrelationHeatmapAxes, 'No data available');
                    return;
                end
                
                % All possible variables we might want to show
                allVars = {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load'};
                prettyNames = {'H₂','CH₄','C₂H₆','C₂H₄','C₂H₂','CO','CO₂','H₂O','Temp','Load'};
                
                % Find which variables actually exist in the data
                availableVars = allVars(ismember(allVars, data.Properties.VariableNames));
                displayNames = prettyNames(ismember(allVars, availableVars));
                
                if length(availableVars) < 2
                    cla(app.CorrelationHeatmapAxes);
                    title(app.CorrelationHeatmapAxes, 'Need at least 2 variables');
                    return;
                end
                
                % Extract data and handle missing values
                corrData = data(:, availableVars);
                dataArray = table2array(corrData);
                
                % Check for constant columns (will cause NaN in correlation)
                constCols = var(dataArray, 0, 1) == 0;
                if any(constCols)
                    % Remove constant columns
                    dataArray(:, constCols) = [];
                    availableVars(constCols) = [];
                    displayNames(constCols) = [];
                    
                    if length(availableVars) < 2
                        cla(app.CorrelationHeatmapAxes);
                        title(app.CorrelationHeatmapAxes, 'Not enough varying variables');
                        return;
                    end
                end
                
                % Calculate correlation with pairwise complete observations
                corrMatrix = corr(dataArray, 'Rows', 'pairwise');
                
                % Handle any remaining NaN values (if any pairs have no complete observations)
                if any(isnan(corrMatrix(:)))
                    % Replace NaN with 0 and indicate missing correlations
                    corrMatrix(isnan(corrMatrix)) = 0;
                    warning('Some correlations could not be computed (insufficient data)');
                end
                
                % Create heatmap
                cla(app.CorrelationHeatmapAxes);
                imagesc(app.CorrelationHeatmapAxes, corrMatrix);
                colorbar(app.CorrelationHeatmapAxes);
                
                % Add correlation values (only if not NaN)
                [n, m] = size(corrMatrix);
               for i = 1:n
                            for j = 1:m
                                text(app.CorrelationHeatmapAxes, j, i, sprintf('%.2f', corrMatrix(i,j)),...
                                    'HorizontalAlignment', 'center', 'Color', 'w');
                         end
                     end
                
                % Configure axes
                app.CorrelationHeatmapAxes.XTick = 1:length(availableVars);
                app.CorrelationHeatmapAxes.XTickLabel = displayNames;
                app.CorrelationHeatmapAxes.XTickLabelRotation = 45;
                app.CorrelationHeatmapAxes.YTick = 1:length(availableVars);
                app.CorrelationHeatmapAxes.YTickLabel = displayNames;
                
                title(app.CorrelationHeatmapAxes, 'Feature Correlation Matrix');
                clim(app.CorrelationHeatmapAxes, [-1 1]); % Fix color scale from -1 to 1
            end
                 
        function updateVisualizations(app)
    % Update all visualizations with current data
    if isempty(app.TransformerData)
        return;
    end
    
    data = app.TransformerData;
    
    % Time series plot
    cla(app.TimeSeriesAxes);
    if ismember('temperature', data.Properties.VariableNames)
        plot(app.TimeSeriesAxes, data.temperature, 'b-', 'LineWidth', 1.5);
        hold(app.TimeSeriesAxes, 'on');
        plot(app.TimeSeriesAxes, data.load, 'r-', 'LineWidth', 1.5);
        hold(app.TimeSeriesAxes, 'off');
        title(app.TimeSeriesAxes, 'Temperature and Load Over Time');
        legend(app.TimeSeriesAxes, {'Temperature', 'Load'});
        grid(app.TimeSeriesAxes, 'on');
    end
    
    % Gas Concentration Plot - Now using our new function
    app.updateGasConcentrationPlot();
    
    % Correlation heatmap
    app.updateCorrelationHeatmap();
    
    % Duval triangle
    app.updateDuvalTriangle();
end
       
       function updateGasConcentrationPlot(app)
    % Clear previous plot
    cla(app.GasConcentrationAxes);
    
    if isempty(app.TransformerData)
        return;
    end
    
    data = app.TransformerData;
    
    % Define all gases with their properties
    gases = {
        'h2',   'H₂',   [0 0.4470 0.7410];    % Hydrogen
        'ch4',  'CH₄',  [0.8500 0.3250 0.0980]; % Methane
        'c2h6', 'C₂H₆', [0.9290 0.6940 0.1250]; % Ethane
        'c2h4', 'C₂H₄', [0.4940 0.1840 0.5560]; % Ethylene
        'c2h2', 'C₂H₂', [0.4660 0.6740 0.1880]; % Acetylene
        'co',   'CO',   [0.3010 0.7450 0.9330]; % Carbon Monoxide
        'co2',  'CO₂',  [0.6350 0.0780 0.1840]; % Carbon Dioxide
        'h2o',  'H₂O',  [0.25 0.25 0.25]       % Water
    };
    
    % Prepare for plotting
    hold(app.GasConcentrationAxes, 'on');
    lineHandles = gobjects(size(gases,1),1);
    legendEntries = {};
    
    % Plot each gas with automatic scaling
    for i = 1:size(gases,1)
        gasVar = gases{i,1};
        gasName = gases{i,2};
        gasColor = gases{i,3};
        
        if ismember(gasVar, data.Properties.VariableNames)
            gasData = data.(gasVar);
            validIdx = isfinite(gasData);
            
            if any(validIdx)
                % Apply scaling for high concentration gases
                if strcmp(gasVar, 'co2')
                    scaledData = gasData / 50;  
                elseif strcmp(gasVar, 'co')
                    scaledData = gasData / 10;  
                else
                    scaledData = gasData;       % No scaling for others
                end
                
                lineHandles(i) = plot(app.GasConcentrationAxes, ...
                    find(validIdx), scaledData(validIdx), ...
                    'Color', gasColor, ...
                    'LineWidth', 2, ...
                    'Marker', '.', ...
                    'MarkerSize', 10);
                legendEntries{end+1} = gasName;
            end
        end
    end
    hold(app.GasConcentrationAxes, 'off');
    
    % Configure axes
    title(app.GasConcentrationAxes, 'Dissolved Gas Concentrations');
    ylabel(app.GasConcentrationAxes, 'Concentration (ppm)');
    xlabel(app.GasConcentrationAxes, 'Sample Index');
    grid(app.GasConcentrationAxes, 'on');
    
    % Set y-axis limits to show all data clearly
    ylim(app.GasConcentrationAxes, [0 100]);
    
    % Add legend
    validHandles = isgraphics(lineHandles);
    if any(validHandles)
        legend(app.GasConcentrationAxes, lineHandles(validHandles), legendEntries, ...
            'Location', 'northeastoutside', 'FontSize', 8);
    end
end       

       function trainModel(app, ~, ~)
     % First verify we have valid data
        app.checkTrainingReadiness();
        if strcmp(app.TrainModelButton.Enable, 'off')
            uialert(app.UIFigure, app.TrainModelButton.Tooltip, 'Training Error');
            return;
        end
        
        % Rest of your training code...
        modelType = app.ModelSelectionDropDown.Value;
        data = app.TransformerData;
        
        app.updateStatus(['Training ' modelType ' model...'], 'yellow');
        app.ProgressBar.Value = 20;
        
        
        try
            % Prepare data - extract relevant features (still using original 7 features)
            X = table2array(data(:, {'h2','ch4','c2h6','c2h4','c2h2','temperature','load'}));
            
            % Check for invalid values
            if any(~isfinite(X(:)))
                error('Data contains NaN or Inf values. Please clean your data first.');
            end
            
            % Create synthetic fault labels
            y = ones(size(X,1),1); % Default to normal operation
            faultClasses = {'Normal', 'PD', 'T1', 'T2', 'D1', 'D2'};
            
            % Label generation logic based on gas ratios
            for i = 1:size(X,1)
                sample = X(i,:);
                total = sum(sample([1,2,5])); % H2 + CH4 + C2H2
                
                if total > 0
                    p_H2 = (sample(1)/total)*100;
                    p_CH4 = (sample(2)/total)*100;
                    p_C2H2 = (sample(5)/total)*100;
                    
                    if p_C2H2 > 23
                        y(i) = 5 + (p_CH4 >= 23); % D1 or D2
                    elseif p_CH4 > 50
                        y(i) = 3 + (p_H2 < 20); % T1 or T2
                    elseif p_H2 > 50
                        y(i) = 2; % PD
                    end
                end
            end
            
            % Convert to categorical
            y_categorical = categorical(y, 1:6, faultClasses);
            
            % Split data into training and validation
            cv = cvpartition(y_categorical, 'HoldOut', 0.2);
            XTrain = X(cv.training,:);
            yTrain = y_categorical(cv.training);
            XVal = X(cv.test,:);
            yVal = y_categorical(cv.test);
            
            % Initialize training progress tracking
            app.TrainingProgress = struct(...
                'Epoch', [], ...
                'TrainingAccuracy', [], ...
                'ValidationAccuracy', [], ...
                'TrainingLoss', [], ...
                'ValidationLoss', []);
            
            % Initialize model storage if needed
            if ~isfield(app, 'TrainedModels') || isempty(app.TrainedModels)
                app.TrainedModels = struct();
            end
            
            % Clean up any existing training figure
            if isfield(app, 'TrainingFigure') && isvalid(app.TrainingFigure)
                close(app.TrainingFigure);
            end
            
            % Model-specific training
            switch modelType
                            case 'LSTM'
                        % Normalize data to [0,1] range
                        [XTrainNorm, normParams] = mapminmax(XTrain', 0, 1);
                        XTrainNorm = XTrainNorm'; % XTrainNorm is [numObservations x numFeatures] (e.g., 100 x 7)
        
                        XValNorm = mapminmax('apply', XVal', normParams)'; % XValNorm is [numObservations x numFeatures]
        
                        % Convert to Nx1 cell array of (numFeatures x 1) sequences (column vectors)
                        % Each cell should contain a [numFeatures x 1] vector
                        numObservationsTrain = size(XTrainNorm, 1);
                        XTrainCell = cell(numObservationsTrain, 1);
                        for i = 1:numObservationsTrain
                            XTrainCell{i} = XTrainNorm(i, :)'; % Transpose to make it a COLUMN vector (7x1)
                        end
        
                        numObservationsVal = size(XValNorm, 1);
                        XValCell = cell(numObservationsVal, 1);
                        for i = 1:numObservationsVal
                            XValCell{i} = XValNorm(i, :)'; % Transpose to make it a COLUMN vector (7x1)
                        end
        
                        % Define LSTM architecture
                        numFeatures = size(XTrainNorm,2); % Still 7 features
        
                        layers = [
                            sequenceInputLayer(numFeatures) % This layer will now expect [numFeatures x 1]
                            lstmLayer(128, 'OutputMode', 'last')
                            dropoutLayer(0.5)
                            fullyConnectedLayer(64)
                            reluLayer()
                            fullyConnectedLayer(numel(categories(yTrain))) % Use numel(categories(yTrain)) for robustness
                            softmaxLayer
                            classificationLayer];
        
                        % Training options (rest remains same)
                        options = trainingOptions('adam', ...
                            'MaxEpochs', 50, ...
                            'MiniBatchSize', 32, ...
                            'ValidationData', {XValCell, yVal}, ...
                            'ValidationFrequency', 10, ...
                            'Plots', 'training-progress', ...
                            'Verbose', true); ...
                            %'ExecutionEnvironment', 'cpu', ... % Keep this as 'cpu' since 'auto' had issues
                            'OutputFcn'; @(info)app.trainingProgressCallback(info);
        
                        % Train model
                        net = trainNetwork(XTrainCell, yTrain, layers, options);
        
                        % Calculate feature importance
                    featureImp = app.calculateLSTMFeatureImportance(net, XTrainCell, yTrain);
            
                        % Store trained model
                        app.TrainedModels.LSTM = struct(...
                            'net', net, ...
                            'normParams', normParams, ...
                            'Accuracy', sum(classify(net, XValCell) == yVal)/numel(yVal), ...
                            'FeatureImportance', featureImp);
                       try
                            % Ensure predictions and true labels are categorical
                            trueLabels = categorical(yVal(:)); % Convert yVal to categorical column vector
                            predLabels = categorical(classify(net, XValCell), categories(trueLabels)); % Ensure same categories
                            
                            % Calculate accuracy
                            accuracy = sum(predLabels == trueLabels) / numel(trueLabels) * 100;
                        
                            % Create confusion matrix with accuracy displayed in the title
                            figure('Name', 'LSTM Confusion Matrix', 'NumberTitle', 'off');
                            confusionchart(trueLabels, predLabels, ...
                                'Title', sprintf('LSTM Confusion Matrix (Accuracy: %.2f%%)', accuracy), ...
                                'RowSummary', 'row-normalized', ...
                                'ColumnSummary', 'column-normalized');
                        
                        catch ME
                            warning('Failed to display confusion matrix: %s', ME().message);
                            disp('--- Debug Info ---');
                            disp('Unique true labels:'); disp(unique(yVal));
                            disp('Unique predicted labels:'); 
                            try
                                disp(unique(classify(net, XValCell)));
                            catch innerME
                                warning('Failed to classify validation data: %s', innerME().message);
                            end
                        end
                    
                case 'SVM'
                    % Standardize data (zero mean, unit variance)
                    app.SVM_Mean = mean(XTrain, 1);
                    app.SVM_Std = std(XTrain, 0, 1);
                    app.SVM_Std(app.SVM_Std == 0) = 1; % Handle constant features
                    
                    % Apply standardization
                    XTrainStd = (XTrain - app.SVM_Mean) ./ app.SVM_Std;
                    XValStd = (XVal - app.SVM_Mean) ./ app.SVM_Std;
                    
                    % Configure SVM with RBF kernel
                    svmTemplate = templateSVM(...
                        'KernelFunction', 'rbf', ...
                        'Standardize', false, ...
                        'KernelScale', 'auto', ...
                        'BoxConstraint', 1);
                    
                    % Train multiclass SVM
                    model = fitcecoc(...
                        XTrainStd, yTrain, ...
                        'Learners', svmTemplate, ...
                        'Coding', 'onevsone', ...
                        'FitPosterior', true);
                    
                    % Calculate feature importance via permutation
                    featureImp = zeros(1, size(XTrain, 2));
                    baselineAcc = sum(predict(model, XTrainStd) == yTrain)/numel(yTrain);
                    
                    for i = 1:size(XTrain, 2)
                        XPerm = XTrainStd;
                        XPerm(:,i) = XPerm(randperm(size(XPerm,1)),i);
                        permAcc = sum(predict(model, XPerm) == yTrain)/numel(yTrain);
                        featureImp(i) = baselineAcc - permAcc;
                    end
                    
                    % Normalize feature importance
                    featureImp = featureImp ./ sum(featureImp);
                    
                    % Make predictions
                    YPredVal = predict(model, XValStd);
                    
                    % Store trained model
                    app.TrainedModels.SVM = struct(...
                        'model', model, ...
                        'Accuracy', sum(YPredVal == yVal)/numel(yVal), ...
                        'FeatureImportance', featureImp);
                    
                    % Show confusion matrix
                    app.showConfusionMatrixInNewFigure(yVal, YPredVal, 'SVM');
                    
                case 'CNN'
                    % Normalize data to [0,1] range
                    XTrainNorm = (XTrain - min(XTrain)) ./ (max(XTrain) - min(XTrain));
                    XValNorm = (XVal - min(XTrain)) ./ (max(XTrain) - min(XTrain));
                    
                    % Reshape for CNN [1, features, samples, 1]
                    XTrainCNN = permute(reshape(XTrainNorm', [1, size(XTrainNorm,2), size(XTrainNorm,1), 1]), [1 2 4 3]);
                    XValCNN = permute(reshape(XValNorm', [1, size(XValNorm,2), size(XValNorm,1), 1]), [1 2 4 3]);
                    
                    % Define CNN architecture
                    layers = [
                        imageInputLayer([1 size(XTrain,2) 1])
                        convolution2dLayer([1 3], 32, 'Padding', 'same')
                        batchNormalizationLayer()
                        reluLayer()
                        maxPooling2dLayer([1 2], 'Stride', [1 1])
                        convolution2dLayer([1 3], 64, 'Padding', 'same')
                        batchNormalizationLayer()
                        reluLayer()
                        fullyConnectedLayer(64)
                        reluLayer()
                        dropoutLayer(0.5)
                        fullyConnectedLayer(6)
                        softmaxLayer()
                        classificationLayer];
                    
                    % Training options
                    options = trainingOptions('adam', ...
                        'MaxEpochs', 30, ...
                        'MiniBatchSize', 32, ...
                        'ValidationData', {XValCNN, yVal}, ...
                        'Plots', 'training-progress');
                    
                    % Train model
                    net = trainNetwork(XTrainCNN, yTrain, layers, options);
                    
                    % Calculate feature importance
                    featureImp = app.calculateCNNFeatureImportance(net, XTrainCNN, yTrain);
                    
                    % Make predictions
                    YPredVal = classify(net, XValCNN);
                    
                    % Store trained model
                    app.TrainedModels.CNN = struct(...
                        'net', net, ...
                        'min', min(XTrain), ...
                        'max', max(XTrain), ...
                        'Accuracy', sum(YPredVal == yVal)/numel(yVal), ...
                        'FeatureImportance', featureImp);
                    
                    % Show confusion matrix
                    app.showConfusionMatrixInNewFigure(yVal, YPredVal, 'CNN');
            end
            
            % Update UI components
            app.plotModelPerformance();
            app.plotFeatureImportance();
            
            % Enable prediction buttons
            modelField = regexprep(modelType, '\s*\(Built-in\)', '');
            accuracy = app.TrainedModels.(modelField).Accuracy;
            app.ProgressBar.Value = 100;
            app.updateStatus([modelType ' trained (Accuracy: ' sprintf('%.1f%%', accuracy*100) ')'], 'green');
            app.PredictButton.Enable = 'on';
            app.GenerateReportButton.Enable = 'on';
            app.ManualPredictButton.Enable = 'on';
            
        catch ME
            % Error handling
            app.ProgressBar.Value = 0;
            app.updateStatus(['Training error: ' ME.message], 'red');
            uialert(app.UIFigure, ME.message, 'Training Error');
            
            % Clean up training figure if it exists
            if isfield(app, 'TrainingFigure') && isvalid(app.TrainingFigure)
                close(app.TrainingFigure);
            end
        end
    end
    
        function featureImp = calculateLSTMFeatureImportance(~, net, XCell, y)
        % Get number of features
        numFeatures = size(XCell{1}, 1);
        numObservations = numel(XCell);
        featureImp = zeros(1, numFeatures);
        
        % Get baseline predictions
        YPred = classify(net, XCell);
        baselineAcc = mean(YPred == y);
        
        % If perfect accuracy, add small noise to create meaningful comparison
        if baselineAcc >= 1
            YPred(1) = categorical(mode(double(y))); % Flip one prediction
            baselineAcc = mean(YPred == y);
        end
        
        % Calculate importance with parallel processing
        parfor i = 1:numFeatures
            % Create permuted copy
            XPerm = XCell;
            
            % Permute this feature across all sequences
            for j = 1:numObservations
                originalSeq = XPerm{j};
                originalSeq(i,:) = originalSeq(i, randperm(size(originalSeq,2)));
                XPerm{j} = originalSeq;
            end
            
            % Get accuracy with permuted feature
            YPredPerm = classify(net, XPerm);
            permAcc = mean(YPredPerm == y);
            
            % Store raw importance
            featureImp(i) = baselineAcc - permAcc;
        end
        
        % Post-processing
        featureImp = featureImp - min(featureImp); % Shift to non-negative
        featureImp = featureImp + 0.01*max(featureImp); % Add small constant
        
        % Normalize using softmax to emphasize differences
        expImp = exp(featureImp*10); % Scale to emphasize differences
        featureImp = expImp/sum(expImp);
        
        % Debug output
        disp(['Raw importance: ' num2str(featureImp)]);
        disp(['Normalized importance: ' num2str(featureImp)]);
    end
         
        function featureImp = calculateCNNFeatureImportance(~, net, X, y)
            % Calculate feature importance for CNN model using occlusion
            numFeatures = size(X, 2);
            featureImp = zeros(1, numFeatures);
            
            % Get baseline accuracy
            YPred = classify(net, X);
            baselineAcc = sum(YPred == y) / numel(y);
            
            % Calculate importance for each feature
            for i = 1:numFeatures
                XOccluded = X;
                % Occlude the feature by setting it to zero
                XOccluded(:,i,:,:) = 0;
                
                % Calculate accuracy with occluded feature
                YPredOccluded = classify(net, XOccluded);
                occAcc = sum(YPredOccluded == y) / numel(y);
                
                % Importance is the decrease in accuracy
                featureImp(i) = baselineAcc - occAcc;
            end
            
            % Normalize importance scores
            featureImp = featureImp / sum(featureImp);
        end

        function stop = trainingPlotCallback(app, info, ax1, ax2)
            % Callback function to plot training progress
            stop = false;
            
            % Check if figure still exists
            if ~isempty(app.TrainingFigure) && ~ishandle(app.TrainingFigure)
                return;
            end
            
            if info.State == "iteration"
                % Update training progress structure
                app.TrainingProgress.Epoch(end+1) = info.Epoch;
                app.TrainingProgress.TrainingAccuracy(end+1) = info.TrainingAccuracy;
                app.TrainingProgress.ValidationAccuracy(end+1) = info.ValidationAccuracy;
                app.TrainingProgress.TrainingLoss(end+1) = info.TrainingLoss;
                app.TrainingProgress.ValidationLoss(end+1) = info.ValidationLoss;
                
                % Update plots if axes are valid
                if nargin > 2 && ishandle(ax1) && ishandle(ax2)
                    % Plot accuracy
                    plot(ax1, app.TrainingProgress.Epoch, app.TrainingProgress.TrainingAccuracy, 'b-', ...
                        'DisplayName', 'Training Accuracy');
                    hold(ax1, 'on');
                    plot(ax1, app.TrainingProgress.Epoch, app.TrainingProgress.ValidationAccuracy, 'r-', ...
                        'DisplayName', 'Validation Accuracy');
                    hold(ax1, 'off');
                    title(ax1, 'Training Progress - Accuracy');
                    xlabel(ax1, 'Epoch');
                    ylabel(ax1, 'Accuracy');
                    legend(ax1, 'show');
                    grid(ax1, 'on');
                    
                    % Plot loss
                    plot(ax2, app.TrainingProgress.Epoch, app.TrainingProgress.TrainingLoss, 'b-', ...
                        'DisplayName', 'Training Loss');
                    hold(ax2, 'on');
                    plot(ax2, app.TrainingProgress.Epoch, app.TrainingProgress.ValidationLoss, 'r-', ...
                        'DisplayName', 'Validation Loss');
                    hold(ax2, 'off');
                    title(ax2, 'Training Progress - Loss');
                    xlabel(ax2, 'Epoch');
                    ylabel(ax2, 'Loss');
                    legend(ax2, 'show');
                    grid(ax2, 'on');
                    
                    drawnow;
                end
                
                % Update progress bar
                if isfield(info, 'MaxEpochs')
                    progress = info.Epoch/info.MaxEpochs;
                    app.ProgressBar.Value = 20 + 80*progress;
                end
            end
        end

        function trainingProgressCallback(app, info)
            % Callback for training progress updates
            if info.State == "iteration"
                app.ProgressBar.Value = 20 + (info.Iteration/info)*80;
                drawnow;
                
                % Store training progress for plotting
                if ~isempty(info.TrainingAccuracy)
                    app.TrainingProgress.Epoch(end+1) = info.Epoch;
                    app.TrainingProgress.TrainingAccuracy(end+1) = info.TrainingAccuracy;
                    app.TrainingProgress.ValidationAccuracy(end+1) = info.ValidationAccuracy;
                    app.TrainingProgress.TrainingLoss(end+1) = info.TrainingLoss;
                    app.TrainingProgress.ValidationLoss(end+1) = info.ValidationLoss;
                end
            end
        end
        
        function plotModelPerformance(app)
            % Plot model performance metrics
            cla(app.PerformanceAxes);
            
            modelType = app.ModelSelectionDropDown.Value;
            
            if isfield(app.TrainedModels, modelType)
                model = app.TrainedModels.(modelType);
                
                % For neural networks, plot training progress if available
                if any(strcmp(modelType, {'LSTM', 'CNN'})) && ~isempty(app.TrainingProgress.Epoch)
                    epochs = app.TrainingProgress.Epoch;
                    
                    yyaxis(app.PerformanceAxes, 'left');
                    plot(app.PerformanceAxes, epochs, app.TrainingProgress.TrainingAccuracy, 'b-o', 'LineWidth', 1.5);
                    hold(app.PerformanceAxes, 'on');
                    plot(app.PerformanceAxes, epochs, app.TrainingProgress.ValidationAccuracy, 'b--x', 'LineWidth', 1.5);
                    ylabel(app.PerformanceAxes, 'Accuracy');
                    
                    yyaxis(app.PerformanceAxes, 'right');
                    plot(app.PerformanceAxes, epochs, app.TrainingProgress.TrainingLoss, 'r-s', 'LineWidth', 1.5);
                    plot(app.PerformanceAxes, epochs, app.TrainingProgress.ValidationLoss, 'r--d', 'LineWidth', 1.5);
                    ylabel(app.PerformanceAxes, 'Loss');
                    
                    xlabel(app.PerformanceAxes, 'Epoch');
                    title(app.PerformanceAxes, [modelType ' Training Progress']);
                    legend(app.PerformanceAxes, {'Train Accuracy', 'Val Accuracy', 'Train Loss', 'Val Loss'});
                    grid(app.PerformanceAxes, 'on');
                    hold(app.PerformanceAxes, 'off');
                    
                else
                    % For other models, show validation accuracy
                    bar(app.PerformanceAxes, model.Accuracy);
                    ylim(app.PerformanceAxes, [0 1]);
                    title(app.PerformanceAxes, ['Validation Accuracy: ' sprintf('%.1f%%', model.Accuracy*100)]);
                    ylabel(app.PerformanceAxes, 'Accuracy');
                end
            end
        end
        
        function plotFeatureImportance(app)
    cla(app.FeatureImportanceAxes);
    
    modelType = app.ModelSelectionDropDown.Value;
    modelField = regexprep(modelType, '\s*\(Built-in\)', '');
    
    if isfield(app.TrainedModels, modelField) && isfield(app.TrainedModels.(modelField), 'FeatureImportance')
        imp = app.TrainedModels.(modelField).FeatureImportance;
        
        % Define all features (original 7 + additional gases)
        allFeatures = {'H₂', 'CH₄', 'C₂H₆', 'C₂H₄', 'C₂H₂', 'CO', 'CO₂', 'H₂O', 'Temp', 'Load'};
        varNames = {'h2', 'ch4', 'c2h6', 'c2h4', 'c2h2', 'co', 'co2', 'h2o', 'temperature', 'load'};
        
        % Match importance values to features (handle cases where not all features were used)
        fullImp = zeros(1, length(allFeatures));
        for i = 1:length(varNames)
            if i <= length(imp)  % Ensure we don't exceed importance array bounds
                fullImp(i) = imp(i);
            end
        end
        
        % Handle NaN/invalid values
        if any(isnan(fullImp)) || all(fullImp == 0)
            fullImp = ones(1, length(allFeatures))/length(allFeatures); % Equal importance
            text(app.FeatureImportanceAxes, 0.5, 0.3, ...
                'Using default importance values', ...
                'HorizontalAlignment', 'center');
        end
        
        % Sort features by importance
        [sortedImp, idx] = sort(fullImp, 'descend');
        sortedFeatures = allFeatures(idx);
        
        % Create plot with minimum bar height for visibility
        minHeight = 0.01; % 1% minimum height
        barValues = max(sortedImp, minHeight);
        
        % Create horizontal bar plot
        bh = barh(app.FeatureImportanceAxes, barValues);
        bh.FaceColor = [0.2 0.4 0.8]; % Nice blue color
        bh.BarWidth = 0.8;
        
        % Configure axes
        app.FeatureImportanceAxes.YTick = 1:length(allFeatures);
        app.FeatureImportanceAxes.YTickLabel = sortedFeatures;
        app.FeatureImportanceAxes.YLim = [0.4 length(allFeatures)+0.6];
        app.FeatureImportanceAxes.XLim = [0 max(barValues)*1.1];
        title(app.FeatureImportanceAxes, 'Feature Importance');
        xlabel(app.FeatureImportanceAxes, 'Importance Score');
        grid(app.FeatureImportanceAxes, 'on');
        
        % Add value labels
        for i = 1:length(sortedImp)
            text(app.FeatureImportanceAxes, barValues(i)/2, i, ...
                sprintf('%.3f', sortedImp(i)), ...
                'Color', 'white', 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');
        end
        
    else
        % No feature importance data available
        text(app.FeatureImportanceAxes, 0.5, 0.5, ...
            'Feature importance data not available', ...
            'HorizontalAlignment', 'center');
        axis(app.FeatureImportanceAxes, 'off');
    end
end

        function predictWithModel(app, ~, ~)
    % Make predictions using trained model
    modelType = app.ModelSelectionDropDown.Value;
    data = app.TransformerData;

    if isempty(data) || ~istable(data)
        app.updateStatus('No data available or data is not a table for prediction', 'red');
        return;
    end

    % Ensure the model type is valid and exists in app.TrainedModels
    modelField = regexprep(modelType, '\s*\(Built-in\)', '');
    if ~isfield(app.TrainedModels, modelField)
        app.updateStatus(['No ' modelType ' model trained. Please train the model first.'], 'red');
        return;
    end

    app.updateStatus(['Running ' modelType ' predictions...'], 'yellow');
    app.ProgressBar.Value = 20;

    try
        % Prediction uses original 6 gases + temp/load
        predVars = {'h2','ch4','c2h6','c2h4','c2h2','temperature','load'};
        if ~all(ismember(predVars, data.Properties.VariableNames))
            missingCols = predVars(~ismember(predVars, data.Properties.VariableNames));
            error('Missing required columns: %s', strjoin(missingCols, ', '));
        end
        X = table2array(data(:, predVars));

        % Check for NaN or Inf values
        if any(~isfinite(X(:)))
            error('Data contains NaN or Inf values. Please clean your data first.');
        end

        % Get the trained model
        modelInfo = app.TrainedModels.(modelField);

        % Initialize variables for prediction
        YPred = [];
        scores = [];

        switch modelType
            case 'LSTM'
                if ~isfield(modelInfo, 'normParams') || isempty(modelInfo.normParams)
                    error('LSTM normalization parameters not found. Please retrain the LSTM model.');
                end

                XNorm = mapminmax('apply', X', modelInfo.normParams)';
                XCell = arrayfun(@(i) XNorm(i,:)', 1:size(XNorm,1), 'UniformOutput', false)';
                [YPred, scores] = classify(modelInfo.net, XCell);

            case 'SVM'
                if isempty(app.SVM_Mean) || isempty(app.SVM_Std)
                    error('SVM standardization parameters not found. Please retrain the SVM model.');
                end
                XStd = (X - app.SVM_Mean) ./ app.SVM_Std;
                [YPred, ~, ~, decisionValues] = predict(modelInfo.model, XStd);
                scores = 1./(1+exp(-decisionValues));
                scores = scores ./ sum(scores, 2);
                YPred = categorical(YPred);

            case 'CNN'
                if ~isfield(modelInfo, 'min') || ~isfield(modelInfo, 'max') || isempty(modelInfo.min) || isempty(modelInfo.max)
                    error('CNN normalization parameters not found. Please retrain the CNN model.');
                end
                XNorm = (X - modelInfo.min) ./ (modelInfo.max - modelInfo.min);
                XCNN = permute(reshape(XNorm', [1, size(XNorm,2), 1, size(XNorm,1)]), [1 2 4 3]);
                [YPred, scores] = classify(modelInfo.net, XCNN);
        end

        if isempty(YPred)
            app.updateStatus('Prediction resulted in empty output', 'red');
            return;
        end

        % Get confidence for latest prediction
        [maxScore, ~] = max(scores(end,:));
        confidence = maxScore * 100;
        prediction = YPred(end);

        % Default values for display
        defaultVals = struct( ...
            'co',   360, ...
            'co2',   25, ...
            'h2o',   15, ...
            'temperature', 25, ...
            'load', 50 ...
        );

        % Build diagnosis text with all available gases
        diagnosisText = sprintf('%s Model Diagnosis:\n\n', modelType);
        diagnosisText = [diagnosisText sprintf('Predicted Fault: %s (%.1f%% confidence)\n\n', char(prediction), confidence)];

        % All gases
        allGases = {
            'h2',   'H₂';
            'ch4',  'CH₄';
            'c2h6', 'C₂H₆';
            'c2h4', 'C₂H₄';
            'c2h2', 'C₂H₂';
            'co',   'CO';
            'co2',  'CO₂';
            'h2o',  'H₂O'
        };

        diagnosisText = [diagnosisText 'Gas Concentrations (ppm):\n'];
        for i = 1:size(allGases,1)
            varName = allGases{i,1};
            prettyName = allGases{i,2};

            if ismember(varName, data.Properties.VariableNames)
                val = data.(varName)(end);
                if ~isfinite(val)
                    val = defaultVals.(varName); % Use default if NaN or Inf
                end
            elseif isfield(defaultVals, varName)
                val = defaultVals.(varName); % Use default if column missing
            else
                val = 0; % fallback
            end

            diagnosisText = [diagnosisText sprintf('  %-4s: %6.2f\n', prettyName, val)];
        end

        % Operating conditions
        tempVal = data.temperature(end);
        if ~isfinite(tempVal)
            tempVal = defaultVals.temperature;
        end

        loadVal = data.load(end);
        if ~isfinite(loadVal)
            loadVal = defaultVals.load;
        end

        diagnosisText = [diagnosisText sprintf('\nOperating Conditions:\n')];
        diagnosisText = [diagnosisText sprintf('  Temperature: %.1f°C\n', tempVal)];
        diagnosisText = [diagnosisText sprintf('  Load:        %.1f%%\n', loadVal)];

        % Add recommended actions
        diagnosisText = [diagnosisText sprintf('\nRECOMMENDED ACTIONS:\n')];
        switch char(prediction)
            case 'Normal'
                diagnosisText = [diagnosisText '  - Continue regular monitoring'];
            case {'PD', 'D1', 'D2'}
                diagnosisText = [diagnosisText '  - Inspect for partial discharge\n' ...
                              '  - Check bushings and tap changers'];
            case {'T1', 'T2'}
                diagnosisText = [diagnosisText '  - Check for overheating\n' ...
                              '  - Inspect cooling system'];
            otherwise
                diagnosisText = [diagnosisText '  - Conduct comprehensive inspection'];
        end

        % Update UI
        app.AIDiagnosisTextArea.Value = diagnosisText;
        app.ProgressBar.Value = 100;
        app.updateStatus([modelType ' predictions completed'], 'green');

    catch ME
        app.ProgressBar.Value = 0;
        app.updateStatus(['Prediction error: ' ME.message], 'red');
        app.AIDiagnosisTextArea.Value = sprintf(...
            'Prediction failed:\n\nError: %s\n\nStack Trace:\n%s', ...
            ME.message, getReport(ME, 'extended', 'hyperlinks', 'off'));
    end
end

        function connectToCloud(app)
    app.updateStatus('Initializing Cloud connection...', 'yellow');
    app.CloudStatusLamp.Color = 'yellow';
    drawnow;
    
    try
        % Validate credentials
        if isempty(app.ThingSpeakChannelID) || isempty(app.ThingSpeakReadAPIKey)
            error('Cloud credentials not configured');
        end
        
        % Test connection
        testData = thingSpeakRead(app.ThingSpeakChannelID, ...
            'Fields', 1, ...
            'NumPoints', 1, ...
            'ReadKey', app.ThingSpeakReadAPIKey, ...
            'Timeout', 10);
        
        if isempty(testData)
            error('Received empty test data');
        end
        
        % Create/restart timer if needed
        if isempty(app.ThingSpeakTimer) || ~isvalid(app.ThingSpeakTimer)
            app.ThingSpeakTimer = timer(...
                'Name', 'ThingSpeakPolling', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', 15, ... % Cloud free account requires 15s between updates
                'TimerFcn', @(~,~)app.fetchThingSpeakData(), ...
                'ErrorFcn', @(~,~)app.handleThingSpeakError());
        end
        
        % Start timer
        if strcmp(app.ThingSpeakTimer.Running, 'off')
            start(app.ThingSpeakTimer);
        end
        
        app.CloudConnected = true;
        app.CloudStatusLamp.Color = 'green';
        app.updateStatus(sprintf('Connected to Cloud Channel %d', app.ThingSpeakChannelID), 'green');
        
    catch ME
        app.CloudConnected = false;
        app.CloudStatusLamp.Color = 'red';
        app.updateStatus(['Connection failed: ' ME.message], 'red');
        
        % Clean up timer on failure
        if ~isempty(app.ThingSpeakTimer) && isvalid(app.ThingSpeakTimer)
            stop(app.ThingSpeakTimer);
        end
    end
end
        
        function handleThingSpeakError(app)
    try
        % Stop and clean up timer
        if ~isempty(app.ThingSpeakTimer) && isvalid(app.ThingSpeakTimer)
            stop(app.ThingSpeakTimer);
            delete(app.ThingSpeakTimer);
            app.ThingSpeakTimer = [];
        end
        
        % Update UI
        app.CloudStatusLamp.Color = 'red';
        app.LiveDataButton.Text = 'Connect to Cloud';
        app.LiveDataButton.BackgroundColor = [0.47, 0.67, 0.19];
        app.updateStatus('Cloud connection lost', 'red');
        
    catch ME
        app.updateStatus(['Error handler failed: ' ME.message], 'red');
    end
end

        function handleConnectionError(app, ~)
            try
                % Stop and clean up timer
                if ~isempty(app.ThingSpeakTimer) && isvalid(app.ThingSpeakTimer)
                    stop(app.ThingSpeakTimer);
                    delete(app.ThingSpeakTimer);
                    app.ThingSpeakTimer = [];
                end
                
                % Update UI if components still exist
                if isvalid(app.UIFigure)
                    app.CloudStatusLamp.Color = 'red';
                    app.LiveDataButton.Text = 'Connect to Cloud';
                    app.LiveDataButton.BackgroundColor = [0.47, 0.67, 0.19];
                    app.updateStatus('Cloud connection lost', 'red');
                end
            catch ME2
                if isvalid(app.UIFigure)
                    app.updateStatus(['Cleanup error: ' ME2.message], 'red');
                end
            end
        end 
               
        function processThingSpeakData(app, newData)
    % Process data received from ThingSpeakTimer
    if isempty(app.TransformerData)
        app.TransformerData = newData;
    else
        app.TransformerData = [app.TransformerData; newData];
    end
    
    app.DataGrid.Data = app.TransformerData;
    app.updateVisualizations();
    app.updateStatus(sprintf('Data updated at %s', datestr(newData.Time)), 'green');
end

        function saveToCloud(app, ~, ~)
            try
                data = table2struct(app.TransformerData);

                options = weboptions(...
                    'HeaderFields', {
                        'X-API-KEY', app.APIKey;
                        'Content-Type', 'application/json'
                    }, ...
                    'Timeout', 120, ...
                    'MediaType', 'application/json');

                response = webwrite([app.CloudEndpoint '/api/data/upload'], data, options);

                if isfield(response, 'status') && strcmp(response.status, 'success')
                    app.updateStatus(sprintf('Saved %d records to cloud', numel(data)), 'green');
                else
                    error('API returned failure status');
                end

            catch ME
                app.updateStatus(['Cloud save error: ' ME.message], 'red');
                uialert(app.UIFigure, ME.message, 'Cloud Save Error');
            end
        end
        
        function showConfusionMatrixInNewFigure(~, trueLabels, predictedLabels, modelType)
            try
                % Ensure predictions and true labels are categorical with same categories
                trueLabels = categorical(trueLabels(:));
                predictedLabels = categorical(predictedLabels(:), categories(trueLabels));
            
                % Calculate accuracy
                accuracy = sum(predictedLabels == trueLabels) / numel(trueLabels) * 100;
            
                % Create confusion matrix with normalized summaries and accuracy in title
                figure('Name', [modelType ' Confusion Matrix'], 'NumberTitle', 'off');
                confusionchart(trueLabels, predictedLabels, ...
                    'Title', sprintf('%s Confusion Matrix (Accuracy: %.2f%%)', modelType, accuracy), ...
                    'RowSummary', 'row-normalized', ...
                    'ColumnSummary', 'column-normalized');
            
            catch ME
                warning('Failed to display confusion matrix for %s model: %s', modelType, ME.message);
                disp('--- Debug Info ---');
                disp('Unique true labels:'); disp(unique(trueLabels));
                disp('Unique predicted labels:');
                try
                    disp(unique(predictedLabels));
                catch innerME
                    warning('Failed to inspect predicted labels: %s', innerME().message);
                end
            end
        end

    end
    
 methods (Access = public)
        
        % App initialization and construction
        function app = TransformerDiagnosticApp1
            % Create and configure components
            createComponents(app);
            
            % Initialize properties
            app.LastDataPath = pwd;
        %    app.PlotLimits = struct();
            app.TrainedModels = struct();
            app.TrainingFigure = [];
            app.TrainingAxes1 = [];
            app.TrainingAxes2 = [];
           % app.ThingSpeakTimer = [];
            app.ThingSpeakTimer = timer.empty;
            app.SVM_Mean = [];
            app.SVM_Std = [];
            app.TrainingProgress = struct(...
                'Epoch', [], ...
                'TrainingAccuracy', [], ...
                'ValidationAccuracy', [], ...
                'TrainingLoss', [], ...
                'ValidationLoss', []);
            
            % Register callbacks
            registerCallbacks(app);
        end

        function createComponents(app)
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 800];
            app.UIFigure.Name = 'Transformer Diagnostic System';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeApp, true);
            
            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [20 70 1160 710];
            
            % Create Data Tab
            app.DataTab = uitab(app.TabGroup, 'Title', 'Data');
            
            % Create DataGrid
            app.DataGrid = uitable(app.DataTab);
            app.DataGrid.Position = [20 100 1120 580];
            app.DataGrid.ColumnName = {'Load data....'};
            
            % Create LoadDataButton
            app.LoadDataButton = uibutton(app.DataTab, 'push');
            app.LoadDataButton.Position = [20 40 100 30];
            app.LoadDataButton.Text = 'Load Data';
            app.LoadDataButton.Tooltip = 'Load transformer data from file';
            
            % Create ClearDataButton
            app.ClearDataButton = uibutton(app.DataTab, 'push');
            app.ClearDataButton.Position = [140 40 100 30];
            app.ClearDataButton.Text = 'Clear Data';
            app.ClearDataButton.Tooltip = 'Clear all loaded data';
            
            % Create DataFormatDropDown
            app.DataFormatDropDown = uidropdown(app.DataTab);
            app.DataFormatDropDown.Position = [260 40 150 30];
            app.DataFormatDropDown.Items = {'Standard DGA', 'IEEE Format', 'Custom'};
            app.DataFormatDropDown.Value = 'Standard DGA';
            app.DataFormatDropDown.Tooltip = 'Select data format for CSV files';
            
            % Create LiveDataButton
                  % Add these components for live data source selection
            app.LiveDataSourceLabel = uilabel(app.DataTab);
            app.LiveDataSourceLabel.Text = 'Live Data Source:';
            app.LiveDataSourceLabel.Position = [430 70 100 22];
            app.LiveDataSourceLabel.FontWeight = 'bold';
            
            app.LiveDataSourceDropDown = uidropdown(app.DataTab);
            app.LiveDataSourceDropDown.Items = {'Select source', 'Local Arduino', 'Connect Cloud'};
            app.LiveDataSourceDropDown.Value = 'Select source';
            app.LiveDataSourceDropDown.Position = [430 40 150 30];
            app.LiveDataSourceDropDown.ValueChangedFcn = createCallbackFcn(app, @liveDataSourceChanged, true);
            
            app.LiveDataButton = uibutton(app.DataTab, 'push');
            app.LiveDataButton.Position = [590 40 120 30];
            app.LiveDataButton.Text = 'Connect';
            app.LiveDataButton.BackgroundColor = [0.47, 0.67, 0.19];
            app.LiveDataButton.Enable = 'off'; % Disabled until source is selected
            app.LiveDataButton.ButtonPushedFcn = createCallbackFcn(app, @connectLiveData, true);
            
            % Create Visualization Tab
            app.VisualizationTab = uitab(app.TabGroup, 'Title', 'Visualization');
            
            % Create TimeSeriesAxes
            app.TimeSeriesAxes = uiaxes(app.VisualizationTab);
            title(app.TimeSeriesAxes, 'Time Series Data')
            xlabel(app.TimeSeriesAxes, 'Time')
            ylabel(app.TimeSeriesAxes, 'Value')
            app.TimeSeriesAxes.Position = [50 300 500 250];
            
            % Create GasConcentrationAxes
            app.GasConcentrationAxes = uiaxes(app.VisualizationTab);
            title(app.GasConcentrationAxes, 'Gas Concentrations')
            xlabel(app.GasConcentrationAxes, 'Time')
            ylabel(app.GasConcentrationAxes, 'Concentration (ppm)')
            app.GasConcentrationAxes.Position = [600 300 500 250];
            
            % Create CorrelationHeatmapAxes
            app.CorrelationHeatmapAxes = uiaxes(app.VisualizationTab);
            title(app.CorrelationHeatmapAxes, 'Correlation Heatmap')
            app.CorrelationHeatmapAxes.Position = [200 40 800 250];
            
            % Create FaultDetection Tab
            app.FaultDetectionTab = uitab(app.TabGroup, 'Title', 'Fault Detection');
            
            % Create DuvalTriangleAxes
            app.DuvalTriangleAxes = uiaxes(app.FaultDetectionTab);
            title(app.DuvalTriangleAxes, 'Duval Triangle')
            app.DuvalTriangleAxes.Position = [100 100 500 450];
            
            % Create FaultTypeLabel
            app.FaultTypeLabel = uilabel(app.FaultDetectionTab);
            app.FaultTypeLabel.Position = [600 300 400 100];
            app.FaultTypeLabel.FontSize = 16;
            app.FaultTypeLabel.Text = 'No fault detected';
            
            % Create AI Analysis Tab
            app.AITab = uitab(app.TabGroup, 'Title', 'AI Analysis');
          
            % Create ModelSelectionDropDown
            app.ModelSelectionDropDown = uidropdown(app.AITab);
            app.ModelSelectionDropDown.Position = [50 600 150 22];
            app.ModelSelectionDropDown.Items = {'LSTM', 'SVM', 'CNN'};
            app.ModelSelectionDropDown.Value = 'LSTM';
            app.ModelSelectionDropDown.Tooltip = 'Select AI model type';
            
            % Create TrainModelButton
            app.TrainModelButton = uibutton(app.AITab, 'push');
            app.TrainModelButton.Position = [220 600 100 30];
            app.TrainModelButton.Text = 'Train Model';
            app.TrainModelButton.Enable = 'off';
            app.TrainModelButton.Tooltip = 'Train selected AI model';
            
            % Create PredictButton
            app.PredictButton = uibutton(app.AITab, 'push');
            app.PredictButton.Position = [340 600 100 30];
            app.PredictButton.Text = 'Predict';
            app.PredictButton.Enable = 'off';
            app.PredictButton.Tooltip = 'Make predictions using trained model';
            
            % Create PerformanceAxes
            app.PerformanceAxes = uiaxes(app.AITab);
            title(app.PerformanceAxes, 'Model Performance')
            app.PerformanceAxes.Position = [50 250 500 250];
            
            % Create FeatureImportanceAxes
            app.FeatureImportanceAxes = uiaxes(app.AITab);
            title(app.FeatureImportanceAxes, 'Feature Importance')
            app.FeatureImportanceAxes.Position = [600 250 500 250];
            
            % Create AIDiagnosisTextArea
            app.AIDiagnosisTextArea = uitextarea(app.AITab);
            app.AIDiagnosisTextArea.Position = [50 40 1100 200];
            app.AIDiagnosisTextArea.Value = 'AI diagnosis results will appear here after prediction';
            app.AIDiagnosisTextArea.FontName = 'Courier New';
            
            % Create Cloud Integration Tab
            app.CloudTab = uitab(app.TabGroup, 'Title', 'Cloud');
            
            % Create CloudConnectButton
            app.CloudConnectButton = uibutton(app.CloudTab, 'push');
            app.CloudConnectButton.Position = [50 600 150 30];
            app.CloudConnectButton.Text = 'Connect to Cloud';
            app.CloudConnectButton.Tooltip = 'Connect to cloud service';
            
            % Create SaveToCloudButton
            app.SaveToCloudButton = uibutton(app.CloudTab, 'push');
            app.SaveToCloudButton.Position = [50 550 150 30];
            app.SaveToCloudButton.Text = 'Save to Cloud';
            app.SaveToCloudButton.Enable = 'off';
            app.SaveToCloudButton.Tooltip = 'Save data to cloud storage';
            
            % Create RealTimeDataSwitch
            app.RealTimeDataSwitch = uiswitch(app.CloudTab, 'toggle');
            app.RealTimeDataSwitch.Position = [250 600 45 20];
            app.RealTimeDataSwitch.Items = {'Off', 'On'};
            app.RealTimeDataSwitch.Tooltip = 'Enable real-time cloud updates';
            
            % Create CloudStatusLamp
            app.CloudStatusLamp = uilamp(app.CloudTab);
            app.CloudStatusLamp.Position = [350 600 20 20];
            app.CloudStatusLamp.Color = 'red';
            app.CloudStatusLamp.Tooltip = 'Cloud connection status';
            
            % Create CloudURLEditField
            app.CloudURLEditField = uieditfield(app.CloudTab, 'text');
            app.CloudURLEditField.Position = [50 500 300 22];
            app.CloudURLEditField.Value = 'http://localhost:8000';
            app.CloudURLEditField.Tooltip = 'Enter your Laravel API endpoint';
            
            % Create APIKeyEditField
            app.APIKeyEditField = uieditfield(app.CloudTab, 'text');
            app.APIKeyEditField.Position = [50 450 300 22];
            app.APIKeyEditField.Value = '';
            app.APIKeyEditField.Tooltip = 'Enter your API key';
            app.APIKeyEditField.Placeholder = 'API Key';
            
            % Create Report Tab
            app.ReportTab = uitab(app.TabGroup, 'Title', 'Report');
            
            % Create GenerateReportButton
            app.GenerateReportButton = uibutton(app.ReportTab, 'push');
            app.GenerateReportButton.Position = [50 600 150 30];
            app.GenerateReportButton.Text = 'Generate Report';
            app.GenerateReportButton.Enable = 'off';
            app.GenerateReportButton.Tooltip = 'Generate diagnostic report PDF';
            
            % Create ReportPreviewArea
            app.ReportPreviewArea = uitextarea(app.ReportTab);
            app.ReportPreviewArea.Position = [50 40 1100 200];
            app.ReportPreviewArea.Value = 'Report preview will appear here after generation';
            app.ReportPreviewArea.FontName = 'Courier New';
                    
            % Create status bar components
            app.StatusText = uilabel(app.UIFigure);
            app.StatusText.Position = [20 20 1000 20];
            app.StatusText.Text = 'Ready';
            
            app.StatusLamp = uilamp(app.UIFigure);
            app.StatusLamp.Position = [1150 20 20 20];
            app.StatusLamp.Color = 'green';
            
            app.ProgressBar = uigauge(app.UIFigure, 'linear');
            app.ProgressBar.Position = [1050 20 80 20];
            app.ProgressBar.Tooltip = 'Operation progress';
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';

         % In createComponents(), add this with other buttons in AITab
            app.ManualPredictButton = uibutton(app.AITab, 'push',...
                'Position', [460 600 120 30],...
                'Text', 'Manual Predict',...
                'Enable', 'off',... % Disabled until training completes
                'Tooltip', 'Predict with manual gas values');
                    % Cloud Connection Panel
                uilabel(app.CloudTab, 'Text', 'Cloud Settings', ...
                    'Position', [20 370 200 22], 'FontWeight', 'bold');
                
                uilabel(app.CloudTab, 'Text', 'Channel ID:', ...
                    'Position', [50 300 100 22]);
                app.ThingSpeakChannelEdit = uieditfield(app.CloudTab, 'numeric', ...
                    'Position', [150 300 200 22]);
                
                uilabel(app.CloudTab, 'Text', 'Write API Key:', ...
                    'Position', [50 250 100 22]);
                app.ThingSpeakWriteKeyEdit = uieditfield(app.CloudTab, 'text', ...
                    'Position', [150 250 200 22]);
                
                uilabel(app.CloudTab, 'Text', 'Read API Key:', ...
                    'Position', [50 200 100 22]);
                app.ThingSpeakReadKeyEdit = uieditfield(app.CloudTab, 'text', ...
                    'Position', [150 200 200 22]);
                
                % Second Cloud Channel
                uilabel(app.CloudTab, 'Text', 'Second Channel ID:', ...
                    'Position', [50 150 100 22]);
                app.SecondThingSpeakChannelEdit = uieditfield(app.CloudTab, 'numeric', ...
                    'Position', [150 150 200 22]);
                
                uilabel(app.CloudTab, 'Text', 'Second Read API Key:', ...
                    'Position', [50 100 100 22]);
                app.SecondThingSpeakReadKeyEdit = uieditfield(app.CloudTab, 'text', ...
                    'Position', [150 100 200 22]);

        end
        
        function registerCallbacks(app)
            % Register component callbacks
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @loadDataFromFile, true);
            app.ClearDataButton.ButtonPushedFcn = createCallbackFcn(app, @clearData, true);
            app.LiveDataButton.ButtonPushedFcn = createCallbackFcn(app, @connectLiveData, true);
            app.TrainModelButton.ButtonPushedFcn = createCallbackFcn(app, @trainModel, true);
            app.PredictButton.ButtonPushedFcn = createCallbackFcn(app, @predictWithModel, true);
            app.CloudConnectButton.ButtonPushedFcn = createCallbackFcn(app, @connectToCloud, true);
            app.SaveToCloudButton.ButtonPushedFcn = createCallbackFcn(app, @saveToCloud, true);
            app.GenerateReportButton.ButtonPushedFcn = createCallbackFcn(app, @generateReport, true);
            app.ManualPredictButton.ButtonPushedFcn = createCallbackFcn(app, @openManualPredictor, true);
        
            app.SecondThingSpeakChannelEdit.ValueChangedFcn = createCallbackFcn(app, @updateSecondChannelID, true);
            app.SecondThingSpeakReadKeyEdit.ValueChangedFcn = createCallbackFcn(app, @updateSecondReadKey, true);
        end
      
        function closeApp(app, ~)
    try
        selection = uiconfirm(app.UIFigure,...
            'Are you sure you want to close?',...
            'Confirm Close',...
            'Options', {'Yes', 'No'},...
            'DefaultOption', 2);
        
        if strcmp(selection, 'Yes')
            % Clean up any running operations
            try
                app.disconnectLiveData();
            catch
                % Ignore errors during cleanup
            end
            
            % Close training figure if it exists
            if ~isempty(app.TrainingFigure) && isvalid(app.TrainingFigure)
                close(app.TrainingFigure);
            end
            
            % Delete the main figure
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    catch ME
        disp(['Error closing app: ' ME.message]);
    end

        selection = uiconfirm(app.UIFigure,...
            'Are you sure you want to close?',...
            'Confirm Close',...
            'Options', {'Yes', 'No'},...
            'DefaultOption', 2);
        
        if strcmp(selection, 'Yes')
            % Use the disconnect function to clean up
            app.disconnectLiveData();
            
            % Close training figure if it exists
            if ~isempty(app.TrainingFigure) && ishandle(app.TrainingFigure)
                close(app.TrainingFigure);
            end
            
            delete(app.UIFigure);
        end
    end
    end
    
    methods (Static)
        function runApp()
            % Run the application
            app = TransformerDiagnosticApp1;
        end
    end
end
