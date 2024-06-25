% Load features and labels
load('emg_features_labels.mat', 'features', 'labels');

% Convert labels to categorical using cellstr
categorical_labels = categorical(cellstr(labels));

% Save features, categorical_labels, and original labels in a new .mat file
train_data = struct('features', features, 'categorical_labels', categorical_labels, 'labels', labels);
save('train_data.mat', 'train_data');
disp('Training data saved to train_data.mat');

% Plot a sample of the features
figure;
subplot(2, 1, 1);
plot(features(1, :)); % Plot the first sample of features
title('EMG Feature Sample');
xlabel('Sample');
ylabel('Feature Value');

% Plot a sample of the categorical labels
subplot(2, 1, 2);
plot(categorical_labels(1:20)); % Plot the first 20 categorical labels
title('Categorical Labels Sample');
xlabel('Sample');
ylabel('Label');
