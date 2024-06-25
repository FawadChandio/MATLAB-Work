function preprocess_and_extract_features()
    Path = 'D:\MATLAB Tasks\client-35\Electromyographic datas\Dataset Reposistory\EMG Dataset Reposistory\01_Deltoid\'; % example path
    FS = 32768; % sampling frequency
    FSR = FS / 8; % resampled frequency (to reduce processing time)
    total_files_to_process = 20; % Limit the number of files processed

    Dir = dir(Path); % List folder contents
    SubDir = {Dir.name}; % Get the name fields contents only

    % Check if SubDir has at least 2 elements
    if numel(SubDir) >= 2
        SubDir(1:2) = []; % Delete the 2 first terms added by the OS (windows)
    end

    file_count = 0;

    % Initialize feature and label storage
    features = [];
    labels = []; % Assuming you have a way to assign labels to each file

    [LPFa, LPFb] = butter(3, 3000 / (FS / 2), 'low'); % Lowpass filter
    [HPFa, HPFb] = butter(3, 15 / (FSR / 2), 'high'); % Highpass filter
    [a50, b50] = butter(3, [49 50] / (FSR / 2), 'stop'); % 50Hz Component elimination filter

    %% Access to Signals        
    for j = 1:numel(SubDir)
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

        for i = 1:numel(sig)
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

                %% Feature Extraction using Continuous Wavelet Transform
                % Perform Continuous Wavelet Transform
                [cfs, frequencies] = cwt(EMG, 'amor');

                % Extract features from the wavelet coefficients
                % Here we use mean and standard deviation of the absolute values of the coefficients as an example
                feature_vector = [mean(abs(cfs), 2)', std(abs(cfs), 0, 2)'];

                % Assuming you have a way to get the label for each file
                % Replace the following line with your own method of assigning labels
                label = get_label_for_file(path2); % You need to implement this function

                % Store the features and corresponding label
                features = [features; feature_vector];
                labels = [labels; label];

                file_count = file_count + 1; % Increment the file count
            end
        end
    end

    %% Save Features and Labels
    save('emg_features_labels.mat', 'features', 'labels');
    disp('Features and labels saved to emg_features_labels.mat');
end

%% Function to assign labels to files
function label = get_label_for_file(filepath)
    % Implement your logic to assign a label based on the file path or file content
    % For example:
    % label = 'Healthy'; % or 'Patient' based on the file name or content

    % Placeholder implementation (modify as needed)
    if contains(filepath, 'healthy')
        label = 'Healthy';
    else
        label = 'Patient';
    end
end
