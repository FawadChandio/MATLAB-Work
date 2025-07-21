% Define path data (example values; replace with actual data or CSV import)
xPath = [0, 1, 2, 3, 4, 5];  % Example x coordinates
yPath = [0, 1, 0, -1, 0, 1]; % Example y coordinates
zPath = [0, 3, 1.5, 1.5, 0, 0]; % Corresponding z coordinates for takeoff, hover, and landing

% Assign the data to the base workspace so Simulink can access it
assignin('base', 'xPath', xPath);
assignin('base', 'yPath', yPath);
assignin('base', 'zPath', zPath);

% Define the model name and create a new system
modelName = 'CompleteDronePathSimulation2';
new_system(modelName);
open_system(modelName);

% Define layout variables for block positioning
xOffset = 100;
yOffset = 50;
blockWidth = 100;
blockHeight = 50;

% 1. Load the waypoints (xPath, yPath, zPath) into Simulink via From Workspace blocks
add_block('simulink/Sources/From Workspace', [modelName, '/xPath'], ...
    'Position', [xOffset, yOffset, xOffset + blockWidth, yOffset + blockHeight], ...
    'VariableName', 'xPath');
add_block('simulink/Sources/From Workspace', [modelName, '/yPath'], ...
    'Position', [xOffset, yOffset + 100, xOffset + blockWidth, yOffset + 100 + blockHeight], ...
    'VariableName', 'yPath');
add_block('simulink/Sources/From Workspace', [modelName, '/zPath'], ...
    'Position', [xOffset, yOffset + 200, xOffset + blockWidth, yOffset + 200 + blockHeight], ...
    'VariableName', 'zPath');

% 2. Add Constant blocks for defining takeoff, hover, and landing heights
add_block('simulink/Sources/Constant', [modelName, '/Takeoff Height'], ...
    'Position', [xOffset + 200, yOffset, xOffset + 200 + blockWidth, yOffset + blockHeight], ...
    'Value', '3');  % Takeoff height at 3m

add_block('simulink/Sources/Constant', [modelName, '/Hover Height'], ...
    'Position', [xOffset + 200, yOffset + 100, xOffset + 200 + blockWidth, yOffset + 100 + blockHeight], ...
    'Value', '1.5'); % Hover height at 1.5m

add_block('simulink/Sources/Constant', [modelName, '/Landing Height'], ...
    'Position', [xOffset + 200, yOffset + 200, xOffset + 200 + blockWidth, yOffset + 200 + blockHeight], ...
    'Value', '0'); % Landing height at ground level

% 3. Add MATLAB Function block to control altitude transitions
add_block('simulink/User-Defined Functions/MATLAB Function', [modelName, '/Altitude Control'], ...
    'Position', [xOffset + 400, yOffset, xOffset + 400 + blockWidth, yOffset + 150]);

% 4. Add a Switch block to change altitude phases based on conditions
add_block('simulink/Signal Routing/Switch', [modelName, '/Phase Switch'], ...
    'Position', [xOffset + 600, yOffset + 50, xOffset + 600 + blockWidth, yOffset + 50 + blockHeight]);

% 5. Add a Clock block for phase timing control
add_block('simulink/Sources/Clock', [modelName, '/Clock'], ...
    'Position', [xOffset + 100, yOffset + 300, xOffset + 100 + blockWidth, yOffset + 300 + blockHeight]);

% 6. Add Display blocks to show X, Y, and Z positions in real-time
add_block('simulink/Sinks/Display', [modelName, '/X Display'], ...
    'Position', [xOffset + 800, yOffset, xOffset + 800 + blockWidth, yOffset + blockHeight]);
add_block('simulink/Sinks/Display', [modelName, '/Y Display'], ...
    'Position', [xOffset + 800, yOffset + 100, xOffset + 800 + blockWidth, yOffset + 100 + blockHeight]);
add_block('simulink/Sinks/Display', [modelName, '/Z Display'], ...
    'Position', [xOffset + 800, yOffset + 200, xOffset + 800 + blockWidth, yOffset + 200 + blockHeight]);

% 7. Add XY Graph block for 2D visualization of the drone's path
add_block('simulink/Sinks/XY Graph', [modelName, '/Drone Path Visualization'], ...
    'Position', [xOffset + 1000, yOffset, xOffset + 1000 + 150, yOffset + 200]);

% 8. Connect blocks for real-time position and path visualization
add_line(modelName, 'xPath/1', 'X Display/1');
add_line(modelName, 'yPath/1', 'Y Display/1');
add_line(modelName, 'zPath/1', 'Z Display/1');
add_line(modelName, 'xPath/1', 'Drone Path Visualization/1');
add_line(modelName, 'yPath/1', 'Drone Path Visualization/2');

% 9. Connect additional components for altitude control and phases
add_line(modelName, 'Clock/1', 'Altitude Control/1');
add_line(modelName, 'Takeoff Height/1', 'Phase Switch/1');
add_line(modelName, 'Hover Height/1', 'Phase Switch/2');
add_line(modelName, 'Landing Height/1', 'Phase Switch/3');

% Save and open the model
save_system(modelName);
open_system(modelName);

disp('Complete Simulink model created successfully.');

% Note:
% Manually open the "Altitude Control" MATLAB Function block in the Simulink model.
% Paste the following function code inside the block:

% function z = fcn(phase)
% if phase == 1
%     z = 3;       % Takeoff height
% elseif phase == 2
%     z = 1.5;     % Hover height
% else
%     z = 0;       % Landing height
% end
