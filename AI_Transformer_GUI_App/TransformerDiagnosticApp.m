classdef TransformerDiagnosticApp < matlab.apps.AppBase
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
        
    end
    
    properties (Access = private)
        TransformerData table               % Stores loaded transformer data
        TrainedModels struct                % Stores trained AI models
        CloudConnected logical = false      % Cloud connection status
        LastDataPath char                   % Last used data path
        PlotLimits struct                   % Stores plot axis limits
        CloudEndpoint = 'http://localhost:8000';
        APIKey char = 'sk-proj-t8E6ZiVlOHTUM_GIi3vTyFqfIsCnOqBbfZz3dllZYBmhxiUR'                    % API key storage
        TrainingProgress struct             % Stores training progress data
        SerialObj = []                      % Serial connection object for live data
    end
    
     methods (Access = private)

    function openManualPredictor(app, ~, ~)
    % Check if model is trained
    modelType = app.ModelSelectionDropDown.Value;
    if ~isfield(app.TrainedModels, modelType)
        uialert(app.UIFigure, ['Please train the ' modelType ' model first'], 'Model Not Trained');
        return;
    end
    
    % Create input figure
    fig = uifigure('Name', 'Gas Concentration Input', ...
                  'Position', [100 100 350 420], ...
                  'Color', [0.96 0.96 0.98]);
    movegui(fig, 'center');
    
    % Default values
    defaultValues = [50 120 66 80 5 360 75 85]; % [H2 CH4 C2H6 C2H4 C2H2 CO Temp Load]
    
    % Gas data configuration
    gases = {
        'H2',   'Hydrogen';
        'CH4',  'Methane';
        'C2H6', 'Ethane'; 
        'C2H4', 'Ethylene';
        'C2H2', 'Acetylene';
        'CO',   'Carbon Monoxide'
    };
    
    % Create input fields
    editFields = gobjects(6,1);
    for i = 1:6
        uilabel(fig, ...
               'Text', sprintf('%s (%s):', gases{i,1}, gases{i,2}), ...
               'Position', [20 350-35*i 120 22], ...
               'FontWeight', 'bold');
        
        editFields(i) = uieditfield(fig, 'numeric', ...
                                  'Position', [150 350-35*i 150 25], ...
                                  'Value', defaultValues(i), ...
                                  'Limits', [0 1000], ...
                                  'ValueDisplayFormat', '%.1f ppm');
    end
    
    % Temperature and Load
    uilabel(fig, 'Text', 'Temp (°C):', ...
           'Position', [20 350-35*7 120 22], ...
           'FontWeight', 'bold');
    
    tempField = uieditfield(fig, 'numeric', ...
                          'Position', [150 350-35*7 150 25], ...
                          'Value', defaultValues(7), ...
                          'Limits', [0 200]);
    
    uilabel(fig, 'Text', 'Load (%):', ...
           'Position', [20 350-35*8 120 22], ...
           'FontWeight', 'bold');
    
    loadField = uieditfield(fig, 'numeric', ...
                          'Position', [150 350-35*8 150 25], ...
                          'Value', defaultValues(8), ...
                          'Limits', [0 100]);
    
    % Prediction button
    uibutton(fig, 'push', ...
            'Text', 'PREDICT', ...
            'Position', [150 30 150 35], ...
            'ButtonPushedFcn', @(btn,event) app.manualPredictCallback(fig, editFields, tempField, loadField), ...
            'BackgroundColor', [0.15 0.35 0.65], ...
            'FontColor', 'white');
end
    
  function manualPredictCallback(app, fig, gasFields, tempField, loadField)
    try
        % Validate inputs
        gasLimits = [0 1000; 0 500; 0 300; 0 400; 0 100; 0 1000]; % H2 to CO
        for i = 1:6
            if gasFields(i).Value < gasLimits(i,1) || gasFields(i).Value > gasLimits(i,2)
                error('%s value out of range (%.1f-%.1f ppm)', ...
                    gasFields(i).Tooltip, gasLimits(i,1), gasLimits(i,2));
            end
        end
        
        % Prepare input data [H2, CH4, C2H6, C2H4, C2H2, Temp, Load]
        inputData = [
            gasFields(1).Value, ... % H2
            gasFields(2).Value, ... % CH4
            gasFields(3).Value, ... % C2H6
            gasFields(4).Value, ... % C2H4
            gasFields(5).Value, ... % C2H2
            tempField.Value, ...    % Temp
            loadField.Value ...     % Load
        ];
        
        % Get prediction
        [prediction, confidence, report] = app.predictFaultFromGases(inputData);
        
        % Update UI
        app.AIDiagnosisTextArea.Value = report;
        app.FaultTypeLabel.Text = sprintf('%s (%.1f%%)', prediction, confidence);
        
        % Set color based on fault type
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
    
    % Keep window open
    if isvalid(fig)
        uistack(fig, 'top');
    end
end


     function [prediction, confidence, report] = predictFaultFromGases(app, inputData)
    % Validate input
    if numel(inputData) ~= 7
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
                X = (inputData - app.SVM_Mean) ./ app.SVM_Std;
                
                % Predict
                [pred, ~, ~, decisionValues] = predict(app.TrainedModels.SVM.model, X);
                scores = 1./(1+exp(-decisionValues));
                confidence = max(scores) * 100;
                prediction = char(pred);
                
            case 'LSTM'
                % Normalize and format for LSTM
                XNorm = mapminmax('apply', inputData', app.TrainedModels.LSTM.normParams)';
                XCell = {XNorm'}; % Convert to cell with column vector
                
                % Predict
                [pred, scores] = classify(app.TrainedModels.LSTM.net, XCell);
                confidence = max(scores) * 100;
                prediction = char(pred);
                
            case 'CNN'
                % Normalize and reshape for CNN
                XNorm = (inputData - app.TrainedModels.CNN.min) ./ ...
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
        report = generateDiagnosisReport(app, prediction, confidence, inputData);
        
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
    gases = {'H2','CH4','C2H6','C2H4','C2H2'};
    report = [report sprintf('\nGAS CONCENTRATIONS:\n')];
    for i = 1:5
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
            if value < 10, interpretation = 'Normal';
            elseif value < 100, interpretation = 'Elevated';
            else, interpretation = 'High (Possible PD)';
            end
            
        case 'ch4'
            normalRange = '10-50 ppm';
            if value < 10, interpretation = 'Normal';
            elseif value < 50, interpretation = 'Elevated';
            else, interpretation = 'High (Possible T1/T2)'; end
            
        case 'c2h6'
            normalRange = '5-30 ppm';
            if value < 5, interpretation = 'Normal';
            elseif value < 30, interpretation = 'Elevated';
            else, interpretation = 'High (Possible T1)'; end
            
        case 'c2h4'
            normalRange = '5-50 ppm';
            if value < 5, interpretation = 'Normal';
            elseif value < 50, interpretation = 'Elevated';
            else, interpretation = 'High (Possible T2/T3)'; end
            
        case 'c2h2'
            normalRange = '0-5 ppm';
            if value < 1, interpretation = 'Normal';
            elseif value < 5, interpretation = 'Trace (Monitor)';
            else, interpretation = 'High (Possible D1/D2)';
            end
            
        otherwise
            normalRange = 'N/A';
            interpretation = 'N/A';
    end
end


        function updateStatus(app, message, color)
            % Update status bar with message and color
            app.StatusText.Text = message;
            app.StatusLamp.Color = color;
            drawnow;
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
                missingCols = setdiff(requiredCols, data.Properties.VariableNames);
                if ~isempty(missingCols)
                    error('Missing required columns: %s', strjoin(missingCols, ', '));
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
        
        function connectLiveData(app, ~, ~)
            % Connect to Arduino for live sensor data
            try
                % Check if serial port is already open
                if ~isempty(app.SerialObj) && isvalid(app.SerialObj) && strcmp(app.SerialObj.Status, 'open')
                    app.updateStatus('Already connected to live data', 'green');
                    return;
                end
                
                % List available serial ports
                ports = serialportlist("available");
                if isempty(ports)
                    error('No serial ports available. Check Arduino connection.');
                end
                
                % Try to connect to each port until successful
                connected = false;
                for i = 1:length(ports)
                    try
                        app.updateStatus(sprintf('Trying to connect to %s...', ports(i)), 'yellow');
                        
                        % Create serial port object
                        app.SerialObj = serialport(ports(i), 9600);
                        configureTerminator(app.SerialObj, "LF");
                        
                        % Set timeout
                        app.SerialObj.Timeout = 10;
                        
                        % Test connection
                        writeline(app.SerialObj, "TEST");
                        response = readline(app.SerialObj);
                        
                        if contains(response, "ARDUINO")
                            connected = true;
                            break;
                        else
                            delete(app.SerialObj);
                            app.SerialObj = [];
                        end
                    catch
                        if ~isempty(app.SerialObj) && isvalid(app.SerialObj)
                            delete(app.SerialObj);
                            app.SerialObj = [];
                        end
                    end
                end
                
                if connected
                    % Configure callback for data received
                    configureCallback(app.SerialObj, "terminator", @(src, ~)app.readLiveData(src));
                    app.updateStatus(sprintf('Connected to live data on %s', ports(i)), 'green');
                    app.LiveDataButton.Text = 'Disconnect Live Data';
                    app.LiveDataButton.BackgroundColor = [0.85, 0.33, 0.1]; % Orange color when connected
                else
                    error('Failed to connect to Arduino. Make sure it is sending "ARDUINO" on connection.');
                end
                
            catch ME
                if ~isempty(app.SerialObj) && isvalid(app.SerialObj)
                    delete(app.SerialObj);
                    app.SerialObj = [];
                end
                app.updateStatus(sprintf('Live data error: %s', ME.message), 'red');
                uialert(app.UIFigure, ME.message, 'Live Data Connection Error');
            end
        end
        
        function disconnectLiveData(app)
            % Disconnect from live data source
            try
                if ~isempty(app.SerialObj) && isvalid(app.SerialObj)
                    configureCallback(app.SerialObj, "off");
                    delete(app.SerialObj);
                    app.SerialObj = [];
                end
                app.LiveDataButton.Text = 'Connect Live Data';
                app.LiveDataButton.BackgroundColor = [0.47, 0.67, 0.19]; % Green color when disconnected
                app.updateStatus('Disconnected from live data', 'yellow');
            catch ME
                app.updateStatus(sprintf('Error disconnecting: %s', ME.message), 'red');
            end
        end
        
        function readLiveData(app, src)
            % Callback function for reading live data from Arduino
            try
                data = readline(src);
                
                % Parse the data (assuming format: "H2:val,CH4:val,C2H6:val,C2H4:val,C2H2:val,Temp:val,Load:val")
                try
                    % Remove any non-printable characters
                    data = regexprep(data, '[^ -~]', '');
                    
                    % Parse the data
                    pairs = split(data, ',');
                    newData = table('Size', [1, 7], 'VariableTypes', repmat({'double'}, 1, 7), ...
                        'VariableNames', {'h2', 'ch4', 'c2h6', 'c2h4', 'c2h2', 'temperature', 'load'});
                    
                    for i = 1:length(pairs)
                        kv = split(pairs{i}, ':');
                        if numel(kv) == 2
                            key = lower(strtrim(kv{1}));
                            value = str2double(kv{2});
                            
                            switch key
                                case 'h2'
                                    newData.h2 = value;
                                case 'ch4'
                                    newData.ch4 = value;
                                case 'c2h6'
                                    newData.c2h6 = value;
                                case 'c2h4'
                                    newData.c2h4 = value;
                                case 'c2h2'
                                    newData.c2h2 = value;
                                case 'temp'
                                    newData.temperature = value;
                                case 'load'
                                    newData.load = value;
                            end
                        end
                    end
                    
                    % Add timestamp
                    newData.Time = datetime('now');
                    
                    % Add to existing data
                    if isempty(app.TransformerData)
                        app.TransformerData = newData;
                    else
                        app.TransformerData = [app.TransformerData; newData];
                    end
                    
                    % Update UI
                    app.DataGrid.Data = app.TransformerData;
                    app.updateVisualizations();
                    
                    % Enable buttons if this is the first data
                    if height(app.TransformerData) == 1
                        app.TrainModelButton.Enable = 'on';
                        app.PredictButton.Enable = 'on';
                        app.GenerateReportButton.Enable = 'on';
                    end
                    
                    app.updateStatus(sprintf('Received live data at %s', datestr(newData.Time)), 'green');
                    
                catch parseErr
                    app.updateStatus(sprintf('Error parsing data: %s', parseErr.message), 'yellow');
                end
                
            catch ME
                app.updateStatus(sprintf('Live data error: %s', ME.message), 'red');
                app.disconnectLiveData();
            end
        end
        
        function generateReport(app, ~, ~)
            % Generate professional PDF report with guaranteed PDF opening
            app.updateStatus('Starting report generation...', [0 0.45 0.74]);
            app.ReportPreviewArea.Value = 'Initializing report generation...';
            drawnow;

            try
                % Create figure with enhanced layout
                fig = figure('Visible', 'off', 'Units', 'inches', ...
                             'Position', [0 0 8.5 11], 'Color', 'w', ...
                             'PaperPositionMode', 'auto');

                % ============ REPORT HEADER ============
                headerAx = axes(fig, 'Position', [0.1 0.94 0.8 0.06], 'Visible', 'off');
                text(headerAx, 0.5, 0.7, 'TRANSFORMER DIAGNOSTIC REPORT', ...
                     'FontSize', 18, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                     'Color', [0 0.45 0.74]);
                line(headerAx, [0 1], [0.1 0.1], 'Color', [0 0.45 0.74], 'LineWidth', 2);

                % ============ SYSTEM STATUS ============
                sectionAx = axes(fig, 'Position', [0.1 0.83 0.8 0.1], 'Visible', 'off');
                text(sectionAx, 0, 0.9, '1. SYSTEM STATUS', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

                cloudStatus = 'Offline';
                if isprop(app, 'CloudConnected') && app.CloudConnected
                    cloudStatus = 'Connected';
                end

                % Construct system overview text
                overviewText = {
                    sprintf('• Generated: %s', datestr(now, 'dd-mmm-yyyy HH:MM'));
                    sprintf('• Model Used: %s', app.ModelSelectionDropDown.Value);
                    sprintf('• Cloud Status: %s', cloudStatus)
                };
                text(sectionAx, 0, 0.5, overviewText, 'FontSize', 11, 'VerticalAlignment', 'top');

                % ============ FAULT ANALYSIS ============
                sectionAx = axes(fig, 'Position', [0.1 0.7 0.8 0.12], 'Visible', 'off');
                text(sectionAx, 0, 0.8, '2. FAULT ANALYSIS', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

                % Fixed fault text concatenation
                faultText = '• No faults detected';
                if isprop(app, 'FaultTypeLabel') && ~isempty(app.FaultTypeLabel.Text)
                    faultText = ['• Detected: ' app.FaultTypeLabel.Text];
                end
                text(sectionAx, 0, 0.5, faultText, 'FontSize', 11, 'VerticalAlignment', 'top');

                % ============ GAS ANALYSIS ============
                sectionAx = axes(fig, 'Position', [0.1 0.49 0.8 0.2], 'Visible', 'off');
                text(sectionAx, 0, 0.9, '3. GAS ANALYSIS (ppm)', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

                if ~isempty(app.TransformerData)
                    gases = {'H₂','CH₄','C₂H₆','C₂H₄','C₂H₂'};
                    vars = {'h2','ch4','c2h6','c2h4','c2h2'};
                    validVars = vars(ismember(vars, app.TransformerData.Properties.VariableNames));

                    gasText = {};
                    for i = 1:length(validVars)
                        gas = gases{strcmp(vars, validVars{i})};
                        value = app.TransformerData.(validVars{i})(end);
                        gasText{end+1} = sprintf('%-6s: %6.2f', gas, value);
                    end
                    text(sectionAx, 0, 0.5, gasText, 'FontSize', 11, 'FontName', 'FixedWidth', 'VerticalAlignment', 'top');
                else
                    text(sectionAx, 0, 0.5, 'No gas data available', 'FontSize', 11, 'VerticalAlignment', 'top');
                end

                % ============ AI DIAGNOSIS ============
                sectionAx = axes(fig, 'Position', [0.1 0.3 0.8 0.2], 'Visible', 'off');
                text(sectionAx, 0, 0.8, '4. AI DIAGNOSIS', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

                if ~isempty(app.AIDiagnosisTextArea.Value)
                    diagnosisText = strrep(app.AIDiagnosisTextArea.Value, '\n', newline);
                    text(sectionAx, 0, 0.5, diagnosisText, 'FontSize', 11, 'VerticalAlignment', 'top');
                else
                    text(sectionAx, 0, 0.5, 'No AI diagnosis available', 'FontSize', 11, 'VerticalAlignment', 'top');
                end

                % ============ FOOTER ============
                footerAx = axes(fig, 'Position', [0.1 0.02 0.8 0.05], 'Visible', 'off');
                text(footerAx, 0.5, 0.5, 'Confidential - Transformer Diagnostics System', ...
                     'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);

                % ============ RELIABLE PDF GENERATION ============
                timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                reportFile = fullfile(pwd, ['Transformer_Report_' timestamp '.pdf']);

                % Generate PDF with retry logic
                maxAttempts = 3;
                for attempt = 1:maxAttempts
                    try
                        exportgraphics(fig, reportFile, 'ContentType', 'vector', 'Resolution', 300);
                        break;
                    catch
                        if attempt == maxAttempts
                            rethrow(lasterror);
                        end
                        pause(1); % Wait before retrying
                    end
                end
                close(fig);

                % ============ GUARANTEED BROWSER OPENING ============
                app.updateStatus('Report generated - opening...', 'green');
                app.ReportPreviewArea.Value = sprintf(...
                    ['REPORT GENERATION SUCCESSFUL\n\n'...
                     'File: Transformer_Report_%s.pdf\n'...
                     'Location: %s\n\n'...
                     'The report should open automatically in your browser.'], ...
                    timestamp, pwd);

                % Robust PDF opening with multiple methods
                try
                    % Method 1: Direct system command
                    if ispc
                        system(['start "" "' reportFile '"']);
                    elseif ismac
                        system(['open "' reportFile '"']);
                    else
                        system(['xdg-open "' reportFile '"']);
                    end

                    % Verify file opened
                    pause(2); % Give time to open
                    if ~exist(reportFile, 'file')
                        error('File not found after generation');
                    end

                catch
                    try
                        % Method 2: MATLAB's web command
                        web(reportFile, '-browser');
                    catch
                        % Method 3: User instruction
                        app.ReportPreviewArea.Value = [app.ReportPreviewArea.Value ...
                            '\n\nCould not open automatically. Please manually open:\n' reportFile];
                    end
                end

            catch ME
                % Clean up figure if it exists
                if exist('fig', 'var') && ishandle(fig)
                    close(fig);
                end

                % Detailed error display
                errReport = sprintf(...
                    ['REPORT GENERATION FAILED\n\n'...
                     'Error: %s\n\n'...
                     'Location: %s\n'...
                     'Line: %d\n\n'...
                     'Immediate actions:\n'...
                     '1. Check disk space\n'...
                     '2. Verify PDF viewer is installed\n'...
                     '3. Contact support if persists'], ...
                    ME.message, ME.stack(1).name, ME.stack(1).line);

                app.updateStatus('Report generation failed', 'red');
                app.ReportPreviewArea.Value = errReport;
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
            % Update correlation heatmap visualization
            data = app.TransformerData;
            
            if isempty(data)
                return;
            end
            
            % Select numerical features for correlation
            numericalVars = {'h2','ch4','c2h6','c2h4','c2h2','temperature','load'};
            numericalVars = numericalVars(ismember(numericalVars, data.Properties.VariableNames));
            
            if length(numericalVars) < 2
                return;
            end
            
            corrData = data(:, numericalVars);
            corrMatrix = corr(table2array(corrData), 'Rows', 'complete');
            
            cla(app.CorrelationHeatmapAxes);
            imagesc(app.CorrelationHeatmapAxes, corrMatrix);
            colorbar(app.CorrelationHeatmapAxes);
            
            % Add correlation values
            [n, m] = size(corrMatrix);
            for i = 1:n
                for j = 1:m
                    text(app.CorrelationHeatmapAxes, j, i, sprintf('%.2f', corrMatrix(i,j)),...
                        'HorizontalAlignment', 'center', 'Color', 'w');
                end
            end
            
            % Set axis labels
            app.CorrelationHeatmapAxes.XTick = 1:length(numericalVars);
            app.CorrelationHeatmapAxes.XTickLabel = numericalVars;
            app.CorrelationHeatmapAxes.XTickLabelRotation = 45;
            app.CorrelationHeatmapAxes.YTick = 1:length(numericalVars);
            app.CorrelationHeatmapAxes.YTickLabel = numericalVars;
            
            title(app.CorrelationHeatmapAxes, 'Feature Correlation Matrix');
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
            
            % Gas concentrations
            cla(app.GasConcentrationAxes);
            gases = {'h2','ch4','c2h6','c2h4','c2h2'};
            colors = lines(length(gases));
            for i = 1:length(gases)
                if ismember(gases{i}, data.Properties.VariableNames)
                    plot(app.GasConcentrationAxes, data.(gases{i}), 'Color', colors(i,:), 'LineWidth', 1.5);
                    hold(app.GasConcentrationAxes, 'on');
                end
            end
            hold(app.GasConcentrationAxes, 'off');
            title(app.GasConcentrationAxes, 'Dissolved Gas Concentrations');
            legend(app.GasConcentrationAxes, gases);
            grid(app.GasConcentrationAxes, 'on');
            
            % Correlation heatmap
            app.updateCorrelationHeatmap();
            
            % Duval triangle
            app.updateDuvalTriangle();
        end
      
        function trainModel(app, ~, ~)
        % Train selected AI model using MATLAB built-in tools
        modelType = app.ModelSelectionDropDown.Value;
        data = app.TransformerData;
        
        % Check if data is available
        if isempty(data)
            app.updateStatus('No data available for training', 'red');
            return;
        end
        
        app.updateStatus(['Training ' modelType ' model...'], 'yellow');
        app.ProgressBar.Value = 20;
        
        try
            % Prepare data - extract relevant features
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
                case 'SVM'
                    % Standardize data (zero mean, unit variance)
                    app.SVM_Mean = mean(XTrain, 1);
                    app.SVM_Std = std(XTrain, 0, 1);
                    
                    % Handle any constant features (zero std)
                    app.SVM_Std(app.SVM_Std == 0) = 1;
                    
                    % Apply standardization
                    XTrainStd = (XTrain - app.SVM_Mean) ./ app.SVM_Std;
                    XValStd = (XVal - app.SVM_Mean) ./ app.SVM_Std;
                    
                    % Configure SVM with RBF kernel
                    svmTemplate = templateSVM(...
                        'KernelFunction', 'rbf', ...
                        'Standardize', false, ... % We standardize manually
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
                    
                    % Store trained model
                    app.TrainedModels.SVM = struct(...
                        'model', model, ...
                        'Accuracy', sum(predict(model, XValStd) == yVal)/numel(yVal), ...
                        'FeatureImportance', featureImp);
                    
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
                        %'ExecutionEnvironment', 'cpu');
                    
                    % Train model
                    net = trainNetwork(XTrainCNN, yTrain, layers, options);
                    
                    % Calculate feature importance
                    featureImp = app.calculateCNNFeatureImportance(net, XTrainCNN, yTrain);
                    
                    % Store trained model
                    app.TrainedModels.CNN = struct(...
                        'net', net, ...
                        'min', min(XTrain), ...
                        'max', max(XTrain), ...
                        'Accuracy', sum(classify(net, XValCNN) == yVal)/numel(yVal), ...
                        'FeatureImportance', featureImp);
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
        features = {'H2','CH4','C2H6','C2H4','C2H2','Temperature','Load'};
        
        % Handle NaN/invalid values
        if any(isnan(imp)) || all(imp == 0)
            imp = ones(1,7)/7; % Default equal importance
            text(app.FeatureImportanceAxes, 0.5, 0.3, ...
                'Using default importance values', ...
                'HorizontalAlignment', 'center');
        end
        
        % Sort features
        [sortedImp, idx] = sort(imp, 'descend');
        sortedFeatures = features(idx);
        
        % Create plot with minimum bar height
        minHeight = 0.01; % Ensure bars are always visible
        barValues = max(sortedImp, minHeight);
        
        bh = barh(app.FeatureImportanceAxes, barValues);
        bh.FaceColor = [0.2 0.4 0.8];
        bh.BarWidth = 0.8;
        
        % Configure axes
        app.FeatureImportanceAxes.YTick = 1:length(features);
        app.FeatureImportanceAxes.YTickLabel = sortedFeatures;
        app.FeatureImportanceAxes.YLim = [0.4 length(features)+0.6];
        app.FeatureImportanceAxes.XLim = [0 max(barValues)*1.1];
        title(app.FeatureImportanceAxes, 'Feature Importance');
        
        % Add value labels
        for i = 1:length(sortedImp)
            text(app.FeatureImportanceAxes, barValues(i)/2, i, ...
                sprintf('%.3f', sortedImp(i)), ...
                'Color', 'white', 'FontWeight', 'bold');
        end
        
    else
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

    if isempty(data) || ~istable(data) % Added ~istable check for robustness
        app.updateStatus('No data available or data is not a table for prediction', 'red');
        return;
    end

    % Ensure the model type is valid and exists in app.TrainedModels
    modelField = regexprep(modelType, '\s*\(Built-in\)', ''); % Clean up name if needed
    if ~isfield(app.TrainedModels, modelField)
        app.updateStatus(['No ' modelType ' model trained. Please train the model first.'], 'red');
        return;
    end

    app.updateStatus(['Running ' modelType ' predictions...'], 'yellow');
    app.ProgressBar.Value = 20;

    try
        % Prepare data
        featureNames = {'h2','ch4','c2h6','c2h4','c2h2','temperature','load'};
        if ~all(ismember(featureNames, data.Properties.VariableNames))
            missingCols = featureNames(~ismember(featureNames, data.Properties.VariableNames));
            error('Missing one or more required feature columns in data for prediction: %s', strjoin(missingCols, ', '));
        end
        X = table2array(data(:, featureNames));

        % Check for NaN or Inf values
        if any(~isfinite(X(:)))
            error('Data contains NaN or Inf values. Please clean your data first.');
        end

        % Get the trained model
        modelInfo = app.TrainedModels.(modelField); % Use modelField here for consistency

        % Initialize variables for prediction
        YPred = [];
        scores = [];

        switch modelType
            case 'LSTM'
                % --- IMPORTANT: Check for normalization parameters ---
                if ~isfield(modelInfo, 'normParams') || isempty(modelInfo.normParams)
                    error('LSTM normalization parameters (normParams) not found. Please retrain the LSTM model.');
                end

                % Normalize data using stored parameters
                % X is [numObservations x numFeatures] (e.g., 100 x 7)
                % mapminmax expects data in columns, so transpose X to [numFeatures x numObservations]
                XNorm = mapminmax('apply', X', modelInfo.normParams); % Output XNorm is now [numFeatures x numObservations]

                % Reshape for LSTM prediction: Create a cell array of sequences
                % Each cell should contain a [numFeatures x 1] column vector
                numObservations = size(XNorm, 2); % Now numObservations is the 2nd dim of XNorm

                % Add check if there are no observations to predict
                if numObservations == 0
                    app.updateStatus('No data points to predict after preparation.', 'red');
                    return;
                end

                XTestCell = cell(numObservations, 1);
                for i = 1:numObservations
                    XTestCell{i} = XNorm(:, i); % Each cell gets a (7x1) column vector
                end

                % Perform classification
                [YPred, scores] = classify(modelInfo.net, XTestCell);

            case 'SVM'
                    % Standardize data using stored parameters
                        if isempty(app.SVM_Mean) || isempty(app.SVM_Std)
                            error('SVM standardization parameters not found. Please retrain the SVM model.');
                        end
                        XStd = (X - app.SVM_Mean) ./ app.SVM_Std;
                        [YPred, ~, ~, decisionValues] = predict(modelInfo.model, XStd);
                        % Convert decision values to probabilities
                        scores = 1./(1+exp(-decisionValues));
                        scores = scores ./ sum(scores, 2);

            case 'CNN'
                % Normalize data
                if ~isfield(modelInfo, 'min') || ~isfield(modelInfo, 'max') || isempty(modelInfo.min) || isempty(modelInfo.max)
                    error('CNN normalization parameters not found. Please retrain the CNN model.');
                end
                rangeVal = modelInfo.max - modelInfo.min;
                rangeVal(rangeVal == 0) = 1; % Avoid division by zero for constant features
                XNorm = (X - modelInfo.min) ./ rangeVal;

                % Reshape for CNN [1, features, 1, samples]
                XTest = reshape(XNorm', [1, size(XNorm,2), 1, size(XNorm,1)]);
                [YPred, scores] = classify(modelInfo.net, XTest);
        end

        % --- Check if YPred is empty before accessing elements ---
        if isempty(YPred)
            app.updateStatus('Prediction resulted in empty output. No data to display.', 'red');
            return;
        end

        % Get confidence scores
        [maxScores, ~] = max(scores, [], 2);
        confidence = arrayfun(@(i) sprintf('%.1f%%', maxScores(i)*100), 1:size(scores,1), 'UniformOutput', false)';

        % Create results table
        results = table(YPred, confidence, 'VariableNames', {'Prediction', 'Confidence'});

        % Display detailed diagnosis for latest sample
        % Using featureNames for robustness in column names
        latestFeatures = array2table(X(end,:), 'VariableNames', featureNames); % X(end,:) assumes X is not empty
        
        % Assign latestPred and latestConfidence here, after YPred is confirmed not empty
        latestPred = YPred(end);
        latestConfidence = maxScores(end)*100;

        % Build diagnosis text
        diagnosisText = sprintf('%s Model Diagnosis:\n\n', modelType);
        diagnosisText = [diagnosisText sprintf('Predicted Fault: %s (%.1f%% confidence)\n\n', char(latestPred), latestConfidence)];
        diagnosisText = [diagnosisText 'Gas Concentrations (ppm):\n'];
        diagnosisText = [diagnosisText sprintf('  H2: %.2f\n', latestFeatures.h2)];
        diagnosisText = [diagnosisText sprintf('  CH4: %.2f\n', latestFeatures.ch4)];
        diagnosisText = [diagnosisText sprintf('  C2H6: %.2f\n', latestFeatures.c2h6)];
        diagnosisText = [diagnosisText sprintf('  C2H4: %.2f\n', latestFeatures.c2h4)];
        diagnosisText = [diagnosisText sprintf('  C2H2: %.2f\n\n', latestFeatures.c2h2)];
        diagnosisText = [diagnosisText sprintf('Operating Conditions:\n  Temperature: %.1f°C\n  Load: %.1f%%\n', ...
            latestFeatures.temperature, latestFeatures.load)];

        % Add recommended actions
        switch char(latestPred)
            case 'Normal'
                diagnosisText = [diagnosisText '\nRecommendation: Continue regular monitoring'];
            case 'D1'
                diagnosisText = [diagnosisText '\nRecommendation: Check for partial discharge'];
            case 'D2'
                diagnosisText = [diagnosisText '\nRecommendation: Inspect for high energy discharge'];
            case 'T1'
                diagnosisText = [diagnosisText '\nRecommendation: Check for thermal faults <300°C'];
            case 'T2'
                diagnosisText = [diagnosisText '\nRecommendation: Inspect for thermal faults >700°C'];
            case 'PD'
                diagnosisText = [diagnosisText '\nRecommendation: Investigate partial discharge sources'];
        end

        % Update UI
        app.AIDiagnosisTextArea.Value = diagnosisText;
        app.ProgressBar.Value = 100;
        app.updateStatus([modelType ' predictions completed'], 'green');

    catch ME
        app.ProgressBar.Value = 0;
        app.updateStatus(['Prediction error: ' ME.message], 'red');
        uialert(app.UIFigure, ME.message, 'Prediction Error');

        % Display error details
        app.AIDiagnosisTextArea.Value = sprintf(...
            'Prediction failed:\n\nError: %s\n\nStack Trace:\n%s', ...
            ME.message, ...
            getReport(ME, 'extended', 'hyperlinks', 'off'));
    end
end


        function connectToCloud(app, ~, ~)
            app.updateStatus('Testing cloud connection...', 'yellow');
            
            try
                app.CloudEndpoint = app.CloudURLEditField.Value;
                app.APIKey = app.APIKeyEditField.Value;

                if isempty(app.CloudEndpoint) || isempty(app.APIKey)
                    error('URL and API key are required');
                end

                options = weboptions(...
                    'HeaderFields', {'X-API-KEY', app.APIKey}, ...
                    'Timeout', 120);

                response = webread([app.CloudEndpoint '/api/atlas/status'], options);

                if isfield(response, 'status') && strcmp(response.status, 'success')
                    app.CloudConnected = true;
                    app.CloudStatusLamp.Color = 'green';
                    app.updateStatus('Connected to cloud service', 'green');
                    app.SaveToCloudButton.Enable = 'on';
                else
                    error('Connection test failed');
                end

            catch ME
                app.CloudConnected = false;
                app.CloudStatusLamp.Color = 'red';
                app.updateStatus(['Connection failed: ' ME.message], 'red');
            end
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
    end
    
 methods (Access = public)
        
        % App initialization and construction
        function app = TransformerDiagnosticApp
            % Create and configure components
            createComponents(app);
            
            % Initialize properties
            app.LastDataPath = pwd;
            app.PlotLimits = struct();
            app.TrainedModels = struct();
            app.TrainingFigure = [];
            app.TrainingAxes1 = [];
            app.TrainingAxes2 = [];
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
            app.LiveDataButton = uibutton(app.DataTab, 'push');
            app.LiveDataButton.Position = [430 40 150 30];
            app.LiveDataButton.Text = 'Connect Live Data';
            app.LiveDataButton.BackgroundColor = [0.47, 0.67, 0.19]; % Green color
            app.LiveDataButton.Tooltip = 'Connect to Arduino for live sensor data';
            
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
        end
      
    
        function closeApp(app, ~)
    % Close request function - confirm before exiting
    selection = uiconfirm(app.UIFigure,...
        'Are you sure you want to close the application?',...
        'Confirm Close',...
        'Options', {'Yes', 'No'},...
        'DefaultOption', 2);
    
    if strcmp(selection, 'Yes')
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
            app = TransformerDiagnosticApp;
        end
    end
end
