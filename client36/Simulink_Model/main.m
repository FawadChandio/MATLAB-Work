% Define time vector
t = 0:0.01:10;

% Define seismic sensor signals
seismic_signal_1 = sin(0.1*t);  % Seismic sensor 1 signal
seismic_signal_2 = cos(0.2*t);  % Seismic sensor 2 signal

% Define overload sensor signal
overload_signal = ones(size(t)); % Overload sensor signal

% Plot the signals
figure;
subplot(3,1,1);
plot(t, seismic_signal_1, 'b');
title('Seismic Sensor 1 Signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

% subplot(3,1,2);
% plot(t, seismic_signal_2, 'r');
% title('Seismic Sensor 2 Signal');
% xlabel('Time (s)');
% ylabel('Amplitude');
% grid on
% 
% subplot(3,1,3);
% plot(t, overload_signal, 'g');
% title('Overload Sensor Signal');
% xlabel('Time (s)');
% ylabel('Amplitude');
% grid on;
