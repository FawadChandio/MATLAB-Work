clearvars;
close all;
clc;

% Define time vector
t = 0:0.01:10;

% Define seismic sensor signals
seismic_signal_1 = sin(0.1*t);  % Seismic sensor 1 signal
seismic_signal_2 = cos(0.2*t);  % Seismic sensor 2 signal

% Define overload sensor signal
overload_signal = ones(size(t)); % Overload sensor signal

% Plot the signals
figure;

% First subplot for seismic signals
subplot(3,1,1);
plot(t, seismic_signal_1, 'b');
title('Seismic Sensor 1 Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Second subplot for seismic signals
subplot(3,1,2);
plot(t, seismic_signal_2, 'r');
title('Seismic Sensor 2 Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Third subplot for overload signal
subplot(3,1,3);
plot(t, overload_signal, 'k');
title('Overload Sensor Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% Simulate ground motion
f = linspace(0, 40, 2048); % frequency vector
zeta = 0.3; % bandwidth of the earthquake excitation.
sigma = 0.3; % standard deviation of the excitation.
fn = 5; % dominant frequency of the earthquake excitation (Hz).
T90 = 0.3; % value of the envelop function at 90 percent of the duration.
eps = 0.4; % normalized duration time when ground motion achieves peak.
tn = 1; % duration of ground motion (seconds).

% function call
[y, t] = seismSim(sigma, fn, zeta, f, T90, eps, tn); 
% y: acceleration record
% t: time

% Plot ground motion results
subplot(3,1,1); % Return to the first subplot
hold on;
plot(t, y, 'm--');
hold off;

% Fitting the ground acceleration record to target spectra & envelope
guessEnvelope = [0.33, 0.43, 50]; % guess for envelope 
guessKT = [1, 1, 5]; % guess for spectrum
[T90_fit, eps_fit, tn_fit, zeta_fit, sigma_fit, fn_fit] = fitKT(t, y, guessEnvelope, guessKT, 'dataPlot', 'yes');
