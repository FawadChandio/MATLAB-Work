%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                                        %
%  This script facilitates signal reading, performs minimal filtering, and displays the  %
%  signals for a limited number of samples.                                              %
%                                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc;
%% Initializing
Path = 'D:\MATLAB Tasks\client-35\Electromyographic datas\Dataset Reposistory\EMG Dataset Reposistory\02_Biceps Brachii\'; % example path
FS = 32768; % sampling frequency
FSR = FS / 8; % resampled frequency (to reduce processing time)

Dir = dir(Path); % list folder contents
SubDir = {Dir.name}; % get the name fields contents only

% Check if SubDir has at least 2 elements
if numel(SubDir) >= 2
    SubDir(1:2) = []; % delete the 2 first terms added by the OS (windows)
end

% Limit the total number of files processed
total_files_to_process = 20;
file_count = 0;

[LPFa, LPFb] = butter(3, 3000 / (FS / 2), 'low'); % lowpass filter
[HPFa, HPFb] = butter(3, 15 / (FSR / 2), 'high'); % highpass filter
[a50, b50] = butter(3, [49 50] / (FSR / 2), 'stop'); % 50Hz Component elimination filter

%% Access to Signals        
for j = 1:numel(SubDir) % Iterate through each subdirectory
    if file_count >= total_files_to_process
        break; % Stop if the total file count reaches the limit
    end
    
    path1 = fullfile(Path, SubDir{j});                         
    CDir = dir(path1);
    sig = {CDir.name};
    
    % Check if sig has at least 2 elements
    if numel(sig) >= 2
        sig(1:2) = []; % Delete the 2 first terms added by the OS (windows)
    end
    
    for i = 1:numel(sig) % Iterate through each file in the subdirectory
        if file_count >= total_files_to_process
            break; % Stop if the total file count reaches the limit
        end
        
        path2 = fullfile(path1, sig{i});
        
        % Check if the file exists and is not a directory
        if isfile(path2) && endsWith(path2, '.asc')
            % Read the .asc file
            data = dlmread(path2); % Load signal from .asc file
            
            % Check if loaded data is a matrix or array
            if ismatrix(data)
                EMG = data(:,1); % Assuming the EMG signal is in the first column
            else
                error('Unexpected data format in %s', path2);
            end
            
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
            
            % Create a separate figure for each EMG signal time-domain plot
            figure;
            plot(t, EMG);
            ylim([-1500 1500])
            title(sprintf('EMG - File %d from SubDir %d', i, j))
            xlabel('Time (s)')
            ylabel('Amplitude (mV)')
            
            %% Continuous Wavelet Transform
            scales = 1:200;
            
            % Create a separate figure for each EMG signal CWT plot
            figure;
            try
                cwt(EMG, scales, 'sym5', 'plot'); % Perform CWT on EMG signal
                title(sprintf('CWT of EMG - File %d from SubDir %d', i, j))
            catch ME
                warning('Failed to perform CWT on file %d from SubDir %d: %s', i, j, ME.message);
            end
            
            file_count = file_count + 1; % Increment the file count
        end
    end
end
