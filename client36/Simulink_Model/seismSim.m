function [acceleration, time] = seismSim(sigma, fn, zeta, frequencies, T90, eps, tn)
    % Simulate ground motion based on specified parameters
    dt = tn / length(frequencies); % Time step
    time = (0:dt:tn-dt); % Time vector
    omega_n = 2 * pi * fn; % Dominant angular frequency
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
