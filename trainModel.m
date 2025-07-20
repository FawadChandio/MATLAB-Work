```matlab
classdef TransformerDiagnosticApp2 < matlab.apps.AppBase
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
        LiveDataButton          matlab.ui.control.Button % New button for live data
        
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
        ReportTab               matlab.ui.container.Tab
        GenerateReportButton    matlab.ui.control.Button
        ReportPreviewArea       matlab.ui.control.TextArea
        % Prediction
        ManualPredictButton     matlab.ui.control.Button
    end
    
    properties (Access = private)
        TransformerData table               % Stores loaded transformer data
        TrainedModels struct                % Stores trained AI models
        CloudConnected logical = false      % Cloud connection status
        LastDataPath char                   % Last used data path
        PlotLimits struct                   % Stores plot axis limits
        CloudEndpoint = 'http://localhost:8000';
        APIKey char = 'sk-proj-t8E6ZiVlOHTUM_GIi3vTyFqfIsCnOqBbfZz3dllZYBmhxiUR' % API key storage
        TrainingProgress struct             % Stores training progress data
        SerialObj = []                      % Serial connection object for live data
    end
    
    methods (Access = public)
        function app = TransformerDiagnosticApp2
            % Construct and initialize the app
            % Create UIFigure and components
            createComponents(app)
            
            % Register the app with App Designer
            registerApp(app, app.UIFigure)
            
            % Execute startup function
            startupFcn(app)
            
            if nargout == 0
                clear app
            end
        end
    end
    
    methods (Access = private)
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 680];
            app.UIFigure.Name = 'Transformer Diagnostic System';
            app.UIFigure.CloseRequestFcn = @(src, evt) closeFcn(app);
            
            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [20 100 1160 560];
            
            % Create DataTab
            app.DataTab = uitab(app.TabGroup);
            app.DataTab.Title = 'Data';
            
            % Create DataGrid
            app.DataGrid = uitable(app.DataTab);
            app.DataGrid.Position = [20 80 800 400];
            
            % Create LoadDataButton
            app.LoadDataButton = uibutton(app.DataTab, 'push');
            app.LoadDataButton.ButtonPushedFcn = @(btn, evt) loadDataFromFile(app);
            app.LoadDataButton.Position = [840 450 100 30];
            app.LoadDataButton.Text = 'Load Data';
            
            % Create ClearDataButton
            app.ClearDataButton = uibutton(app.DataTab, 'push');
            app.ClearDataButton.ButtonPushedFcn = @(btn, evt) clearData(app);
            app.ClearDataButton.Position = [960 450 100 30];
            app.ClearDataButton.Text = 'Clear Data';
            
            % Create DataFormatDropDown
            app.DataFormatDropDown = uidropdown(app.DataTab);
            app.DataFormatDropDown.Items = {'Standard DGA', 'IEEE Format', 'Custom'};
            app.DataFormatDropDown.Position = [840 400 220 30];
            app.DataFormatDropDown.Value = 'Standard DGA';
            
            % Create LiveDataButton
            app.LiveDataButton = uibutton(app.DataTab, 'push');
            app.LiveDataButton.ButtonPushedFcn = @(btn, evt) connectLiveData(app);
            app.LiveDataButton.Position = [840 350 220 30];
            app.LiveDataButton.Text = 'Connect Live Data';
            app.LiveDataButton.BackgroundColor = [0.47 0.67 0.19];
            
            % Create TransformerInfoPanel
            app.TransformerInfoPanel = uipanel(app.DataTab);
            app.TransformerInfoPanel.Title = 'Transformer Info';
            app.TransformerInfoPanel.Position = [840 80 220 250];
            
            % Create VisualizationTab
            app.VisualizationTab = uitab(app.TabGroup);
            app.VisualizationTab.Title = 'Visualization';
            
            % Create TimeSeriesAxes
            app.TimeSeriesAxes = uiaxes(app.VisualizationTab);
            app.TimeSeriesAxes.Position = [20 280 500 200];
            title(app.TimeSeriesAxes, 'Temperature and Load Over Time');
            
            % Create GasConcentrationAxes
            app.GasConcentrationAxes = uiaxes(app.VisualizationTab);
            app.GasConcentrationAxes.Position = [540 280 600 200];
            title(app.GasConcentrationAxes, 'Dissolved Gas Concentrations');
            
            % Create CorrelationHeatmapAxes
            app.CorrelationHeatmapAxes = uiaxes(app.VisualizationTab);
            app.CorrelationHeatmapAxes.Position = [20 80 500 180];
            title(app.CorrelationHeatmapAxes, 'Feature Correlation Matrix');
            
            % Create FaultDetectionTab
            app.FaultDetectionTab = uitab(app.TabGroup);
            app.FaultDetectionTab.Title = 'Fault Detection';
            
            % Create DuvalTriangleAxes
            app.DuvalTriangleAxes = uiaxes(app.FaultDetectionTab);
            app.DuvalTriangleAxes.Position = [20 80 500 400];
            title(app.DuvalTriangleAxes, 'Duval Triangle Analysis');
            
            % Create RogersRatioPanel
            app.RogersRatioPanel = uipanel(app.FaultDetectionTab);
            app.RogersRatioPanel.Title = 'Rogers Ratio Analysis';
            app.RogersRatioPanel.Position = [540 280 600 200];
            
            % Create KeyGasPanel
            app.KeyGasPanel = uipanel(app.FaultDetectionTab);
            app.KeyGasPanel.Title = 'Key Gas Analysis';
            app.KeyGasPanel.Position = [540 80 600 180];
            
            % Create FaultTypeLabel
            app.FaultTypeLabel = uilabel(app.FaultDetectionTab);
            app.FaultTypeLabel.Position = [20 480 500 30];
            app.FaultTypeLabel.Text = 'No fault detected';
            app.FaultTypeLabel.FontSize = 16;
            
            % Create AITab
            app.AITab = uitab(app.TabGroup);
            app.AITab.Title = 'AI Analysis';
            
            % Create ModelSelectionDropDown
            app.ModelSelectionDropDown = uidropdown(app.AITab);
            app.ModelSelectionDropDown.Position = [20 450 200 30];
            
            % Create TrainModelButton
            app.TrainModelButton = uibutton(app.AITab, 'push');
            app.TrainModelButton.ButtonPushedFcn = @(btn, evt) trainModel(app);
            app.TrainModelButton.Position = [240 450 100 30];
            app.TrainModelButton.Text = 'Train Model';
            
            % Create PredictButton
            app.PredictButton = uibutton(app.AITab, 'push');
            app.PredictButton.ButtonPushedFcn = @(btn, evt) predictWithModel(app);
            app.PredictButton.Position = [360 450 100 30];
            app.PredictButton.Text = 'Predict';
            
            % Create ManualPredictButton
            app.ManualPredictButton = uibutton(app.AITab, 'push');
            app.ManualPredictButton.ButtonPushedFcn = @(btn, evt) openManualPredictor(app);
            app.ManualPredictButton.Position = [480 450 100 30];
            app.ManualPredictButton.Text = 'Manual Predict';
            
            % Create PerformanceAxes
            app.PerformanceAxes = uiaxes(app.AITab);
            app.PerformanceAxes.Position = [20 280 560 160];
            title(app.PerformanceAxes, 'Model Performance');
            
            % Create FeatureImportanceAxes
            app.FeatureImportanceAxes = uiaxes(app.AITab);
            app.FeatureImportanceAxes.Position = [600 280 560 160];
            title(app.FeatureImportanceAxes, 'Feature Importance');
            
            % Create AIDiagnosisTextArea
            app.AIDiagnosisTextArea = uitextarea(app.AITab);
            app.AIDiagnosisTextArea.Position = [20 80 1140 180];
            
            % Create CloudTab
            app.CloudTab = uitab(app.TabGroup);
            app.CloudTab.Title = 'Cloud Integration';
            
            % Create CloudConnectButton
            app.CloudConnectButton = uibutton(app.CloudTab, 'push');
            app.CloudConnectButton.ButtonPushedFcn = @(btn, evt) connectToCloud(app);
            app.CloudConnectButton.Position = [20 450 100 30];
            app.CloudConnectButton.Text = 'Connect';
            
            % Create SaveToCloudButton
            app.SaveToCloudButton = uibutton(app.CloudTab, 'push');
            app.SaveToCloudButton.ButtonPushedFcn = @(btn, evt) saveToCloud(app);
            app.SaveToCloudButton.Position = [140 450 100 30];
            app.SaveToCloudButton.Text = 'Save to Cloud';
            
            % Create RealTimeDataSwitch
            app.RealTimeDataSwitch = uiswitch(app.CloudTab, 'toggle');
            app.RealTimeDataSwitch.ValueChangedFcn = @(src, evt) realTimeCloudSwitch(app, src);
            app.RealTimeDataSwitch.Position = [260 450 60 30];
            app.RealTimeDataSwitch.Items = {'Off', 'On'};
            
            % Create CloudStatusLamp
            app.CloudStatusLamp = uilamp(app.CloudTab);
            app.CloudStatusLamp.Position = [340 450 20 20];
            app.CloudStatusLamp.Color = [1 0 0];
            
            % Create CloudURLEditField
            app.CloudURLEditField = uieditfield(app.CloudTab, 'text');
            app.CloudURLEditField.Position = [20 400 300 30];
            app.CloudURLEditField.Value = app.CloudEndpoint;
            
            % Create APIKeyEditField
            app.APIKeyEditField = uieditfield(app.CloudTab, 'text');
            app.APIKeyEditField.Position = [20 350 300 30];
            app.APIKeyEditField.Value = app.APIKey;
            
            % Create ReportTab
            app.ReportTab = uitab(app.TabGroup);
            app.ReportTab.Title = 'Report';
            
            % Create GenerateReportButton
            app.GenerateReportButton = uibutton(app.ReportTab, 'push');
            app.GenerateReportButton.ButtonPushedFcn = @(btn, evt) generateReport(app);
            app.GenerateReportButton.Position = [20 450 100 30];
            app.GenerateReportButton.Text = 'Generate Report';
            
            % Create ReportPreviewArea
            app.ReportPreviewArea = uitextarea(app.ReportTab);
            app.ReportPreviewArea.Position = [20 80 1140 360];
            app.ReportPreviewArea.Value = 'Report preview will appear here after generation';
            
            % Create StatusText
            app.StatusText = uilabel(app.UIFigure);
            app.StatusText.Position = [20 20 800 30];
            app.StatusText.Text = 'Ready';
            
            % Create StatusLamp
            app.StatusLamp = uilamp(app.UIFigure);
            app.StatusLamp.Position = [840 20 20 20];
            app.StatusLamp.Color = [0 1 0];
            
            % Create ProgressBar
            app.ProgressBar = uigauge(app.UIFigure, 'linear');
            app.ProgressBar.Position = [880 20 300 30];
            app.ProgressBar.Limits = [0 100];
            app.ProgressBar.Value = 0;
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
        
        function startupFcn(app)
            % Initialize the app
            app.updateStatus('Initializing Transformer Diagnostic System...', 'yellow');
            
            % Initialize data structures
            app.TransformerData = table();
            app.TrainedModels = struct();
            app.TrainingProgress = struct('Epoch', [], 'TrainingAccuracy', [], ...
                'ValidationAccuracy', [], 'TrainingLoss', [], 'ValidationLoss', []);
            app.PlotLimits = struct();
            
            % Set default UI states
            app.TrainModelButton.Enable = 'off';
            app.PredictButton.Enable = 'off';
            app.SaveToCloudButton.Enable = 'off';
            app.GenerateReportButton.Enable = 'off';
            app.ManualPredictButton.Enable = 'off';
            
            % Populate model selection dropdown
            app.ModelSelectionDropDown.Items = {'SVM', 'LSTM', 'CNN'};
            
            % Initialize visualizations
            app.updateVisualizations();
            
            app.updateStatus('Ready', 'green');
        end
        
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
            defaultValues = [50 120 66 80 5 360 500 25 75 85]; % [H2 CH4 C2H6 C2H4 C2H2 CO CO2 H2O Temp Load]
            
            % Gas data configuration - includes all 8 gases
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
            editFields = gobjects(8,1);
            for i = 1:8
                uilabel(fig, ...
                       'Text', sprintf('%s (%s):', gases{i,1}, gases{i,2}), ...
                       'Position', [20 500-35*i 120 22], ...
                       'FontWeight', 'bold');
                
                editFields(i) = uieditfield(fig, 'numeric', ...
                                          'Position', [150 500-35*i 150 25], ...
                                          'Value', defaultValues(i));
            end
            
            % Temperature and Load
            uilabel(fig, 'Text', 'Temp (°C):', ...
                   'Position', [20 500-35*9 120 22], ...
                   'FontWeight', 'bold');
            
            tempField = uieditfield(fig, 'numeric', ...
                                  'Position', [150 500-35*9 150 25], ...
                                  'Value', defaultValues(9));
            
            uilabel(fig, 'Text', 'Load (%):', ...
                   'Position', [20 500-35*10 120 22], ...
                   'FontWeight', 'bold');
            
            loadField = uieditfield(fig, 'numeric', ...
                                  'Position', [150 500-35*10 150 25], ...
                                  'Value', defaultValues(10));
            
            % Prediction button (uses all 8 gases + temp/load)
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
                gasLimits = [0 1000; 0 500; 0 300; 0 400; 0 100; 0 2000; 0 5000; 0 100]; % H2 to H2O
                for i = 1:8
                    if gasFields(i).Value < gasLimits(i,1) || gasFields(i).Value > gasLimits(i,2)
                        error('%s value out of range (%.1f-%.1f ppm)', ...
                            gasFields(i).Tooltip, gasLimits(i,1), gasLimits(i,2));
                    end
                end
                
                % Prepare input data [H2, CH4, C2H6, C2H4, C2H2, CO, CO2, H2O, Temp, Load]
                inputData = [
                    gasFields(1).Value, ... 
                    gasFields(2).Value, ... 
                    gasFields(3).Value, ... 
                    gasFields(4).Value, ... 
                    gasFields(5).Value, ... 
                    gasFields(6).Value, ... 
                    gasFields(7).Value, ... 
                    gasFields(8).Value, ... 
                    tempField.Value, ...    
                    loadField.Value ...    
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
            if numel(inputData) ~= 10
                error('Input must contain exactly 10 values');
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
                        XCell = {XNorm'};
                        
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
            gases = {'H2','CH4','C2H6','C2H4','C2H2','CO','CO2','H2O'};
            report = [report sprintf('\nGAS CONCENTRATIONS:\n')];
            for i = 1:8
                [normalRange, interpretation] = app.getGasInterpretation(gases{i}, inputData(i));
                report = [report sprintf('  %-5s: %6.1f ppm (Normal: %-10s %s)\n', ...
                    gases{i}, inputData(i), normalRange, interpretation)];
            end
            
            % Operating conditions
            report = [report sprintf('\nOPERATING CONDITIONS:\n')];
            report = [report sprintf('  Temperature: %.1f°C\n', inputData(9))];
            report = [report sprintf('  Load:        %.1f%%\n')];
            
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
                    if value < 1, interpretation = 'Normal';
                    elseif value < 50, interpretation = 'Elevated';
                    else, interpretation = 'High (Possible T1/T2)';
                    end
                    
                case 'c2h6'
                    normalRange = '5-30 ppm';
                    if value < 5, interpretation = 'Normal';
                    elseif value < 30, interpretation = 'Elevated';
                    else, interpretation = 'High (Possible T1)';
                    end
                    
                case 'c2h4'
                    normalRange = '5-50 ppm';
                    if value < 5, interpretation = 'Normal';
                    elseif value < 50, interpretation = 'Elevated';
                    else, interpretation = 'High (Possible T2/T3)';
                    end
                    
                case 'c2h2'
                    normalRange = '0-5 ppm';
                    if value < 1, interpretation = 'Normal';
                    elseif value < 5, interpretation = 'Trace (Monitor)';
                    else, interpretation = 'High (Possible D1/D2)';
                    end
                    
                case 'co'
                    normalRange = '50-700 ppm';
                    if value < 50, interpretation = 'Low';
                    elseif value < 700, interpretation = 'Normal';
                    else, interpretation = 'High (Possible Cellulose Degradation)';
                    end
                    
                case 'co2'
                    normalRange = '500-4000 ppm';
                    if value < 500, interpretation = 'Low';
                    elseif value < 4000, interpretation = 'Normal';
                    else, interpretation = 'High (Possible Cellulose Degradation)';
                    end
                    
                case 'h2o'
                    normalRange = '0-30 ppm';
                    if value < 10, interpretation = 'Dry';
                    elseif value < 30, interpretation = 'Normal';
                    else, interpretation = 'Wet (Possible Insulation Issue)';
                    end
                    
                otherwise
                    normalRange = 'N/A';
                    interpretation = 'N/A';
            end
        end
        
        function updateStatus(app, message, color)
            % Update status bar with message and color
            app.StatusText.Text = message;
            if ischar(color)
                switch lower(color)
                    case 'red'
                        app.StatusLamp.Color = [1 0 0];
                    case 'yellow'
                        app.StatusLamp.Color = [1 1 0];
                    case 'green'
                        app.StatusLamp.Color = [0 1 0];
                    otherwise
                        app.StatusLamp.Color = str2num(color);
                end
            else
                app.StatusLamp.Color = color;
            end
            drawnow;
        end
        
        function loadDataFromFile(app, ~, ~)
            % Load transformer data from file with improved file selection
            fileFormats = {
                '*.csv', 'CSV Files (*.csv)';
                '*.xlsx;*.txt', 'Excel/TXT files (*.xlsx, *.txt)';
                '*.mat', 'MAT files (*.mat)';
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
                                opts.VariableNames = {'H2','CH4','C2H6','C2H4','C2H2','CO','CO2','H2O','Temperature','Load'};
                                opts.VariableTypes = repmat({'double'}, 1, 10);
                            case 'IEEE Format'
                                opts.VariableNames = {'Date','H2','CH4','C2H6','C2H4','C2H2','CO','CO2','H2O','Temperature','Load'};
                                opts.VariableTypes = {'datetime','double','double','double','double','double','double','double','double','double','double'};
                            case 'Custom'
                                % Use detected import options
                        end
                        data = readtable(fullPath, opts);
                        
                    case {'.xlsx', '.txt'}
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
                requiredCols = {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load'};
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
                        app.updateStatus(sprintf('Replaced %d invalid values in %s with median %.1f', sum(invalid), col{1}, medianVal), 'yellow');
                    end
                end
                
                % Calculate gas ratios if not present
                if ~ismember('ratio_ch4_h2', data.Properties.VariableNames)
                    data.ratio_ch4_h2 = data.ch4 ./ max(data.h2, eps);
                end
                if ~ismember('ratio_c2h4_c2h6', data.Properties.VariableNames)
                    data.ratio_c2h4_c2h6 = data.c2h4 ./ max(data.c2h6, eps);
                end
                if ~ismember('ratio_c2h2_c2h4', data.Properties.VariableNames)
                    data.ratio_c2h2_c2h4 = data.c2h2 ./ max(data.c2h4, eps);
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
                    app.LiveDataButton.BackgroundColor = [0.85 0.33 0.1]; % Orange color when connected
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
                app.LiveDataButton.BackgroundColor = [0.47 0.67 0.19]; % Green color when disconnected
                app.updateStatus('Disconnected from live data', 'yellow');
            catch ME
                app.updateStatus(sprintf('Error disconnecting: %s', ME.message), 'red');
            end
        end
        
        function readLiveData(app, src)
            % Callback function for reading live data from Arduino
            try
                data = readline(src);
                
                % Parse the data (assuming format: "H2:val,CH4:val,C2H6:val,C2H4:val,C2H2:val,CO:val,CO2:val,H2O:val,Temp:val,Load:val")
                try
                    % Remove any non-printable characters
                    data = regexprep(data, '[^ -~]', '');
                    
                    % Parse the data
                    pairs = split(data, ',');
                    newData = table('Size', [1, 10], 'VariableTypes', repmat({'double'}, 1, 10), ...
                        'VariableNames', {'h2', 'ch4', 'c2h6', 'c2h4', 'c2h2', 'co', 'co2', 'h2o', 'temperature', 'load'});
                    
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
                                case 'co'
                                    newData.co = value;
                                case 'co2'
                                    newData.co2 = value;
                                case 'h2o'
                                    newData.h2o = value;
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
            % Generate professional PDF report with all 8 gases displayed
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
                if app.CloudConnected
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
                
                faultText = '• No faults detected';
                if ~isempty(app.FaultTypeLabel.Text)
                    faultText = ['• Detected: ' app.FaultTypeLabel.Text];
                end
                text(sectionAx, 0, 0.5, faultText, 'FontSize', 11, 'VerticalAlignment', 'top');
                
                % ============ GAS ANALYSIS ============
                sectionAx = axes(fig, 'Position', [0.1 0.49 0.8 0.2], 'Visible', 'off');
                text(sectionAx, 0, 0.9, '3. GAS ANALYSIS (ppm)', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
                
                if ~isempty(app.TransformerData)
                    % All gases to display
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
                        if ismember(vars{i}, validVars)
                            gas = gases{strcmp(vars, vars{i}), 1};
                            value = app.TransformerData.(vars{i})(end);
                            gasText{end+1} = sprintf('%-6s: %6.2f ppm', gas, value);
                        else
                            gas = gases{strcmp(vars, vars{i}), 1};
                            gasText{end+1} = sprintf('%-6s: %6s ppm', gas, 'N/A');
                        end
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
                
                % ============ MODEL PERFORMANCE ============
                sectionAx = axes(fig, 'Position', [0.1 0.15 0.8 0.15], 'Visible', 'off');
                text(sectionAx, 0, 0.9, '5. MODEL PERFORMANCE', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
                
                modelField = regexprep(app.ModelSelectionDropDown.Value, '\s*\(Built-in\)', '');
                if isfield(app.TrainedModels, modelField)
                    model = app.TrainedModels.(modelField);
                    perfText = {
                        sprintf('Model Type: %s', app.ModelSelectionDropDown.Value);
                        sprintf('Validation Accuracy: %.1f%%', model.Accuracy*100);
                        sprintf('Training Date: %s', datestr(now, 'dd-mmm-yyyy'))
                    };
                    text(sectionAx, 0, 0.5, perfText, 'FontSize', 11, 'VerticalAlignment', 'top');
                else
                    text(sectionAx, 0, 0.5, 'No trained model available', 'FontSize', 11, 'VerticalAlignment', 'top');
                end
                
                % ============ FOOTER ============
                footerAx = axes(fig, 'Position', [0.1 0.02 0.8 0.05], 'Visible', 'off');
                text(footerAx, 0.5, 0.5, 'Confidential - Transformer Diagnostics System', ...
                     'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
                
                % ============ PDF GENERATION ============
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
                        pause(1);
                    end
                end
                close(fig);
                
                % ============ OPEN PDF ============
                app.updateStatus('Report generated - opening...', 'green');
                app.ReportPreviewArea.Value = sprintf(...
                    ['REPORT GENERATION SUCCESSFUL\n\n'...
                     'File: Transformer_Report_%s.pdf\n'...
                     'Location: %s\n\n'...
                     'The report should open automatically in your browser.'], ...
                    timestamp, pwd);
                
                % Try multiple methods to open the PDF
                try
                    if ispc
                        system(['start "" "' reportFile '"']);
                    elseif ismac
                        system(['open "' reportFile '"']);
                    else
                        system(['xdg-open "' reportFile '"']);
                    end
                    pause(2);
                catch
                    try
                        web(reportFile, '-browser');
                    catch
                        app.ReportPreviewArea.Value = [app.ReportPreviewArea.Value ...
                            '\n\nCould not open automatically. Please manually open:\n' reportFile];
                    end
                end
                
            catch ME
                if exist('fig', 'var') && ishandle(fig)
                    close(fig);
                end
                
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
            if p_C2H2 > 23
                if p_CH4 < 23
                    faultType = 'D1 (Partial Discharge)';
                    color = [0 0 0.8];
                elseif p_CH4 < 40
                    faultType = 'D2 (Discharge of High Energy)';
                    color = [0.2 0.2 1];
                else
                    faultType = 'D2 (Discharge of Low Energy)';
                    color = [0.4 0.4 1];
                end
            elseif p_CH4 > 98
                faultType = 'T3 (Thermal >700°C)';
                color = [0 0.5 0];
            elseif p_CH4 > 50
                if p_H2 < 15
                    faultType = 'T2 (Thermal 300°C < T ≤ 700°C)';
                    color = [0 0.7 0];
                else
                    faultType = 'T2 (Thermal with H2)';
                    color = [0.2 0.8 0.2];
                end
            elseif p_CH4 > 25
                faultType = 'T1 (Thermal <300°C)';
                color = [0.93 0.69 0.13];
            elseif p_H2 > 98
                faultType = 'PD (Partial Discharge)';
                color = [0.8 0 0];
            elseif p_H2 > 50
                faultType = 'PD (Partial Discharge with CH4)';
                color = [1 0.2 0.2];
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
            
            text(app.DuvalTriangleAxes, 110, 80, infoText, ...
                'FontSize', 10, 'VerticalAlignment', 'top');
            
            hold(app.DuvalTriangleAxes, 'off');
            axis(app.DuvalTriangleAxes, 'equal');
            axis(app.DuvalTriangleAxes, [0 100 0 100*sind(60)]);
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
            
            % All possible variables including all gases
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
            
            % Check for constant columns
            constCols = var(dataArray, 0, 1) == 0;
            if any(constCols)
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
            
            % Handle any remaining NaN values
            if any(isnan(corrMatrix(:)))
                corrMatrix(isnan(corrMatrix)) = 0;
                warning('Some correlations could not be computed (insufficient data)');
            end
            
            % Create heatmap
            cla(app.CorrelationHeatmapAxes);
            imagesc(app.CorrelationHeatmapAxes, corrMatrix);
            colormap(app.CorrelationHeatmapAxes, 'jet');
            colorbar(app.CorrelationHeatmapAxes);
            
            % Add correlation values
            [n, ~] = size(corrMatrix);
            for i = 1:n
                for j = 1:n
                    text(app.CorrelationHeatmapAxes, j, i, sprintf('%.2f', corrMatrix(i,j)),...
                        'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 8);
                end
            end
            
            % Configure axes
            app.CorrelationHeatmapAxes.XTick = 1:length(availableVars);
            app.CorrelationHeatmapAxes.XTickLabel = displayNames;
            app.CorrelationHeatmapAxes.XTickLabelRotation = 45;
            app.CorrelationHeatmapAxes.YTick = 1:length(availableVars);
            app.CorrelationHeatmapAxes.YTickLabel = displayNames;
            
            title(app.CorrelationHeatmapAxes, 'Feature Correlation Matrix');
            clim(app.CorrelationHeatmapAxes, [-1 1]);
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
                plot(app.TimeSeriesAxes, 1:height(data), data.temperature, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Temperature');
                hold(app.TimeSeriesAxes, 'on');
                plot(app.TimeSeriesAxes, 1:height(data), data.load, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Load');
                hold(app.TimeSeriesAxes, 'off');
                title(app.TimeSeriesAxes, 'Temperature and Load Over Time');
                legend(app.TimeSeriesAxes, 'show', 'Location', 'best');
                grid(app.TimeSeriesAxes, 'on');
                xlabel(app.TimeSeriesAxes, 'Sample Index');
            end
            
            % Gas concentration plot
            cla(app.GasConcentrationAxes);
            gases = {
                'h2',   'H₂',   [0 0.4470 0.7410];
                'ch4',  'CH₄',  [0.8500 0.3250 0.0980];
                'c2h6', 'C₂H₆', [0.9290 0.6940 0.1250];
                'c2h4', 'C₂H₄', [0.4940 0.1840 0.5560];
                'c2h2', 'C₂H₂', [0.4660 0.6740 0.1880];
                'co',   'CO',   [0.3010 0.7450 0.9330];
                'co2',  'CO₂',  [0.6350 0.0780 0.1840];
                'h2o',  'H₂O',  [0.25 0.25 0.25]
            };
            
            legendEntries = {};
            for i = 1:size(gases,1)
                gas = gases{i,1};
                if ismember(gas, data.Properties.VariableNames)
                    plot(app.GasConcentrationAxes, 1:height(data), data.(gas), 'Color', gases{i,3}, 'LineWidth', 1.5);
                    hold(app.GasConcentrationAxes, 'on');
                    legendEntries{end+1} = gases{i,2};
                end
            end
            hold(app.GasConcentrationAxes, 'off');
            
            title(app.GasConcentrationAxes, 'Dissolved Gas Concentrations');
            legend(app.GasConcentrationAxes, legendEntries, 'Location', 'northeastoutside');
            ylabel(app.GasConcentrationAxes, 'Concentration (ppm)');
            xlabel(app.GasConcentrationAxes, 'Sample Index');
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
                % Prepare data - extract all features
                X = table2array(data(:, {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load'}));
                
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
                        XTrainNorm = XTrainNorm';
                        
                        XValNorm = mapminmax('apply', XVal', normParams)';
                        
                        % Convert to Nx1 cell array of sequences
                        numObservationsTrain = size(XTrainNorm, 1);
                        XTrainCell = cell(numObservationsTrain, 1);
                        for i = 1:numObservationsTrain
                            XTrainCell{i} = XTrainNorm(i, :)';
                        end
                        
                        numObservationsVal = size(XValNorm, 1);
                        XValCell = cell(numObservationsVal, 1);
                        for i = 1:numObservationsVal
                            XValCell{i} = XValNorm(i, :)';
                        end
                        
                        % Define LSTM architecture
                        numFeatures = size(XTrainNorm,2);
                        
                        layers = [
                            sequenceInputLayer(numFeatures)
                            lstmLayer(128, 'OutputMode', 'last')
                            dropoutLayer(0.5)
                            fullyConnectedLayer(64)
                            reluLayer()
                            fullyConnectedLayer(numel(categories(yTrain)))
                            softmaxLayer
                            classificationLayer];
                        
                        % Training options
                        options = trainingOptions('adam', ...
                            'MaxEpochs', 50, ...
                            'MiniBatchSize', 32, ...
                            'ValidationData', {XValCell, yVal}, ...
                            'ValidationFrequency', 10, ...
                            'Plots', 'training-progress', ...
                            'Verbose', true, ...
                            'OutputFcn', @(info)app.trainingProgressCallback(info));
                        
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
                            trueLabels = categorical(yVal(:));
                            predLabels = categorical(classify(net, XValCell), categories(trueLabels));
                            
                            figure('Name', 'LSTM Confusion Matrix', 'NumberTitle', 'off');
                            confusionchart(trueLabels, predLabels, ...
                                'Title', sprintf('LSTM Confusion Matrix (Accuracy: %.2f%%)', sum(predLabels == trueLabels)/numel(trueLabels)*100), ...
                                'RowSummary', 'row-normalized', ...
                                'ColumnSummary', 'column-normalized');
                            
                        catch ME
                            warning('Failed to display confusion matrix: %s', ME.message);
                        end
                        
                    case 'SVM'
                        % Standardize data
                        app.SVM_Mean = mean(XTrain, 1);
                        app.SVM_Std = std(XTrain, 0, 1);
                        app.SVM_Std(app.SVM_Std == 0) = 1;
                        
                        XTrainStd = (XTrain - app.SVM_Mean) ./ app.SVM_Std;
                        XValStd = (XVal - app.SVM_Mean) ./ app.SVM_Std;
                        
                        % Configure SVM
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
                        
                        % Calculate feature importance
                        featureImp = zeros(1, size(XTrain, 2));
                        baselineAcc = sum(predict(model, XTrainStd) == yTrain)/numel(yTrain);
                        
                        for i = 1:size(XTrain, 2)
                            XPerm = XTrainStd;
                            XPerm(:,i) = XPerm(randperm(size(XPerm,1)),i);
                            permAcc = sum(predict(model, XPerm) == yTrain)/numel(yTrain);
                            featureImp(i) = baselineAcc - permAcc;
                        end
                        
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
                        % Normalize data
                        XTrainNorm = (XTrain - min(XTrain)) ./ (max(XTrain) - min(XTrain));
                        XValNorm = (XVal - min(XTrain)) ./ (max(XTrain) - min(XTrain));
                        
                        % Reshape for CNN
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
                            'Plots', 'training-progress', ...
                            'OutputFcn', @(info)app.trainingProgressCallback(info));
                        
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
                app.ProgressBar.Value = 0;
                app.updateStatus(['Training error: ' ME.message], 'red');
                uialert(app.UIFigure, ME.message, 'Training Error');
                
                if isfield(app, 'TrainingFigure') && isvalid(app.TrainingFigure)
                    close(app.TrainingFigure);
                end
            end
        end
        
    