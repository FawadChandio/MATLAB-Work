%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                        %
%  This script facilitates signal reading, performs filtering, and displays the signals  %
%                                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Initializing
Path = 'D:\MATLAB Tasks\client-35\Electromyographic datas\Dataset Reposistory\EMG Dataset Reposistory\01_Deltoid\'; % example path
FS = 32768; % sampling frequency
FSR = FS / 8; % resampled frequency (to reduce processing time)

Dir = dir(Path); % list folder contents
SubDir = {Dir.name}; % get the name fields contents only

% Check if SubDir has at least 2 elements
if numel(SubDir) >= 2
    SubDir(1:2) = []; % delete the 2 first terms added by the OS (windows)
end

com = 0;

[LPFa, LPFb] = butter(3, 3000 / (FS / 2), 'low'); % lowpass filter
[HPFa, HPFb] = butter(3, 15 / (FSR / 2), 'high'); % highpass filter
[a50, b50] = butter(3, [49 50] / (FSR / 2), 'stop'); % 50Hz Component elimination filter

%% Access to Signals        
for j = 1:numel(SubDir) % Returns the number of elements in SubDir
    path1 = fullfile(Path, SubDir{j});                         
    CDir = dir(path1);
    sig = {CDir.name};
    
    % Check if sig has at least 2 elements
    if numel(sig) >= 2
        sig(1:2) = []; % Delete the 2 first terms added by the OS (windows)
    end
    
    for i = 1:numel(sig) % Number of elements in sig
        path2 = fullfile(path1, sig{i});
        
        % Check if the file exists and is not a directory
        if isfile(path2)
            data = load(path2); % Load signal
            
            % Check if loaded data is a structure
            if isstruct(data)
                % Assuming the actual EMG data is stored in a field of the structure
                fieldNames = fieldnames(data);
                EMG = data.(fieldNames{1}); % Access the first field
            else
                EMG = data; % Directly use the loaded data if it's not a structure
            end
            
            com = com + 1;
            
            %% Filtering         
            EMG_F = filtfilt(LPFa, LPFb, EMG); % Filtered signal
            EMG_FR = resample(EMG_F, 1, 8); % Resampled Filtered signal
            EMG_FRC = filtfilt(a50, b50, EMG_FR); % 50Hz Component elimination
            EMG_FRCF = filtfilt(HPFa, HPFb, EMG_FRC); % Filtered signal
            EMG = EMG_FRCF; % Filtered, resampled, then filtered signal
            
            %% Display
            N = length(EMG); % Signal length 
            T = N / FSR; % Signal duration
            t = (0:N-1) / FSR; % Time
            
            figure(com);
            plot(t, EMG);
            ylim([-1500 1500])
            title('EMG')
            xlabel('Time (s)')
            ylabel('Amplitude (mV)')
            
            %% Continuous Wavelet Transform
            scales = 1:200;
            figure(201)
            cwt(EMG, scales, 'sym5', 'plot'); % Perform CWT on EMG signal
        end
    end
end
