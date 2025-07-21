function preprocess_and_extract_features()
    % Path to data
    Path = 'D:\MATLAB Tasks\client-35\Electromyographic datas\Dataset Reposistory\EMG Dataset Reposistory\01_Deltoid\'; % example path
    FS = 32768; % sampling frequency
    FSR = FS / 8; % resampled frequency (to reduce processing time)

    % List folder contents
    Dir = dir(Path); 
    SubDir = {Dir.name}; 
    if numel(SubDir) >= 2
        SubDir(1:2) = []; 
    end

    % Initialize feature and label arrays
    all_features = [];
    all_labels = [];

    % Process each file
    for j = 1:numel(SubDir)
        path1 = fullfile(Path, SubDir{j});                         
        CDir = dir(path1);
        sig = {CDir.name};
        if numel(sig) >= 2
            sig(1:2) = [];
        end
        
        for i = 1:numel(sig)
            path2 = fullfile(path1, sig{i});
            if isfile(path2)
                data = load(path2);
                
                % Check if data is a numeric array (potentially containing the EMG data)
                if isnumeric(data)
                    EMG = data; % Assume data contains the EMG signal directly
                else
                    error('Loaded data is not in a recognized format.');
                end

                % Ensure EMG data is a double-precision array
                EMG = double(EMG);

                % Proceed with processing the EMG data...
                % (filtering, resampling, feature extraction, etc.)
                
                % Placeholder code for feature extraction (replace with actual feature extraction code)
                features = extract_features(EMG);
                
                % Append features and corresponding label to arrays
                all_features = [all_features; features];
                all_labels = [all_labels; get_label_for_file(path2)];
            end
        end
    end

    % Save features and labels
    save('emg_features_labels.mat', 'all_features', 'all_labels');
    disp('Features and labels saved to emg_features_labels.mat');
end

function label = get_label_for_file(~)
    % Add code here to extract label from filepath or filename
    % Example: label = extract_label_from_filepath(filepath);
    % You need to implement this function
    label = 'Unknown'; % Placeholder label
end

function features = extract_features(~)
    % Add code here to extract features from EMG signal
    % You need to implement this function
    features = zeros(1, 10); % Placeholder features
end
