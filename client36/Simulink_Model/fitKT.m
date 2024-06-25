function [T90, eps, tn, zeta, sigma, fn] = fitKT(time, acceleration, guessEnvelope, guessSpectrum, varargin)
    % Refine model parameters based on provided data
    dataPlot = 'no'; % Default value for data plot
    
    % Parse additional options
    for i = 1:length(varargin)
        if strcmp(varargin{i}, 'dataPlot')
            dataPlot = varargin{i+1};
        end
    end
    
    % Combine initial guesses for envelope and spectrum parameters
    initialParameters = [guessEnvelope, guessSpectrum];
    
    % Define objective function for parameter optimization
    objectiveFunction = @(parameters) calculateObjective(parameters, time, acceleration);
    
    % Optimize parameters using nonlinear least squares
    options = optimoptions('lsqnonlin', 'Display', 'off');
    refinedParameters = lsqnonlin(objectiveFunction, initialParameters, [], [], options);
    
    % Extract refined parameters
    T90 = refinedParameters(1);
    eps = refinedParameters(2);
    tn = refinedParameters(3);
    zeta = refinedParameters(4);
    sigma = refinedParameters(5);
    fn = refinedParameters(6);
    
    % Plot data if requested
    if strcmp(dataPlot, 'yes')
        [simulated_acceleration, ~] = seismSim(sigma, fn, zeta, linspace(0, 40, length(time)), T90, eps, tn);
        plotGroundMotionResults(time, acceleration, simulated_acceleration);
    end
end

function plotGroundMotionResults(time, acceleration, simulated_acceleration)
    % Plot ground motion results
    figure;
    plot(time, acceleration, 'b', time, simulated_acceleration, 'r--');
    xlabel('Time (s)');
    ylabel('Ground Acceleration (m/s^2)');
    title('Fitted Ground Motion');
    legend('Original Data', 'Fitted Data');
    grid on;
    set(gca, 'FontName', 'Arial', 'FontSize', 12);
    set(gcf, 'color', 'w');
end

function error = calculateObjective(parameters, time, acceleration)
    % Calculate objective function to minimize during parameter optimization
    T90 = parameters(1);
    eps = parameters(2);
    tn = parameters(3);
    zeta = parameters(4);
    sigma = parameters(5);
    fn = parameters(6);
    
    % Simulate ground motion with the provided parameters
    [simulated_acceleration, ~] = seismSim(sigma, fn, zeta, linspace(0, 40, length(time)), T90, eps, tn);
    
    % Truncate simulated acceleration to match the length of the time vector
    simulated_acceleration = simulated_acceleration(1:length(time));
    
    % Compute error between simulated and actual acceleration
    error = acceleration - simulated_acceleration;
end
