% Clear workspace, close all figures, and clear command window
clearvars;
close all;
clc;

% Define parameters for earthquake excitation
frequencies = linspace(0, 40, 2048);  
zeta = 0.5;                           
sigma = 0.3;                          
dominant_frequency = 2;               
envelope_value_at_90_percent_duration = 0.3;  
normalized_duration_time_at_peak = 0.5;      
duration_of_ground_motion = 1;               

% Simulate ground motion
[ground_acceleration, time_vector] = simulateGroundMotion(sigma, dominant_frequency, zeta, frequencies, ...
    envelope_value_at_90_percent_duration, normalized_duration_time_at_peak, duration_of_ground_motion); 

% Plot ground motion results
plotGroundMotionResults(time_vector, ground_acceleration);

% Initial guesses for envelope and spectrum parameters
initial_guess_envelope = [0.33, 0.43, 50]; 
initial_guess_spectrum = [1, 1, 5]; 

% Refine the model parameters
[T90, eps, tn, zeta, sigma, fn] = refineModelParameters(time_vector, ground_acceleration, ...
    initial_guess_envelope, initial_guess_spectrum, 'dataPlot', 'yes');

% Display refined parameters
disp('Refined Parameters:');
disp(['T90: ', num2str(T90)]);
disp(['Epsilon: ', num2str(eps)]);
disp(['Duration: ', num2str(tn), ' seconds']);
disp(['Bandwidth: ', num2str(zeta)]);
disp(['Standard Deviation: ', num2str(sigma)]);
disp(['Dominant Frequency: ', num2str(fn), ' Hz']);

function [acceleration, time] = simulateGroundMotion(sigma, fn, zeta, frequencies, T90, eps, tn)
    % Simulate ground motion based on specified parameters
    dt = tn / length(frequencies);  % Time step
    time = (0:dt:tn-dt);            % Time vector
    omega_n = 2 * pi * fn;          % Dominant angular frequency
    transfer_function = 1 ./ ((1 - (frequencies/fn).^2) + 2i*zeta*(frequencies/fn)); % Transfer function
    
    % Generate random phase spectrum
    random_phase_spectrum = 2 * pi * rand(size(frequencies));
    X = sqrt(2 * sigma^2 * dt) .* abs(transfer_function) .* exp(1i*random_phase_spectrum);
    
    % Inverse Fourier transform to obtain time domain signal
    acceleration = real(ifft(X, 'symmetric'));
    
    % Apply envelope function
    envelope_function = exp(-time/T90) .* (time/tn).^eps;
    acceleration = acceleration .* envelope_function;
end

function plotGroundMotionResults(time, acceleration)
    % Plot ground motion results
    figure;
    plot(time, acceleration, 'b');
    xlabel('Time (s)');
    ylabel('Ground Acceleration (m/s^2)');
    title('Simulated Ground Movement');
    grid on;
    set(gca, 'FontName', 'Arial', 'FontSize', 12);
    set(gcf, 'color', 'w');
end

function [T90, eps, tn, zeta, sigma, fn] = refineModelParameters(time, acceleration, guessEnvelope, guessSpectrum, varargin)
    % Refine model parameters based on provided data
    dataPlot = 'no';
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
        [simulated_acceleration, ~] = simulateGroundMotion(sigma, fn, zeta, linspace(0, 40, 2048), T90, eps, tn);
        plotGroundMotionResults(time, acceleration);
        hold on;
        plot(time, simulated_acceleration, 'r--');
        legend('Original Data', 'Fitted Data');
        hold off;
    end
end

function error = calculateObjective(parameters, time, acceleration)
    % Calculate objective function to minimize during parameter optimization
    T90 = parameters(1);
    eps = parameters(2);
    tn = parameters(3);
    zeta = parameters(4);
    sigma = parameters(5);
    fn = parameters(6);
    
    [simulated_acceleration, ~] = simulateGroundMotion(sigma, fn, zeta, linspace(0, 40, 2048), T90, eps, tn);
    error = acceleration - simulated_acceleration;
end
