classdef DronePathApp < matlab.apps.AppBase

    % Properties for UI components
    properties (Access = public)
        UIFigure                  matlab.ui.Figure
        HexColorLabel             matlab.ui.control.Label
        HexColorField             matlab.ui.control.EditField
        WaypointsTable            matlab.ui.control.Table
        LoadWaypointsButton       matlab.ui.control.Button
        SaveWaypointsButton       matlab.ui.control.Button
        ClearButton               matlab.ui.control.Button
        StartButton               matlab.ui.control.Button
        StopButton                matlab.ui.control.Button
        UIAxes                    matlab.ui.control.UIAxes
    end

    % Animation variables and control properties
    properties (Access = private)
        xPath                     
        yPath                     
        zPath                    
        droneImage                
        trackLine                 
        completedPathLine        
        trackColor = [1, 0, 0]    
        isRunning = false         
    end

    % Callbacks for UI interaction
    methods (Access = private)

        % Load waypoints from a CSV file
        function LoadWaypointsButtonPushed(app, ~)
            [file, path] = uigetfile('*.csv');
            if ischar(file)
                waypointData = readtable(fullfile(path, file));
                app.xPath = waypointData.Var1';
                app.yPath = waypointData.Var2';
                app.zPath = ones(size(app.xPath)) * 3;  % Initial takeoff height
                app.updateWaypointsTable();
                app.plotPath();
            end
        end

        % Save current waypoints to a CSV file
        function SaveWaypointsButtonPushed(app, ~)
            [file, path] = uiputfile('*.csv');
            if ischar(file)
                waypointData = table(app.xPath', app.yPath');
                writetable(waypointData, fullfile(path, file));
            end
        end

        % Update waypoints table display
        function updateWaypointsTable(app)
            data = [app.xPath', app.yPath'];
            app.WaypointsTable.Data = data;
        end

        % Plot path on the UIAxes and set up for drone movement
        function plotPath(app)
            
            if isempty(app.xPath) || isempty(app.yPath) || isempty(app.zPath)
                return;  
            end

            % Delete previous path lines if they exist
            if ~isempty(app.trackLine) && isgraphics(app.trackLine)
                delete(app.trackLine);
            end
            if ~isempty(app.completedPathLine) && isgraphics(app.completedPathLine)
                delete(app.completedPathLine);
            end

            % Plot the planned path in red
            app.trackLine = plot3(app.UIAxes, app.xPath, app.yPath, app.zPath, ...
                                  'Color', app.trackColor, 'LineWidth', 6);
            hold(app.UIAxes, 'on');

            % Initialize completed path line (blue color) over the red path
            app.completedPathLine = plot3(app.UIAxes, NaN, NaN, NaN, ...
                                          'Color', [0, 0, 1], 'LineWidth', 6);

                          % Initialize drone image marker
            if ~isempty(app.droneImage) && isgraphics(app.droneImage)
             delete(app.droneImage);  % Remove existing drone image
            end

             % Load drone icon
             droneIcon = imread('droneIcon.jpg');  

              % Increase the size of the drone icon 
                iconSize = 0.3; 

                app.droneImage = imagesc(app.UIAxes, ...
                         'XData', [app.xPath(1) - iconSize, app.xPath(1) + iconSize], ...
                         'YData', [app.yPath(1) - iconSize, app.yPath(1) + iconSize], ...
                         'CData', droneIcon);

                 % Ensure the image is positioned at the first waypoint
                   set(app.droneImage, 'XData', [app.xPath(1) - iconSize, app.xPath(1) + iconSize], ...
                    'YData', [app.yPath(1) - iconSize, app.yPath(1) + iconSize]);

            

            % Set the axis to a fixed view
            axis(app.UIAxes, 'equal');
            xlim(app.UIAxes, [min(app.xPath)-0.5, max(app.xPath)+0.5]);
            ylim(app.UIAxes, [min(app.yPath)-0.5, max(app.yPath)+0.5]);
            zlim(app.UIAxes, [0, max(app.zPath)+1]);

            % Set a fixed view angle for better visibility
            view(app.UIAxes, 3);  % Set a 3D view if you want 
            grid(app.UIAxes, 'off');
            hold(app.UIAxes, 'off');
        end

        % Function to handle drone animation along the path with blue track overlay
        function animateDrone(app)
            app.isRunning = true;  
            midPointIdx = ceil(length(app.xPath) / 2);  % Index for hover
            speed = 1.5;           
            hoverDuration = 2;      

            % Loop to animate drone movement
            for i = 1:length(app.xPath)
                if ~app.isRunning
                    return;  % Stop animation if flag is false
                end

                % Check if droneImage exists and is valid
                if isempty(app.droneImage) || ~isgraphics(app.droneImage)
                    % Reload drone icon if deleted or not initialized
                    droneIcon = imread('droneIcon.png');  % Replace with your image file name
                    app.droneImage = imagesc(app.UIAxes, ...
                                             'XData', [app.xPath(i) - 0.1, app.xPath(i) + 0.1], ...
                                             'YData', [app.yPath(i) - 0.1, app.yPath(i) + 0.1], ...
                                             'CData', droneIcon);
                else
                    % Update drone image position
                    set(app.droneImage, 'XData', [app.xPath(i) - 0.1, app.xPath(i) + 0.1], ...
                                        'YData', [app.yPath(i) - 0.1, app.yPath(i) + 0.1]);
                end

                % Update completed path (blue) to overlay on red track
                set(app.completedPathLine, 'XData', app.xPath(1:i), 'YData', app.yPath(1:i), 'ZData', app.zPath(1:i));

                % Hover at the midpoint
                if i == midPointIdx
                    pause(hoverDuration);
                end

                % Pause to control speed
                pause(speed);
            end
            app.isRunning = false;  % Animation complete
        end

        % Start animation callback
        function StartButtonPushed(app, ~)
            if ~app.isRunning
                app.isRunning = true;
                animateDrone(app);
            end
        end

        % Stop animation callback
        function StopButtonPushed(app, ~)
            app.isRunning = false;  % Toggle to stop the animation
        end

        % Function to update the track color
        function HexColorFieldValueChanged(app, ~)
            colorStr = app.HexColorField.Value;
            app.trackColor = sscanf(colorStr, '#%2x%2x%2x', [1 3]) / 255;
            app.plotPath();
        end

        % Clear waypoints and path
        function ClearButtonPushed(app, ~)
            app.xPath = [];
            app.yPath = [];
            app.zPath = [];
            app.WaypointsTable.Data = [];
            cla(app.UIAxes);
        end
    end

    % App component creation and layout adjustments
    methods (Access = private)

% Create UI components
function createComponents(app)
    % Create main UI figure
    app.UIFigure = uifigure('Position', [100 100 900 600], 'Name', 'Drone Path Builder');
    
    % Color selection
    app.HexColorLabel = uilabel(app.UIFigure, 'Position', [20 540 150 22], ...
                                'Text', 'Hex color code of track (#RRGGBB)');
    app.HexColorField = uieditfield(app.UIFigure, 'text', 'Position', [180 540 100 22], ...
                                    'Value', '#FF0000');
    app.HexColorField.ValueChangedFcn = createCallbackFcn(app, @HexColorFieldValueChanged, true);

    % Create waypoints table
    app.WaypointsTable = uitable(app.UIFigure, 'Position', [20 300 260 220], ...
                                 'ColumnName', {'East', 'North'}, 'ColumnEditable', [false false]);

    % Load, save, and clear buttons
    app.LoadWaypointsButton = uibutton(app.UIFigure, 'push', 'Position', [20 260 120 30], 'Text', 'Load Waypoints');
    app.LoadWaypointsButton.ButtonPushedFcn = createCallbackFcn(app, @LoadWaypointsButtonPushed, true);
    
    app.SaveWaypointsButton = uibutton(app.UIFigure, 'push', 'Position', [160 260 120 30], 'Text', 'Save Waypoints');
    app.SaveWaypointsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveWaypointsButtonPushed, true);

    app.ClearButton = uibutton(app.UIFigure, 'push', 'Position', [20 220 120 30], 'Text', 'Clear');
    app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);

    % Start and stop buttons for animation
    app.StartButton = uibutton(app.UIFigure, 'push', 'Position', [160 220 120 30], 'Text', 'Start');
    app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);

    app.StopButton = uibutton(app.UIFigure, 'push', 'Position', [160 180 120 30], 'Text', 'Stop');
    app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);

    % Create the axes for path plot
    app.UIAxes = matlab.ui.control.UIAxes('Parent', app.UIFigure, 'Position', [300 50 550 500]);
end



    end

    % App initialization and startup functions
    methods (Access = public)

        % App startup function
        function startupFcn(app)
            app.xPath = [];  % Initialize empty paths
            app.yPath = [];
            app.zPath = [];
        end

        % Construct app
        function app = DronePathApp()
            createComponents(app);
            startupFcn(app);
        end

    end
end
