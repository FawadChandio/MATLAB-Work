classdef FaceRecognitionSystem < matlab.apps.AppBase
    % Properties corresponding to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        TabGroup                    matlab.ui.container.TabGroup
        RecognitionTab              matlab.ui.container.Tab
        TrainingTab                 matlab.ui.container.Tab
        SettingsTab                 matlab.ui.container.Tab
        
        % Recognition Tab Components
        ImageAxes                  matlab.ui.control.UIAxes
        WebcamPanel                matlab.ui.container.Panel
        WebcamButton               matlab.ui.control.Button
        WebcamPreviewAxes          matlab.ui.control.UIAxes
        LoadImageButton            matlab.ui.control.Button
        RecognizeButton            matlab.ui.control.Button % Changed from StateButton to Button
        ModelSelectionDropDown     matlab.ui.control.DropDown
        ConfidenceGauge            matlab.ui.control.LinearGauge
        ResultPanel                matlab.ui.container.Panel
        ResultText                 matlab.ui.control.Label
        ConfidenceText             matlab.ui.control.Label
        FaceDatabaseButton         matlab.ui.control.Button
        LiveRecognitionSwitch      matlab.ui.control.ToggleSwitch
        LiveRecognitionLabel       matlab.ui.control.Label
        StatusText                 matlab.ui.control.Label
        
        % Training Tab Components
        TrainingAxes               matlab.ui.control.UIAxes
        AddPersonButton            matlab.ui.control.Button
        CaptureSamplesButton       matlab.ui.control.Button % Changed from StateButton to Button
        TrainButton                matlab.ui.control.Button % Changed from StateButton to Button
        TrainingProgressBar        matlab.ui.control.Gauge
        TrainingStatusText         matlab.ui.control.Label
        PersonNameEditField        matlab.ui.control.EditField
        NumSamplesSpinner          matlab.ui.control.Spinner
        DatasetInfoText            matlab.ui.control.Label
        
        % Settings Tab Components
        FeatureExtractionDropDown  matlab.ui.control.DropDown
        ModelSettingsPanel         matlab.ui.container.Panel
        SVMSettingsButton          matlab.ui.control.Button
        KNNSettingsButton         matlab.ui.control.Button
        CNNSettingsButton         matlab.ui.control.Button
        ThresholdSlider           matlab.ui.control.Slider
        ThresholdLabel            matlab.ui.control.Label
        SaveSettingsButton        matlab.ui.control.Button % Changed from StateButton to Button
        ResetSettingsButton       matlab.ui.control.Button % Changed from StateButton to Button
    end
    
    properties (Access = private)
        % System properties
        faceDetector = []
        trainedModels             struct
        faceDatabase              containers.Map
        currentImage              uint8
        webcamObj                 webcam
        isWebcamRunning           logical = false
        featureMethod             char = 'HOG'
        recognitionThreshold      double = 0.7
        timerObj                  timer
        isSystemInitialized       logical = false

        timerRunning logical = false  % Track timer state separately
        closingApp logical = false 
    end
    
    methods (Access = private)
        
        function initializeSystem(app)
            % Initialize face detector
            try
                app.faceDetector = vision.CascadeObjectDetector();
                app.faceDetector.MergeThreshold = 6;
                
                % Initialize empty models structure
                app.trainedModels = struct('svm', [], 'knn', [], 'cnn', []);
                
                % Initialize face database
                app.faceDatabase = containers.Map('KeyType', 'double', 'ValueType', 'any');
                
                % Set up live recognition timer
                app.timerObj = timer(...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 1, ...
                    'TimerFcn', @(~,~)app.liveRecognitionCallback());
                
                app.isSystemInitialized = true;
                updateUI(app);
                
                app.StatusText.Text = 'System initialized. Ready to use.';
            catch ME
                app.StatusText.Text = ['Initialization failed: ' ME.message];
                app.isSystemInitialized = false;
            end
        end
        
        function updateUI(app)
            % Enable/disable components based on system state
            app.RecognizeButton.Enable = app.isSystemInitialized && ~isempty(app.currentImage);
            app.LiveRecognitionSwitch.Enable = app.isSystemInitialized && app.isWebcamRunning;
            app.ModelSelectionDropDown.Enable = app.isSystemInitialized && ...
                (~isempty(app.trainedModels.svm) || ~isempty(app.trainedModels.knn) || ~isempty(app.trainedModels.cnn));
            
            % Update dataset info
            updateDatasetInfo(app);
        end
        
        function updateDatasetInfo(app)
            if isempty(app.faceDatabase) || ~app.faceDatabase.Count
                app.DatasetInfoText.Text = 'No faces in database';
            else
                numPeople = app.faceDatabase.Count;
                totalSamples = 0;
                keys = app.faceDatabase.keys;
                for i = 1:numPeople
                    totalSamples = totalSamples + size(app.faceDatabase(keys{i}).features, 1);
                end
                app.DatasetInfoText.Text = sprintf('Database: %d persons, %d samples', numPeople, totalSamples);
            end
        end
        
        function features = extractFeatures(~, img)
    % Standardize output size
    targetFeatureSize = 3780; % Example size for HOG features
    
    try
        img = imresize(img, [150 150]);
        if size(img, 3) == 3
            img = rgb2gray(img);
        end
        
        features = extractHOGFeatures(img);
        features = features(1:min(end,targetFeatureSize)); % Ensure consistent size
        if length(features) < targetFeatureSize
            features(end+1:targetFeatureSize) = 0; % Pad if needed
        end
    catch
        features = zeros(1, targetFeatureSize); % Return default if error
    end
end
        function trainModels(app)
    if ~app.isSystemInitialized || app.faceDatabase.Count < 2
        app.TrainingStatusText.Text = 'Need at least 2 people in database';
        return;
    end
    
    % Prepare training data
    features = [];
    labels = [];
    keys = app.faceDatabase.keys;
    
    % Collect all samples
    for i = 1:length(keys)
        data = app.faceDatabase(keys{i});
        if ~isempty(data.features)
            features = [features; data.features];
            labels = [labels; repmat(keys{i}, size(data.features, 1), 1)];
        end
    end
    
    % Train models only if we have valid data
    if ~isempty(features) && ~isempty(labels)
        % Train SVM
        app.trainedModels.svm = fitcecoc(features, labels, 'Learners', 'svm');
        
        % Train KNN
        app.trainedModels.knn = fitcknn(features, labels, 'NumNeighbors', 5);
        
        app.TrainingStatusText.Text = 'Training complete!';
    else
        app.TrainingStatusText.Text = 'No valid training data!';
    end
end
        function [label, confidence] = recognizeFace(app, img)
    % Initialize default return values
    label = -1;
    confidence = 0;
    
    try
        % Detect faces
        bbox = step(app.faceDetector, img);
        if isempty(bbox)
            return;
        end

        % Process largest face
        [~, idx] = max(bbox(:,3).*bbox(:,4));
        faceImg = imcrop(img, bbox(idx,:));
        features = app.extractFeatures(faceImg);
        
        if isempty(features)
            return;
        end

        % Ensure features are in correct format for prediction
        features = double(features(:)'); % Convert to row vector
        
        % Predict using selected model
        modelType = app.ModelSelectionDropDown.Value;
        switch modelType
            case 'SVM'
                if ~isempty(app.trainedModels.svm)
                    [label, scores] = predict(app.trainedModels.svm, features);
                    confidence = max(scores);
                end
            case 'KNN'
                if ~isempty(app.trainedModels.knn)
                    [label, scores] = predict(app.trainedModels.knn, features);
                    confidence = max(scores);
                end
            otherwise
                % Handle other model types
        end

        % Apply confidence threshold
        if confidence < app.recognitionThreshold
            label = -1;
        end
    catch ME
        app.StatusText.Text = ['Recognition error: ' ME.message];
    end
end

        function FaceDatabaseButtonPushed(app, ~)
    try
        fig = uifigure('Name', 'Face Database', 'Position', [100 100 400 500]);
        
        if isempty(app.faceDatabase) || app.faceDatabase.Count == 0
            uilabel(fig, 'Text', 'Database is empty', 'Position', [20 450 360 30]);
            return;
        end
        
        % Convert keys to sorted numeric array
        keys = app.faceDatabase.keys;
        keyNums = cell2mat(keys);
        [~, idx] = sort(keyNums);
        sortedKeys = keys(idx);
        
        % Prepare data for display
        data = cell(length(sortedKeys), 3);
        for i = 1:length(sortedKeys)
            key = sortedKeys{i};
            data{i,1} = key;
            data{i,2} = app.faceDatabase(key).name;
            data{i,3} = size(app.faceDatabase(key).features, 1);
        end
        
        uit = uitable(fig, 'Data', data, ...
            'ColumnName', {'ID', 'Name', 'Samples'}, ...
            'Position', [20 100 360 350]);
        
        uilabel(fig, 'Text', 'Face Database Contents', 'Position', [20 460 360 30], ...
            'FontSize', 16, 'FontWeight', 'bold');
        
        uibutton(fig, 'push', 'Text', 'Close', 'Position', [300 50 80 30], ...
            'ButtonPushedFcn', @(~,~)delete(fig));
    catch ME
        app.StatusText.Text = ['Database error: ' ME.message];
    end
end
       
    function liveRecognitionCallback(app)
        % COMPLETE LIVE RECOGNITION CALLBACK WITH ERROR HANDLING
        % Handles webcam feed, face detection, recognition, and display updates
        
        try
            % 1. SYSTEM VALIDATION CHECKS
            if ~isvalid(app) || ~app.isWebcamRunning || ~isvalid(app.LiveRecognitionSwitch)
                return;
            end
            
            if ~app.LiveRecognitionSwitch.Value
                return;
            end
            
            % 2. FRAME CAPTURE
            try
                frame = snapshot(app.webcamObj);
                if isempty(frame)
                    error('Empty frame received from webcam');
                end
            catch ME
                app.StatusText.Text = 'Webcam feed lost';
                app.stopWebcam();
                return;
            end
            
            % 3. DISPLAY LIVE FEED
            try
                imshow(frame, 'Parent', app.WebcamPreviewAxes);
                drawnow limitrate; % Smoother display update
            catch
                % Continue if display fails but log the error
                disp('Preview display update failed');
            end
            
            % 4. FACE DETECTION
            try
                bbox = step(app.faceDetector, frame);
                
                if ~isempty(bbox)
                    % Get largest face
                    [~, idx] = max(bbox(:,3).*bbox(:,4));
                    mainFace = bbox(idx,:);
                    
                    % 5. FACE RECOGNITION
                    faceImg = imcrop(frame, mainFace);
                    [label, confidence] = app.recognizeFace(faceImg);
                    
                    % 6. UPDATE RESULTS
                    if label == -1 || confidence < app.recognitionThreshold
                        app.ResultText.Text = 'Unknown person';
                        app.ConfidenceText.Text = sprintf('Confidence: %.1f%%', confidence*100);
                        app.ConfidenceGauge.Value = confidence * 100;
                    else
                        if isKey(app.faceDatabase, label)
                            personData = app.faceDatabase(label);
                            app.ResultText.Text = ['Recognized: ' personData.name];
                            app.ConfidenceText.Text = sprintf('Confidence: %.1f%%', confidence*100);
                            app.ConfidenceGauge.Value = confidence * 100;
                        else
                            app.ResultText.Text = 'Person not in database';
                        end
                    end
                    
                    % 7. DRAW FACE BOX
                    try
                        annotatedImg = insertObjectAnnotation(frame, 'rectangle', mainFace, 'Face');
                        imshow(annotatedImg, 'Parent', app.ImageAxes);
                    catch
                        % Fallback to frame without annotation
                        imshow(frame, 'Parent', app.ImageAxes);
                    end
                else
                    % No faces detected
                    app.ResultText.Text = 'No face detected';
                    imshow(frame, 'Parent', app.ImageAxes);
                end
                
            catch ME
                % Handle recognition/detection errors
                app.StatusText.Text = 'Recognition processing error';
                disp(getReport(ME, 'extended'));
                
                % Fallback display
                try
                    imshow(frame, 'Parent', app.ImageAxes);
                catch
                    % Last resort if all display fails
                    cla(app.ImageAxes);
                end
            end
            
        catch ME
            % Catch-all for unexpected errors
            app.webcamErrorHandler();
            disp(['CRITICAL ERROR: ' getReport(ME, 'extended')]);
        end
        
        % 8. MEMORY MANAGEMENT
        clear frame; % Release memory explicitly
    end   
    function CaptureSamplesButtonPushed(app, ~)
        try
            if ~app.isWebcamRunning
                app.TrainingStatusText.Text = 'Start webcam first!';
                return;
            end
            
            personName = app.PersonNameEditField.Value;
            if isempty(personName)
                app.TrainingStatusText.Text = 'Select a person first';
                return;
            end
            
            % Find person in database
            personID = [];
            keys = app.faceDatabase.keys;
            for i = 1:length(keys)
                if strcmp(app.faceDatabase(keys{i}).name, personName)
                    personID = keys{i};
                    break;
                end
            end
            
            if isempty(personID)
                app.TrainingStatusText.Text = 'Person not found';
                return;
            end
            
            % Capture samples
            numSamples = app.NumSamplesSpinner.Value;
            features = [];
            
            for i = 1:numSamples
                % Countdown
                for count = 3:-1:1
                    app.TrainingStatusText.Text = sprintf('Capturing %d/%d in %d...', i, numSamples, count);
                    drawnow;
                    pause(1);
                end
                
                % Capture and process
                frame = snapshot(app.webcamObj);
                bbox = step(app.faceDetector, frame);
                
                if isempty(bbox)
                    app.TrainingStatusText.Text = 'No face! Retrying...';
                    i = i - 1;
                    continue;
                end
                
                % Process face
                [~, idx] = max(bbox(:,3).*bbox(:,4));
                faceImg = imcrop(frame, bbox(idx,:));
                feat = app.extractFeatures(faceImg);
                
                if ~isempty(feat)
                    features = [features; feat];
                end
                
                % Show preview
                imshow(faceImg, 'Parent', app.TrainingAxes);
                app.TrainingStatusText.Text = sprintf('Captured %d/%d', i, numSamples);
            end
            
            % Store features safely
            if ~isempty(features)
                currentData = app.faceDatabase(personID);
                currentData.features = [currentData.features; features];
                app.faceDatabase(personID) = currentData;
                app.TrainingStatusText.Text = sprintf('Added %d samples', numSamples);
                updateDatasetInfo(app);
            else
                app.TrainingStatusText.Text = 'No valid features captured';
            end
        catch ME
            app.StatusText.Text = ['Capture error: ' ME.message];
        end
    end
      
    function startWebcam(app)
    try
        if app.isWebcamRunning || app.closingApp
            return;
        end
        
        % Initialize webcam
        app.webcamObj = webcam(1);
        app.isWebcamRunning = true;
        
        % Create new timer if needed
        if isempty(app.timerObj) || ~isvalid(app.timerObj)
            app.timerObj = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.5, ...
                'TimerFcn', @(~,~)app.liveRecognitionCallback(), ...
                'ErrorFcn', @(~,~)app.webcamErrorHandler(), ...
                'Name', 'FaceRecognitionTimer', ...
                'Tag', 'AppWebcamTimer');
        end
        
        % Start timer if not running
        if strcmp(app.timerObj.Running, 'off')
            start(app.timerObj);
            app.timerRunning = true;
        end
        
        % Update UI
        app.WebcamButton.Text = 'Stop Webcam';
        app.StatusText.Text = 'Webcam active';
        
    catch ME
        app.stopWebcam();
        app.StatusText.Text = ['Webcam error: ' ME.message];
    end
end

% Enhanced stopWebcam function
function stopWebcam(app)
    try
        if ~app.isWebcamRunning || app.closingApp
            return;
        end
        
        % Stop and delete timer
        if ~isempty(app.timerObj) && isvalid(app.timerObj)
            if strcmp(app.timerObj.Running, 'on')
                stop(app.timerObj);
            end
            delete(app.timerObj);
            app.timerObj = [];
        end
        
        % Clear webcam
        if ~isempty(app.webcamObj)
            clear app.webcamObj;
            app.webcamObj = [];
        end
        
        % Update states
        app.isWebcamRunning = false;
        app.timerRunning = false;
        
        % Update UI
        app.WebcamButton.Text = 'Start Webcam';
        app.StatusText.Text = 'Webcam stopped';
        
    catch ME
        app.StatusText.Text = ['Stop error: ' ME.message];
    end
end


% Modified error handler
function webcamErrorHandler(app)
    try
        app.StatusText.Text = 'System error occurred';
        app.stopWebcam();
    catch
        % If everything fails, try to delete everything
        try
            delete(timerfind('Tag', 'AppWebcamTimer'));
            delete(app.UIFigure);
        catch
        end
    end
end    
        function SVMSettingsButtonPushed(~, ~)
            msgbox('SVM settings would be configured here', 'Settings');
        end
        
        function KNNSettingsButtonPushed(~, ~)
            msgbox('KNN settings would be configured here', 'Settings'); 
        end
        
        function CNNSettingsButtonPushed(~, ~)
            msgbox('CNN settings would be configured here', 'Settings');
        end
        
        function SaveSettingsButtonPushed(app, ~)
            app.featureMethod = app.FeatureExtractionDropDown.Value;
            app.recognitionThreshold = app.ThresholdSlider.Value / 100;
            app.StatusText.Text = 'Settings saved successfully';
        end
        
        function ResetSettingsButtonPushed(app, ~)
            app.featureMethod = 'HOG';
            app.recognitionThreshold = 0.7;
            app.FeatureExtractionDropDown.Value = 'HOG';
            app.ThresholdSlider.Value = 70;
            app.ThresholdLabel.Text = 'Recognition Threshold: 70.0%';
            app.StatusText.Text = 'Settings reset to defaults';
        end
    end
    
    % Callbacks
    methods (Access = private)
        
        function startupFcn(app)
            app.UIFigure.Color = [0.96 0.96 0.98];
            initializeSystem(app);
            
            % Configure axes
            axesList = [app.ImageAxes, app.WebcamPreviewAxes, app.TrainingAxes];
            for ax = axesList
                ax.XTick = [];
                ax.YTick = [];
                ax.Box = 'on';
            end
            
            % Set default threshold
            app.ThresholdSlider.Value = app.recognitionThreshold * 100;
            app.ThresholdLabel.Text = sprintf('Threshold: %.1f%%', app.recognitionThreshold*100);
            
            % Initialize status
            app.StatusText.Text = 'System initializing...';
            app.TrainingStatusText.Text = 'Ready for training';
        end
        
        function LoadImageButtonPushed(app, ~)
            [file, path] = uigetfile({'*.jpg;*.png;*.bmp', 'Image Files'});
            if ~isequal(file, 0)
                app.currentImage = imread(fullfile(path, file));
                imshow(app.currentImage, 'Parent', app.ImageAxes);
                app.StatusText.Text = 'Image loaded. Ready for recognition.';
                updateUI(app);
            end
        end
        
        function WebcamButtonPushed(app, ~)
            if app.isWebcamRunning
                stopWebcam(app);
            else
                startWebcam(app);
            end
        end
        
        function RecognizeButtonPushed(app, ~)
            if isempty(app.currentImage)
                app.ResultText.Text = 'No image to recognize!';
                return;
            end
            
            [label, confidence] = app.recognizeFace(app.currentImage);
            
            if label == -1
                app.ResultText.Text = 'Unknown person';
                app.ConfidenceText.Text = 'Low confidence';
            else
                personData = app.faceDatabase(label);
                app.ResultText.Text = ['Recognized: ' personData.name];
                app.ConfidenceText.Text = sprintf('Confidence: %.1f%%', confidence*100);
            end
            app.ConfidenceGauge.Value = confidence * 100;
        end
        
        function AddPersonButtonPushed(app, ~)
            personName = app.PersonNameEditField.Value;
            if isempty(personName)
                app.TrainingStatusText.Text = 'Enter a name first';
                return;
            end
            
            % Check for existing name
            keys = app.faceDatabase.keys;
            for i = 1:length(keys)
                if strcmp(app.faceDatabase(keys{i}).name, personName)
                    app.TrainingStatusText.Text = 'Person exists!';
                    return;
                end
            end
            
            % Add new person
            newID = length(keys) + 1;
            app.faceDatabase(newID) = struct('name', personName, 'features', []);
            app.TrainingStatusText.Text = ['Added ' personName];
            updateDatasetInfo(app);
        end
        
        function TrainButtonPushed(app, ~)
            trainModels(app);
        end
        
        function LiveRecognitionSwitchValueChanged(app, ~)
            if app.LiveRecognitionSwitch.Value && ~app.isWebcamRunning
                app.LiveRecognitionSwitch.Value = false;
                app.StatusText.Text = 'Start webcam first!';
            end
        end
        
        function ThresholdSliderValueChanged(app, ~)
            app.recognitionThreshold = app.ThresholdSlider.Value / 100;
            app.ThresholdLabel.Text = sprintf('Threshold: %.1f%%', app.recognitionThreshold*100);
        end
        
        function UIFigureCloseRequest(app, ~)
    try
        app.closingApp = true; % Set closing flag
        
        % Force stop webcam and timer
        app.stopWebcam();
        
        % Additional cleanup if needed
        if isvalid(app.UIFigure)
            delete(app.UIFigure);
        end
        
    catch ME
        % Final attempt to close
        delete(app.UIFigure);
    end
end

    end
    
    methods (Access = public)
        function app = FaceRecognitionSystem
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);
            if nargout == 0
                clear app;
            end
        end
        
        function delete(app)
            delete(app.UIFigure);
        end
    end
    
    methods (Access = private)
     function createComponents(app)
    % Create UIFigure
    app.UIFigure = uifigure('Visible', 'off');
    app.UIFigure.Position = [100 100 1000 700];
    app.UIFigure.Name = 'Advanced Face Recognition System';
    app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
    
    % Create TabGroup
    app.TabGroup = uitabgroup(app.UIFigure);
    app.TabGroup.Position = [20 20 960 660];
    
    % Create RecognitionTab
    app.RecognitionTab = uitab(app.TabGroup);
    app.RecognitionTab.Title = 'Recognition';
    
    % Create ImageAxes
    app.ImageAxes = uiaxes(app.RecognitionTab);
    app.ImageAxes.Position = [30 300 400 300];
    app.ImageAxes.Box = 'on';
    
    % Create WebcamPanel
    app.WebcamPanel = uipanel(app.RecognitionTab);
    app.WebcamPanel.Title = 'Webcam';
    app.WebcamPanel.Position = [30 30 400 250];
    
    % Create WebcamPreviewAxes
    app.WebcamPreviewAxes = uiaxes(app.WebcamPanel);
    app.WebcamPreviewAxes.Position = [10 50 380 180];
    app.WebcamPreviewAxes.XTick = [];
    app.WebcamPreviewAxes.YTick = [];
    app.WebcamPreviewAxes.Box = 'on';
    app.WebcamPreviewAxes.Visible = 'off';
    
    % Create WebcamButton
    app.WebcamButton = uibutton(app.WebcamPanel, 'push');
    app.WebcamButton.ButtonPushedFcn = createCallbackFcn(app, @WebcamButtonPushed, true);
    app.WebcamButton.Position = [10 10 100 30];
    app.WebcamButton.Text = 'Start Webcam';
    
    % Create LoadImageButton
    app.LoadImageButton = uibutton(app.RecognitionTab, 'push');
    app.LoadImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadImageButtonPushed, true);
    app.LoadImageButton.Position = [450 600 120 30];
    app.LoadImageButton.Text = 'Load Image';
    
    % Create ModelSelectionDropDown (Moved before RecognizeButton since it's referenced in updateUI)
    app.ModelSelectionDropDown = uidropdown(app.RecognitionTab);
    app.ModelSelectionDropDown.Items = {'SVM', 'KNN', 'CNN'};
    app.ModelSelectionDropDown.Position = [450 500 120 30];
    app.ModelSelectionDropDown.Value = 'SVM';
    app.ModelSelectionDropDown.Enable = 'off';
    
    % Create RecognizeButton
    app.RecognizeButton = uibutton(app.RecognitionTab, 'push');
    app.RecognizeButton.ButtonPushedFcn = createCallbackFcn(app, @RecognizeButtonPushed, true);
    app.RecognizeButton.Position = [450 550 120 30];
    app.RecognizeButton.Text = 'Recognize Face';
    app.RecognizeButton.Enable = 'off';
    
    % Create ConfidenceGauge
    app.ConfidenceGauge = uigauge(app.RecognitionTab, 'linear');
    app.ConfidenceGauge.Position = [600 550 300 30];
    app.ConfidenceGauge.Limits = [0 100];
    
    % Create ResultPanel (Moved before ResultText and ConfidenceText)
    app.ResultPanel = uipanel(app.RecognitionTab);
    app.ResultPanel.Title = 'Recognition Result';
    app.ResultPanel.Position = [600 300 300 200];
    
    % Create ResultText
    app.ResultText = uilabel(app.ResultPanel);
    app.ResultText.Position = [20 130 260 30];
    app.ResultText.Text = 'No recognition performed';
    app.ResultText.FontSize = 14;
    
    % Create ConfidenceText
    app.ConfidenceText = uilabel(app.ResultPanel);
    app.ConfidenceText.Position = [20 90 260 30];
    app.ConfidenceText.Text = 'Confidence: 0%';
    
    % Create FaceDatabaseButton
    app.FaceDatabaseButton = uibutton(app.RecognitionTab, 'push');
    app.FaceDatabaseButton.ButtonPushedFcn = createCallbackFcn(app, @FaceDatabaseButtonPushed, true);
    app.FaceDatabaseButton.Position = [450 450 120 30];
    app.FaceDatabaseButton.Text = 'View Database';
    
    % Create LiveRecognitionSwitch
    app.LiveRecognitionSwitch = uiswitch(app.RecognitionTab, 'toggle');
    app.LiveRecognitionSwitch.Position = [600 500 45 20];
    app.LiveRecognitionSwitch.ValueChangedFcn = createCallbackFcn(app, @LiveRecognitionSwitchValueChanged, true);
    app.LiveRecognitionSwitch.Enable = 'off';
    
    % Create LiveRecognitionLabel
    app.LiveRecognitionLabel = uilabel(app.RecognitionTab);
    app.LiveRecognitionLabel.Position = [650 500 200 20];
    app.LiveRecognitionLabel.Text = 'Live Recognition';
    
    % Create StatusText
    app.StatusText = uilabel(app.RecognitionTab);
    app.StatusText.Position = [50 100 400 30];
    app.StatusText.Text = 'Status: Ready';
    
    % Create TrainingTab
    app.TrainingTab = uitab(app.TabGroup);
    app.TrainingTab.Title = 'Training';
    
    % Create TrainingAxes
    app.TrainingAxes = uiaxes(app.TrainingTab);
    app.TrainingAxes.Position = [30 300 400 300];
    app.TrainingAxes.Box = 'on';
    
    % Create AddPersonButton
    app.AddPersonButton = uibutton(app.TrainingTab, 'push');
    app.AddPersonButton.ButtonPushedFcn = createCallbackFcn(app, @AddPersonButtonPushed, true);
    app.AddPersonButton.Position = [30 250 120 30];
    app.AddPersonButton.Text = 'Add Person';
    
    % Create PersonNameEditField
    app.PersonNameEditField = uieditfield(app.TrainingTab, 'text');
    app.PersonNameEditField.Position = [160 250 150 30];
    app.PersonNameEditField.Placeholder = 'Enter name';
    
    % Create NumSamplesSpinner (Moved before CaptureSamplesButton since it's related)
    app.NumSamplesSpinner = uispinner(app.TrainingTab);
    app.NumSamplesSpinner.Position = [200 200 80 30];
    app.NumSamplesSpinner.Limits = [1 100];
    app.NumSamplesSpinner.Value = 10;
    
    % Create CaptureSamplesButton
    app.CaptureSamplesButton = uibutton(app.TrainingTab, 'push');
    app.CaptureSamplesButton.ButtonPushedFcn = createCallbackFcn(app, @CaptureSamplesButtonPushed, true);
    app.CaptureSamplesButton.Position = [30 200 150 30];
    app.CaptureSamplesButton.Text = 'Capture Samples';
    
    % Create TrainButton
    app.TrainButton = uibutton(app.TrainingTab, 'push');
    app.TrainButton.ButtonPushedFcn = createCallbackFcn(app, @TrainButtonPushed, true);
    app.TrainButton.Position = [30 150 120 30];
    app.TrainButton.Text = 'Train Models';
    
    % Create TrainingProgressBar
    app.TrainingProgressBar = uigauge(app.TrainingTab, 'circular');
    app.TrainingProgressBar.Position = [500 400 200 200];
    
    % Create TrainingStatusText
    app.TrainingStatusText = uilabel(app.TrainingTab);
    app.TrainingStatusText.Position = [500 350 300 30];
    app.TrainingStatusText.Text = 'Ready for training';
    app.TrainingStatusText.FontSize = 14;
    
    % Create DatasetInfoText
    app.DatasetInfoText = uilabel(app.TrainingTab);
    app.DatasetInfoText.Position = [30 100 400 30];
    app.DatasetInfoText.Text = 'Database: 0 persons, 0 samples';
    app.DatasetInfoText.FontSize = 12;
    
    % Create SettingsTab
    app.SettingsTab = uitab(app.TabGroup);
    app.SettingsTab.Title = 'Settings';
    
    % Create FeatureExtractionDropDown
    app.FeatureExtractionDropDown = uidropdown(app.SettingsTab);
    app.FeatureExtractionDropDown.Items = {'HOG', 'LBP', 'SURF', 'CNN'};
    app.FeatureExtractionDropDown.Position = [30 600 200 30];
    app.FeatureExtractionDropDown.Value = 'HOG';
    
    % Create ModelSettingsPanel
    app.ModelSettingsPanel = uipanel(app.SettingsTab);
    app.ModelSettingsPanel.Title = 'Model Settings';
    app.ModelSettingsPanel.Position = [30 400 300 180];
    
    % Create SVMSettingsButton
    app.SVMSettingsButton = uibutton(app.ModelSettingsPanel, 'push');
    app.SVMSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @SVMSettingsButtonPushed, true);
    app.SVMSettingsButton.Position = [20 120 120 30];
    app.SVMSettingsButton.Text = 'SVM Settings';
    
    % Create KNNSettingsButton
    app.KNNSettingsButton = uibutton(app.ModelSettingsPanel, 'push');
    app.KNNSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @KNNSettingsButtonPushed, true);
    app.KNNSettingsButton.Position = [20 80 120 30];
    app.KNNSettingsButton.Text = 'KNN Settings';
    
    % Create CNNSettingsButton
    app.CNNSettingsButton = uibutton(app.ModelSettingsPanel, 'push');
    app.CNNSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @CNNSettingsButtonPushed, true);
    app.CNNSettingsButton.Position = [20 40 120 30];
    app.CNNSettingsButton.Text = 'CNN Settings';
    
    % Create ThresholdSlider
    app.ThresholdSlider = uislider(app.SettingsTab);
    app.ThresholdSlider.Position = [30 350 200 3];
    app.ThresholdSlider.Limits = [50 100];
    app.ThresholdSlider.Value = 70;
    app.ThresholdSlider.ValueChangedFcn = createCallbackFcn(app, @ThresholdSliderValueChanged, true);
    
    % Create ThresholdLabel
    app.ThresholdLabel = uilabel(app.SettingsTab);
    app.ThresholdLabel.Position = [30 370 300 22];
    app.ThresholdLabel.Text = 'Recognition Threshold: 70.0%';
    
    % Create SaveSettingsButton
    app.SaveSettingsButton = uibutton(app.SettingsTab, 'push');
    app.SaveSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveSettingsButtonPushed, true);
    app.SaveSettingsButton.Position = [30 100 120 30];
    app.SaveSettingsButton.Text = 'Save Settings';
    
    % Create ResetSettingsButton
    app.ResetSettingsButton = uibutton(app.SettingsTab, 'push');
    app.ResetSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @ResetSettingsButtonPushed, true);
    app.ResetSettingsButton.Position = [170 100 120 30];
    app.ResetSettingsButton.Text = 'Reset Settings';
    
    % Show the figure after all components are created
    app.UIFigure.Visible = 'on';
end

    end
end