function [y, t] = seismSim(sigma, fn, zeta, f, T90, eps, tn)
    % SEISMSIM generates synthetic ground motion data.
    %
    % Inputs:
    %   sigma - Standard deviation of the excitation (m/s^2)
    %   fn - Dominant frequency of the excitation (Hz)
    %   zeta - Bandwidth of the excitation
    %   f - Frequency vector (Hz)
    %   T90 - Envelope function value at 90% duration (s)
    %   eps - Normalized duration time when peak is achieved
    %   tn - Duration of ground motion (seconds)
    %
    % Outputs:
    %   y - Synthetic ground acceleration record (m/s^2)
    %   t - Time vector (s)
    
    % Validate input arguments
    validateattributes(sigma, {'numeric'}, {'scalar', 'positive'}, 'seismSim', 'sigma');
    validateattributes(fn, {'numeric'}, {'scalar', 'positive'}, 'seismSim', 'fn');
    validateattributes(zeta, {'numeric'}, {'scalar', 'nonnegative'}, 'seismSim', 'zeta');
    validateattributes(f, {'numeric'}, {'vector', 'nonempty', 'positive'}, 'seismSim', 'f');
    validateattributes(T90, {'numeric'}, {'scalar', 'positive'}, 'seismSim', 'T90');
    validateattributes(eps, {'numeric'}, {'scalar', 'nonnegative'}, 'seismSim', 'eps');
    validateattributes(tn, {'numeric'}, {'scalar', 'positive'}, 'seismSim', 'tn');
    
    % Time step
    dt = tn / length(f);
    
    % Time vector
    t = (0:dt:tn-dt);
    
    % Dominant angular frequency
    omega_n = 2 * pi * fn;
    
    % Transfer function
    H = 1 ./ ((1 - (f/fn).^2) + 2i*zeta*(f/fn));
    
    % Generate random phase spectrum
    phi = 2 * pi * rand(size(f));
    X = sqrt(2 * sigma^2 * dt) .* abs(H) .* exp(1i*phi);
    
    % Inverse Fourier transform to get time domain signal
    y = real(ifft(X, 'symmetric'));
    
    % Envelope function
    A = exp(-t/T90) .* (t/tn).^eps;
    
    % Apply envelope to the signal
    y = y .* A;
end
