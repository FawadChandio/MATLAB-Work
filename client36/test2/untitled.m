% Clear workspace, close all figures, and clear command window
clearvars;
close all;
clc;

% Define parameters for earthquake excitation
frequencies = linspace(0, 40, 2048);  % Frequency vector (Hz)
zeta = 0.3;                           % Bandwidth of the earthquake excitation
sigma = 0.3;                          % Standard deviation of the excitation
dominant_frequency = 5;               % Dominant frequency of the earthquake excitation (Hz)
envelope_value_at_90_percent_duration = 0.3;  % Value of the envelope function at 90% of the duration
normalized_duration_time_at_peak = 0.4;       % Normalized duration time when ground motion achieves peak
duration_of_ground_motion = 30;               % Duration of ground motion (seconds)

% Simulate ground motion
[ground_acceleration, time_vector] = simulateGroundMotion(sigma, dominant_frequency, zeta, frequencies, ...
    envelope_value_at_90_percent_duration, normalized_duration_time_at_peak, duration_of_ground_motion); 

% Initial guesses for envelope and spectrum parameters
initial_guess_envelope = [0.33, 0.43, 50]; 
initial_guess_spectrum = [1, 1, 5]; 

% Refine the model parameters
[T90, eps, tn, zeta, sigma, fn] = refineModelParameters(time_vector, ground_acceleration, ...
    initial_guess_envelope, initial_guess_spectrum);

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
    dt = tn / (length(frequencies) - 1);  % Time step
    time = (0:dt:tn);            % Time vector
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

function [T90, eps, tn, zeta, sigma, fn] = refineModelParameters(time, acceleration, guessEnvelope, guessSpectrum)
    % Refine model parameters based on provided data
    
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
end

function error = calculateObjective(parameters, time, acceleration)
    % Calculate objective function to minimize during parameter optimization
    T90 = parameters(1);
    eps = parameters(2);
    tn = parameters(3);
    zeta = parameters(4);
    sigma = parameters(5);
    fn = parameters(6);
    
    [simulated_acceleration, ~] = simulateGroundMotion(sigma, fn, zeta, linspace(0, 40, length(time)), T90, eps, tn);
    error = acceleration - simulated_acceleration;
end
