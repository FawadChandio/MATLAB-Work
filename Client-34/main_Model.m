% Create a new Simulink model for evaluating DC-DC converter topologies for EVs, PHEVs
modelName = 'EV_DCDC_Converter_Model_New';
open_system(new_system(modelName));

% Add blocks to the model
% Custom Battery Model (Voltage Source)
add_block('simulink/Commonly Used Blocks/Constant', [modelName '/Battery']);
set_param([modelName '/Battery'], 'Value', '400');  % Set the initial battery voltage (in volts)
% Switch (Controlled)
add_block('simulink/Commonly Used Blocks/Switch', [modelName '/Switching Component']);
% Custom Diode Behavior
add_block('simulink/Commonly Used Blocks/Gain', [modelName '/Diode']);
set_param([modelName '/Diode'], 'Gain', '1', 'Multiplication', 'Input');
% Inductor
add_block('powerlib/Elements/Electrical Elements/Inductor', [modelName '/Inductor']);
% Capacitor
add_block('powerlib/Elements/Electrical Elements/Capacitor', [modelName '/Capacitor']);
% Scope for Monitoring
add_block('simulink/Sinks/Scope', [modelName '/Converter Output']);

% Connect the blocks
% Battery to Switching Component
add_line(modelName, 'Battery/1', 'Switching Component/1');
% Switching Component to Inductor
add_line(modelName, 'Switching Component/1', 'Inductor/1');
% Inductor to Capacitor
add_line(modelName, 'Inductor/1', 'Capacitor/1');
% Capacitor to Switching Component
add_line(modelName, 'Capacitor/1', 'Switching Component/2');
% Capacitor to Scope
add_line(modelName, 'Capacitor/1', 'Converter Output/1');
% Switching Component to Diode
add_line(modelName, 'Switching Component/2', 'Diode/1');
% Diode to Inductor
add_line(modelName, 'Diode/1', 'Inductor/2');

% Save and open the model
save_system(modelName);
open_system(modelName);
