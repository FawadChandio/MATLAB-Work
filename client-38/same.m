% Create a new Simulink model with a different name
model = 'DiffuserToJetSystem_V2';
new_system(model);
open_system(model);

% Add the Air Source block
airSourceBlock = [model, '/Air Source'];
add_block('simulink/Sources/Constant', airSourceBlock, ...
    'Value', '10', 'Position', [100, 100, 140, 120]);

% Add the Diffuser block
diffuserBlock = [model, '/Diffuser'];
add_block('simulink/Commonly Used Blocks/Gain', diffuserBlock, ...
    'Gain', '0.5', 'Position', [200, 100, 240, 120]);

% Add the Jet System block
jetSystemBlock = [model, '/Jet System'];
add_block('simulink/Commonly Used Blocks/Gain', jetSystemBlock, ...
    'Gain', '2', 'Position', [300, 100, 340, 120]);

% Add the Environment subsystem
environmentSubsystem = [model, '/Environment'];
add_block('simulink/Ports & Subsystems/Subsystem', environmentSubsystem, ...
    'Position', [400, 75, 500, 145]);

% Open the Environment subsystem to add internal blocks
open_system(environmentSubsystem);

% Add input and output ports to the Environment subsystem
add_block('simulink/Ports/Input', [environmentSubsystem, '/In1'], ...
    'Position', [20, 30, 40, 50]);
add_block('simulink/Ports/Output', [environmentSubsystem, '/Out1'], ...
    'Position', [320, 30, 340, 50]);

% Add Scope blocks inside the Environment subsystem for measurements
add_block('simulink/Sinks/Scope', [environmentSubsystem, '/Scope1'], ...
    'Position', [100, 50, 150, 70]);
add_block('simulink/Sinks/Scope', [environmentSubsystem, '/Scope2'], ...
    'Position', [100, 100, 150, 120]);

% Connect the internal blocks within the Environment subsystem
add_line(environmentSubsystem, 'In1/1', 'Scope1/1');
add_line(environmentSubsystem, 'In1/1', 'Scope2/1');
add_line(environmentSubsystem, 'Scope1/1', 'Out1/1');

% Close the Environment subsystem
close_system(environmentSubsystem);

% Add connections between the main model blocks
add_line(model, 'Air Source/1', 'Diffuser/1');
add_line(model, 'Diffuser/1', 'Jet System/1');
add_line(model, 'Jet System/1', 'Environment/1');

% Save and close the model
save_system(model);
close_system(model);
