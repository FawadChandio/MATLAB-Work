% Open Simulink and create a new model
modelName = 'MicrogridModel';
new_system(modelName);
open_system(modelName);

% Add Blocks for Solar and Wind Generation
add_block('simulink/Sources/Random Number', [modelName, '/SolarGeneration']);
set_param([modelName, '/SolarGeneration'], 'Position', [100, 100, 150, 130]);

add_block('simulink/Sources/Random Number', [modelName, '/WindGeneration']);
set_param([modelName, '/WindGeneration'], 'Position', [100, 200, 150, 230]);

% Add Block for Diesel Generator
add_block('simulink/Sources/Constant', [modelName, '/DieselGeneration']);
set_param([modelName, '/DieselGeneration'], 'Value', '50'); % Example constant value
set_param([modelName, '/DieselGeneration'], 'Position', [100, 300, 150, 330]);

% Add Block for Battery Storage
add_block('simulink/Continuous/Integrator', [modelName, '/BatteryStorage']);
set_param([modelName, '/BatteryStorage'], 'InitialCondition', '100'); % Initial SoC
set_param([modelName, '/BatteryStorage'], 'Position', [300, 150, 350, 180]);

% Add Blocks for Load Demand
add_block('simulink/Sources/Signal Builder', [modelName, '/LoadDemand']);
set_param([modelName, '/LoadDemand'], 'Position', [100, 400, 150, 430]);

% Add Blocks for Grid Interaction
add_block('simulink/Commonly Used Blocks/Gain', [modelName, '/BuyPrice']);
set_param([modelName, '/BuyPrice'], 'Gain', '0.1'); % Example buying price
set_param([modelName, '/BuyPrice'], 'Position', [500, 100, 550, 130]);

add_block('simulink/Commonly Used Blocks/Gain', [modelName, '/SellPrice']);
set_param([modelName, '/SellPrice'], 'Gain', '0.05'); % Example selling price
set_param([modelName, '/SellPrice'], 'Position', [500, 200, 550, 230]);

% Add Block for Control Logic (MATLAB Function Block)
add_block('simulink/User-Defined Functions/MATLAB Function', [modelName, '/ControlLogic']);
set_param([modelName, '/ControlLogic'], 'Position', [300, 300, 400, 330]);

% Add Scopes for Visualization
add_block('simulink/Sinks/Scope', [modelName, '/ScopeGeneration']);
set_param([modelName, '/ScopeGeneration'], 'Position', [700, 100, 750, 130]);

add_block('simulink/Sinks/Scope', [modelName, '/ScopeBattery']);
set_param([modelName, '/ScopeBattery'], 'Position', [700, 200, 750, 230]);

add_block('simulink/Sinks/Scope', [modelName, '/ScopeLoad']);
set_param([modelName, '/ScopeLoad'], 'Position', [700, 300, 750, 330]);

% Add Mux block to combine signals
add_block('simulink/Signal Routing/Mux', [modelName, '/Mux']);
set_param([modelName, '/Mux'], 'Inputs', '3');
set_param([modelName, '/Mux'], 'Position', [250, 150, 275, 230]);

% Connect Generation Sources to Mux
add_line(modelName, 'SolarGeneration/1', 'Mux/1', 'autorouting', 'on');
add_line(modelName, 'WindGeneration/1', 'Mux/2', 'autorouting', 'on');
add_line(modelName, 'DieselGeneration/1', 'Mux/3', 'autorouting', 'on');

% Connect Mux to Battery Storage
add_line(modelName, 'Mux/1', 'BatteryStorage/1', 'autorouting', 'on');

% Connect Battery Storage to Control Logic
add_line(modelName, 'BatteryStorage/1', 'ControlLogic/1', 'autorouting', 'on');

% Connect Load Demand to Control Logic
add_line(modelName, 'LoadDemand/1', 'ControlLogic/2', 'autorouting', 'on');

% Connect Control Logic to Buy and Sell Prices
add_line(modelName, 'ControlLogic/1', 'BuyPrice/1', 'autorouting', 'on');
add_line(modelName, 'ControlLogic/2', 'SellPrice/1', 'autorouting', 'on');

% Connect Outputs to Scopes
add_line(modelName, 'SolarGeneration/1', 'ScopeGeneration/1', 'autorouting', 'on');
add_line(modelName, 'BatteryStorage/1', 'ScopeBattery/1', 'autorouting', 'on');
add_line(modelName, 'LoadDemand/1', 'ScopeLoad/1', 'autorouting', 'on');

% Define the Control Logic function
matlabFunctionCode = ...
    ['function [buy, sell] = ControlLogic(battery, load)', newline, ...
    'solar_gen = 50;', newline, ...
    'wind_gen = 30;', newline, ...
    'diesel_gen = 20;', newline, ...
    'total_gen = solar_gen + wind_gen + diesel_gen;', newline, ...
    'if total_gen > load', newline, ...
    '    excess = total_gen - load;', newline, ...
    '    if battery < 100', newline, ...
    '        battery = battery + excess;', newline, ...
    '        sell = 0;', newline, ...
    '    else', newline, ...
    '        sell = excess;', newline, ...
    '    end', newline, ...
    '    buy = 0;', newline, ...
    'else', newline, ...
    '    deficit = load - total_gen;', newline, ...
    '    if battery > 0', newline, ...
    '        battery = battery - deficit;', newline, ...
    '        buy = 0;', newline, ...
    '    else', newline, ...
    '        buy = deficit;', newline, ...
    '    end', newline, ...
    '    sell = 0;', newline, ...
    'end', newline, ...
    'end'];

% Set the MATLAB Function block code
block = [modelName, '/ControlLogic'];
open_system(block);
set_param(block, 'FunctionName', 'ControlLogic');
set_param(block, 'FunctionDefinition', matlabFunctionCode);
% Save the model
save_system(modelName);

% Run the simulation
sim(modelName);
