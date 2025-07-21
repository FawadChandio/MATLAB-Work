% testPrediction.m
app = TransformerDiagnosticApp;  % Initialize your app

% Define gas values [H2, CH4, C2H6, C2H4, C2H2, CO, temp, load]
sampleGases = [120, 85, 45, 60, 8, 350, 72, 80]; 

% Get prediction
[prediction, confidence, report] = predictFaultFromGases(app, sampleGases);

% Display results
disp('=== Transformer Fault Prediction ===');
disp(['Predicted Fault: ' prediction]);
disp(['Confidence: ' num2str(confidence) '%']);
disp('Full Report:');
disp(report);