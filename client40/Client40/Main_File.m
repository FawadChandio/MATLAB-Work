% Load path data from CSV file 
clc
pathData = readtable('D:\MATLAB Tasks\client40\parrotMinidroneCompetition-main\correct_waypoints.csv');  
xPath = pathData.Var1; 
yPath = pathData.Var2;  


xPath = xPath(:)';  
yPath = yPath(:)';


xPath = flip(xPath);
yPath = flip(yPath);

% Define simulation parameters  
takeoffHeight = 3;        
hoverHeight = 0.5;   % hover at 0.5m      
landingHeight = 0;         
hoverDuration = 2;        
speed = 0.05;              

% Initial settings  
z = ones(size(xPath)) * takeoffHeight;   
midPointIdx = ceil(length(xPath) / 2);    
z(midPointIdx) = hoverHeight;          

% Circular path points for initial takeoff rotation
circleRadius = 0.1;
theta = linspace(0, 2*pi, 50);  
xCircle = xPath(1) + circleRadius * cos(theta);
yCircle = yPath(1) + circleRadius * sin(theta);

% Ensure xCircle and yCircle are row vectors
xCircle = xCircle(:)';
yCircle = yCircle(:)';


xPath = [xCircle, xPath];
yPath = [yCircle, yPath];
z = [ones(size(xCircle)) * takeoffHeight, z];

% Save the path data for Simulink model
save('dronePathData.mat', 'xPath', 'yPath', 'z');

% Setup figure for simulation with professional visual settings  
figure('Name', 'Drone Path Simulation', 'NumberTitle', 'off', 'Color', [0.95, 0.95, 0.95]);  
hold on;  
grid on;  
axis equal;  
axis vis3d;  

% Set background color and plot the path  
plot3(xPath, yPath, zeros(size(xPath)), 'r-', 'LineWidth', 2, 'DisplayName', 'Planned Path');  

% Mark starting, hovering, and landing points with circles  
fill(circleRadius * cos(theta) + xPath(1), circleRadius * sin(theta) + yPath(1), 'g', 'FaceAlpha', 0.5, 'DisplayName', 'Start (Takeoff)');  
plot3(xPath(1), yPath(1), takeoffHeight, 'go', 'MarkerSize', 10, 'LineWidth', 2);  

% Hover point (Middle)  
fill(circleRadius * cos(theta) + xPath(midPointIdx), circleRadius * sin(theta) + yPath(midPointIdx), 'm', 'FaceAlpha', 0.5, 'DisplayName', 'Hover Point');  
plot3(xPath(midPointIdx), yPath(midPointIdx), hoverHeight, 'mo', 'MarkerSize', 10, 'LineWidth', 2);  

% Landing point (End)  
fill(circleRadius * cos(theta) + xPath(end), circleRadius * sin(theta) + yPath(end), 'r', 'FaceAlpha', 0.5, 'DisplayName', 'End (Landing)');  
plot3(xPath(end), yPath(end), landingHeight, 'ro', 'MarkerSize', 10, 'LineWidth', 2);  

% Labels and legend for clarity  
title('3D Drone Path Simulation with Takeoff, Hover, and Landing', 'FontSize', 14, 'FontWeight', 'bold');  
xlabel('X Position (m)', 'FontSize', 12, 'FontWeight', 'bold');  
ylabel('Y Position (m)', 'FontSize', 12, 'FontWeight', 'bold');  
zlabel('Z Position (Altitude, m)', 'FontSize', 12, 'FontWeight', 'bold');  
legend('Location', 'best');  

% Simulate drone movement along the path  
for i = 1:length(xPath)  
      
    zCurrent = z(i);  
    plot3(xPath(i), yPath(i), zCurrent, 'b.', 'MarkerSize', 15);  % Drone position  

     
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
view(3);  % 
rotate3d on;  
