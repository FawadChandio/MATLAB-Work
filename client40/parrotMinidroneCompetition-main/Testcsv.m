% Load path data from CSV file  
pathData = readtable('D:\MATLAB Tasks\client40\parrotMinidroneCompetition-main\correct_waypoints.csv');  
xPath = pathData.Var1;  % Replace with actual column name if needed  
yPath = pathData.Var2;  % Replace with actual column name if needed  

% Define simulation parameters  
takeoffHeight = 3;      % Starting at a height of 3m  
landingHeight = 0;      % Height at the landing point  
hoverDuration = 2;      % Duration to hover at the midpoint in seconds  
speed = 0.05;           % Speed factor for movement delay  

% Initial settings  
z = ones(size(xPath)) * takeoffHeight;  % Set all z-coordinates to the takeoff height  
midPointIdx = ceil(length(xPath) / 2);  % Index for hover point  

% Adjust yPath to have the drone move downward left  
yPath = linspace(takeoffHeight, landingHeight, length(xPath));  % Create downward path  

% Setup figure for simulation with professional visual settings  
figure('Name', 'Drone Path Simulation', 'NumberTitle', 'off', 'Color', [0.95, 0.95, 0.95]);  
hold on;  
grid on;  
axis equal;  
axis vis3d;  

% Set background color and plot the path  
plot3(xPath, yPath, zeros(size(xPath)), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Planned Path');  

% Mark starting, hovering, and landing points with circles  
theta = linspace(0, 2*pi, 100); % Circle points  
circleX = 0.1 * cos(theta); % Circle radius  
circleY = 0.1 * sin(theta); % Circle radius  

% Starting point (Takeoff)  
fill(circleX + xPath(1), circleY + yPath(1), 'g', 'FaceAlpha', 0.5, 'DisplayName', 'Start (Takeoff)');  
plot3(xPath(1), yPath(1), takeoffHeight, 'go', 'MarkerSize', 10, 'LineWidth', 2);  

% Hover point (Middle)  
fill(circleX + xPath(midPointIdx), circleY + yPath(midPointIdx), 'm', 'FaceAlpha', 0.5, 'DisplayName', 'Hover Point');  
plot3(xPath(midPointIdx), yPath(midPointIdx), takeoffHeight, 'mo', 'MarkerSize', 10, 'LineWidth', 2);  

% Landing point (End)  
fill(circleX + xPath(end), circleY + yPath(end), 'r', 'FaceAlpha', 0.5, 'DisplayName', 'End (Landing)');  
plot3(xPath(end), yPath(end), landingHeight, 'ro', 'MarkerSize', 10, 'LineWidth', 2);  

% Labels and legend for clarity  
title('3D Drone Path Simulation with Takeoff, Hover, and Landing', 'FontSize', 14, 'FontWeight', 'bold');  
xlabel('X Position (m)', 'FontSize', 12, 'FontWeight', 'bold');  
ylabel('Y Position (m)', 'FontSize', 12, 'FontWeight', 'bold');  
zlabel('Z Position (Altitude, m)', 'FontSize', 12, 'FontWeight', 'bold');  
legend('Location', 'best');  

% Simulate drone movement along the path  
for i = 1:length(xPath)  
    % Update z-coordinate to maintain altitude during movement  
    zCurrent = z(i);  % Maintain z at takeoffHeight  
    plot3(xPath(i), yPath(i), zCurrent, 'b.', 'MarkerSize', 15);  % Drone position  

    % Pause to simulate movement  
    pause(speed);  

    % Hover at midpoint  
    if i == midPointIdx  
        pause(hoverDuration);  
    end  
end  

% Final landing visualization at the endpoint  
plot3(xPath(end), yPath(end), landingHeight, 'bo', 'MarkerSize', 15, 'LineWidth', 2, 'DisplayName', 'Final Landing Position');  

% Additional finishing touches  
hold off;  
view(3);  % Set 3D view for better perspective  
rotate3d on;  % Enable 3D rotation for interactive viewing