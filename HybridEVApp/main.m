classdef HybridEVApp < matlab.apps.AppBase

    % Properties that are accessible from the main code
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        APIKeyLabel       matlab.ui.control.Label
        apiKeyField       matlab.ui.control.TextArea
        APIURLLabel       matlab.ui.control.Label
        apiUrlField       matlab.ui.control.TextArea
        runButton         matlab.ui.control.Button
        StatusLabel       matlab.ui.control.Label
        statusArea        matlab.ui.control.TextArea
    end

    % App initialization and callbacks
    methods (Access = private)

        % App startup function
        function startupFcn(app)
            % Set default values for convenience
            app.apiKeyField.Value = '8729a167fdee93d0fe086cab277d729b';
            app.apiUrlField.Value = 'https://api.openweathermap.org/data/2.5/forecast';
            % Create GUI components
            createComponents(app);
        end

        % Create GUI components (Layout)
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 500 400];
            app.UIFigure.Name = 'Hybrid EV Model Runner';
            
            % Create APIKeyLabel
            app.APIKeyLabel = uilabel(app.UIFigure);
            app.APIKeyLabel.HorizontalAlignment = 'right';
            app.APIKeyLabel.Position = [25 350 75 22];
            app.APIKeyLabel.Text = 'API Key:';

            % Create apiKeyField
            app.apiKeyField = uitextarea(app.UIFigure);
            app.apiKeyField.Position = [110 350 350 25];
            
            % Create APIURLLabel
            app.APIURLLabel = uilabel(app.UIFigure);
            app.APIURLLabel.HorizontalAlignment = 'right';
            app.APIURLLabel.Position = [25 310 75 22];
            app.APIURLLabel.Text = 'API URL:';

            % Create apiUrlField
            app.apiUrlField = uitextarea(app.UIFigure);
            app.apiUrlField.Position = [110 310 350 25];
            
            % Create runButton
            app.runButton = uibutton(app.UIFigure, 'push');
            app.runButton.ButtonPushedFcn = createCallbackFcn(app, @runButtonPushed, true);
            app.runButton.Position = [110 260 350 30];
            app.runButton.Text = 'Run Simulink Model';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.HorizontalAlignment = 'right';
            app.StatusLabel.Position = [25 220 75 22];
            app.StatusLabel.Text = 'Status:';

            % Create statusArea
            app.statusArea = uitextarea(app.UIFigure);
            app.statusArea.Editable = false;
            app.statusArea.Position = [110 20 350 220];
            app.statusArea.Value = {'Ready. Enter API info and click Run.'};
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        % Button pushed function: Run Simulink Model
        function runButtonPushed(app, event)
            app.statusArea.Value = {'Starting simulation...'};
            drawnow;

            % Disable button to prevent multiple clicks
            app.runButton.Enable = 'off';

            % Get the values from the GUI fields
            apiKey = strtrim(app.apiKeyField.Value);
            apiUrl = strtrim(app.apiUrlField.Value);

            % Call the main function with GUI inputs and the status area handle
            runHybridEVModel(app, apiKey, apiUrl);

            % Re-enable the button
            app.runButton.Enable = 'on';
        end

    end
    
    % Main logic for simulation
    methods (Access = public)
        
        function runHybridEVModel(app, apiKey, apiUrl)
            % RUNHYBRIDEVMODEL
            % Fetches live weather data, runs the simulation, and creates plots.
            
            modelName = 'HybridEVModel';
            
            % Step 1: Fetch and process weather data BEFORE the simulation starts
            app.statusArea.Value = [app.statusArea.Value; {'=== FETCHING LIVE WEATHER DATA ==='}];
            app.statusArea.Value = [app.statusArea.Value; {sprintf('API Endpoint: %s', apiUrl)}];
            app.statusArea.Value = [app.statusArea.Value; {sprintf('API Key: %s', apiKey)}];
            drawnow;
            
            lat = 50.2667;
            lon = -5.0527;
            
            try
                fullUrl = sprintf('%s?lat=%f&lon=%f&appid=%s&units=metric', ...
                    apiUrl, lat, lon, apiKey);
                
                options = weboptions('Timeout', 30);
                weatherData = webread(fullUrl, options);
                
                % Process forecast data
                n = min(40, length(weatherData.list));
                time_step_s = 3 * 3600;
                time_points_api = 0:time_step_s:time_step_s*(n-1);
                
                cloud_cover = zeros(n,1);
                wind_speed = zeros(n,1);
                
                for i = 1:n
                    rec = weatherData.list(i);
                    if isfield(rec, 'clouds') && isfield(rec.clouds, 'all')
                        cloud_cover(i) = rec.clouds.all;
                    else
                        cloud_cover(i) = 50;
                    end
                    if isfield(rec, 'wind') && isfield(rec.wind, 'speed')
                        wind_speed(i) = rec.wind.speed;
                    else
                        wind_speed(i) = 5;
                    end
                end
                
                solar_irradiance = (1 - cloud_cover/100) * 1000;
                
                % Determine weather condition
                avg_cloud_cover = mean(cloud_cover);
                avg_wind_speed = mean(wind_speed);
                if avg_cloud_cover < 30 && avg_wind_speed > 3
                    weather_condition = 2; % Excellent
                elseif avg_cloud_cover < 50
                    weather_condition = 1; % Good
                else
                    weather_condition = 0; % Poor
                end
                
                app.statusArea.Value = [app.statusArea.Value; {'Successfully fetched and processed live weather data.'}];
                
            catch ME
                app.statusArea.Value = [app.statusArea.Value; {'API fetch failed. Using default values.'}];
                app.statusArea.Value = [app.statusArea.Value; {ME.message}];
                n = 40;
                time_step_s = 3 * 3600;
                time_points_api = 0:time_step_s:time_step_s*(n-1);
                solar_irradiance = 500 + 300*sin(2*pi*(0:n-1)/n);
                wind_speed = 5 + 3*sin(2*pi*(0:n-1)/n);
                weather_condition = 1; % Good
            end
            
            % Corrected Step: Assign variables to the base workspace for Simulink to access
            assignin('base', 'irradiance_data', timeseries(solar_irradiance, time_points_api));
            assignin('base', 'wind_speed_data', timeseries(wind_speed, time_points_api));
            assignin('base', 'weather_condition_ts', timeseries(weather_condition, 0));
            
            % FIX: Calculate the simulation stop time based on the fetched data duration
            sim_stop_time = time_points_api(end);
            
            % Step 2: Build the Simulink model with From Workspace blocks
            app.statusArea.Value = [app.statusArea.Value; {'Building Simulink model...'}];
            drawnow;
            buildSimulinkModel(app, sim_stop_time);
            
            % Step 3: Run the simulation and plot the results
            app.statusArea.Value = [app.statusArea.Value; {'=== STARTING SIMULATION ==='}];
            drawnow;
            
            % Run simulation
            simOut = sim(modelName, 'ReturnWorkspaceOutputs','on');
            
            % FIX: Retrieve all logged data directly and check if it's a timeseries object.
            PpvStruct       = simOut.Ppv;
            PwindStruct     = simOut.Pwind;
            PbatStruct      = simOut.Pbat;
            PdieselStruct   = simOut.Pdiesel;
            SOCStruct       = simOut.SOC;
            TariffStruct    = simOut.Tariff;
            PemergencyStruct = simOut.Pemergency;
            PstandardStruct  = simOut.Pstandard;
            PgridStruct     = simOut.Pgrid;
            
            function [t,y] = extractTimeData(S)
                if isa(S, 'timeseries') && ~isempty(S.Data)
                    t = S.Time;
                    y = S.Data;
                else
                    t = []; y = [];
                end
            end
            
            [t, pv]         = extractTimeData(PpvStruct);
            [t, wnd]        = extractTimeData(PwindStruct);
            [t, bat]        = extractTimeData(PbatStruct);
            [t, dsl]        = extractTimeData(PdieselStruct);
            [t, soc]        = extractTimeData(SOCStruct);
            [t, tariff]     = extractTimeData(TariffStruct);
            [t, emergency]  = extractTimeData(PemergencyStruct);
            [t, standard]   = extractTimeData(PstandardStruct);
            [t, Pgrid_data] = extractTimeData(PgridStruct);
            
            % Convert time to hours for better plotting
            t_hours = t / 3600;
            
            % Create comprehensive dashboard plot
            figure('Name','Advanced Hybrid EV Charging System - Simulation Results','NumberTitle','off', 'Position', [100, 100, 1200, 900]);
            
            % 1. Energy Generation vs Demand
            subplot(4, 2, [1, 2]);
            renewable_gen = pv + wnd;
            total_demand = emergency + standard;
            plot(t_hours, renewable_gen, 'g-', 'LineWidth', 2, 'DisplayName', 'Renewables'); hold on;
            plot(t_hours, total_demand, 'r--', 'LineWidth', 2, 'DisplayName', 'Total Demand');
            plot(t_hours, emergency, 'b-', 'LineWidth', 2, 'DisplayName', 'Emergency Demand');
            ylabel('Power (kW)');
            title('Energy Generation vs Demand');
            legend('show', 'Location', 'best');
            grid on;
            xlabel('Time (hours)');
            ylim([0 1500]);
            
            % 2. Priority vs Standard Charging
            subplot(4, 2, 3);
            plot(t_hours, emergency, 'b-', 'LineWidth', 2, 'DisplayName', 'Emergency'); hold on;
            plot(t_hours, standard, 'c-', 'LineWidth', 2, 'DisplayName', 'Standard');
            ylabel('Power (kW)');
            title('Emergency vs Standard Charging');
            legend('show', 'Location', 'best');
            grid on;
            xlabel('Time (hours)');
            ylim([0 1200]);
            
            % 3. Battery State of Charge
            subplot(4, 2, 4);
            plot(t_hours, soc, 'm-', 'LineWidth', 2, 'DisplayName', 'SOC');
            ylabel('SOC (%)');
            title('Battery State of Charge');
            grid on;
            xlabel('Time (hours)');
            ylim([0 100]);
            
            % 4. Grid & Diesel Usage
            subplot(4, 2, 5);
            plot(t_hours, Pgrid_data, 'r-', 'LineWidth', 2, 'DisplayName', 'Grid'); hold on;
            plot(t_hours, dsl, 'k-', 'LineWidth', 2, 'DisplayName', 'Diesel');
            ylabel('Power (kW)');
            title('Grid & Diesel Usage');
            legend('show', 'Location', 'best');
            grid on;
            xlabel('Time (hours)');
            ylim([0 1200]);
            
            % 5. Renewable Energy Share
            renewable_share = (renewable_gen ./ total_demand) * 100;
            renewable_share(total_demand == 0) = 0;
            subplot(4, 2, 6);
            plot(t_hours, renewable_share, 'c-', 'LineWidth', 2, 'DisplayName', 'Renewable Share');
            ylabel('Percentage (%)');
            title('Renewable Energy Share');
            grid on;
            xlabel('Time (hours)');
            ylim([0 120]);
            
            % 6. Dynamic Charging Tariff
            subplot(4, 2, 7);
            plot(t_hours, tariff, 'k-', 'LineWidth', 2, 'DisplayName', 'Tariff');
            ylabel('£/kWh');
            title('Dynamic Charging Tariff');
            grid on;
            xlabel('Time (hours)');
            ylim([0 0.4]);
            
            % 7. Energy Source Distribution (Pie Chart)
            subplot(4, 2, 8);
            if ~isempty(t)
                total_renewable = trapz(t, renewable_gen) / 3600;
                total_grid = trapz(t, Pgrid_data) / 3600;
                total_diesel = trapz(t, dsl) / 3600;
            else
                total_renewable = 0;
                total_grid = 0;
                total_diesel = 0;
            end
            sources = [total_renewable, total_grid, total_diesel];
            
            if any(sources > 0)
                pie(sources, {'Renewables', 'Grid', 'Diesel'});
                title('Energy Source Distribution');
            else
                text(0.5, 0.5, 'No Energy Used', 'HorizontalAlignment', 'center', 'FontSize', 12);
                title('Energy Source Distribution');
            end
            
            % Display summary statistics
            app.statusArea.Value = [app.statusArea.Value; {'=== SIMULATION RESULTS SUMMARY ==='}];
            app.statusArea.Value = [app.statusArea.Value; {sprintf('Total Renewable Generation: %.2f kWh', total_renewable)}];
            app.statusArea.Value = [app.statusArea.Value; {sprintf('Total Grid Energy Used: %.2f kWh', total_grid)}];
            app.statusArea.Value = [app.statusArea.Value; {sprintf('Total Diesel Generator Usage: %.2f kWh', total_diesel)}];
            app.statusArea.Value = [app.statusArea.Value; {sprintf('Total Diesel Cost: £%.2f', total_diesel * 0.45)}];
            
            if ~isempty(renewable_share)
                app.statusArea.Value = [app.statusArea.Value; {sprintf('Average Renewable Share: %.2f %%', mean(renewable_share, 'omitnan'))}];
            else
                app.statusArea.Value = [app.statusArea.Value; {'Average Renewable Share: N/A'}];
            end
            
            if ~isempty(soc)
                app.statusArea.Value = [app.statusArea.Value; {sprintf('Final Battery SOC: %.2f %%', soc(end))}];
            else
                app.statusArea.Value = [app.statusArea.Value; {'Final Battery SOC: N/A'}];
            end
            
            if ~isempty(tariff)
                app.statusArea.Value = [app.statusArea.Value; {sprintf('Average Dynamic Tariff: £%.3f/kWh', mean(tariff, 'omitnan'))}];
            else
                app.statusArea.Value = [app.statusArea.Value; {'Average Dynamic Tariff: N/A'}];
            end
            
            app.statusArea.Value = [app.statusArea.Value; {'✅ Simulation finished. Comprehensive dashboard displayed.'}];
            
        end
        
        function buildSimulinkModel(app, stopTime)
            % BUILDSIMULINKMODEL
            % Creates HybridEVModel with data inputs from the base workspace.
            modelName = 'HybridEVModel';
            
            % Clean start
            if bdIsLoaded(modelName)
                close_system(modelName,0);
            end
            
            % Create and open model
            new_system(modelName);
            open_system(modelName);
            
            % Set model parameters
            set_param(modelName, 'Solver', 'ode45', ...
                'StopTime', num2str(stopTime), ...
                'SaveOutput', 'on', ...
                'SaveState', 'on', ...
                'SaveFormat', 'Dataset');
            
            % Layout helpers
            x0 = 50;  y0 = 80;
            dy = 80;
            
            % Sources
            add_block('simulink/Sources/From Workspace', [modelName '/Irradiance'], ...
                'Position', [x0 y0 x0+100 y0+40], 'VariableName', 'irradiance_data');
            add_block('simulink/Sources/From Workspace', [modelName '/WindSpeed'], ...
                'Position', [x0 y0+dy x0+100 y0+dy+40], 'VariableName', 'wind_speed_data');
            add_block('simulink/Sources/From Workspace', [modelName '/WeatherCondition'], ...
                'Position', [x0 y0+2*dy x0+100 y0+2*dy+40], 'VariableName', 'weather_condition_ts');
            
            % Two-Tier Demand System
            add_block('simulink/Sources/Constant', [modelName '/EmergencyDemand'], ...
                'Position', [x0 y0+3*dy x0+100 y0+3*dy+40], ...
                'Value', '130');
            
            add_block('simulink/Sources/Step', [modelName '/StandardDemand'], ...
                'Position', [x0 y0+4*dy x0+100 y0+4*dy+40], ...
                'Time','28800','Before','1170','After','1170');
            
            % Demand Sum block
            add_block('simulink/Math Operations/Sum', [modelName '/TotalDemand'], ...
                'Inputs','++', 'Position', [x0+120 y0+3.5*dy x0+160 y0+3.5*dy+20]);
            
            % Battery Subsystem
            battery_capacity_kwh = 500;
            initial_soc_percent = 50;
            initial_soc_kwh = battery_capacity_kwh * (initial_soc_percent / 100);
            
            add_block('simulink/Math Operations/Sum', [modelName '/Battery Power Sum'], ...
                'Inputs','+-', 'Position', [x0+200+100 y0+3.5*dy x0+240+100 y0+3.5*dy+20]);
            
            add_block('simulink/Continuous/Integrator', [modelName '/Battery Energy (kWh)'], ...
                'InitialCondition', num2str(initial_soc_kwh), ...
                'Position', [x0+260+100 y0+3*dy+10 x0+320+100 y0+3*dy+40]);
            
            add_block('simulink/Discontinuities/Saturation', [modelName '/SOC Saturation'], ...
                'UpperLimit', num2str(battery_capacity_kwh), 'LowerLimit', '0', ...
                'Position', [x0+340+100 y0+3*dy+10 x0+400+100 y0+3*dy+40]);
            
            add_block('simulink/Math Operations/Gain', [modelName '/SOC Gain'], ...
                'Gain', num2str(100/battery_capacity_kwh), ...
                'Position', [x0+420+100 y0+3*dy+10 x0+480+100 y0+3*dy+40]);
            
            % Controller
            ctrlPath = [modelName '/Controller'];
            add_block('simulink/User-Defined Functions/MATLAB Function', ctrlPath, ...
                'Position', [x0+200+100 y0-10 x0+200+240+100 y0+3*dy+60]);
            
            pause(0.5);
            
            rt = sfroot;
            chart = rt.find('-isa','Stateflow.EMChart','Path',ctrlPath);
            if isempty(chart)
                charts = rt.find('-isa','Stateflow.EMChart');
                for ii = 1:numel(charts)
                    if contains(charts(ii).Path, [modelName '/Controller'])
                        chart = charts(ii);
                        break;
                    end
                end
            end
            
            if isempty(chart)
                error('Could not find Controller chart.');
            end
            
            controllerCode = strjoin({
                'function [Ppv, Pwind, Pbat_power, Pdiesel, SOC_perc, tariff, Pemergency, Pstandard, Pgrid] = fcn(irradiance, wind, emergency_demand, standard_demand, soc_kwh, weatherCondition)'
                '%% SIMPLIFIED CONTROLLER FOR SIMULINK COMPATIBILITY'
                '%% This function calculates power flows and tariff based on a set of rules.'
                ''
                '%% Initialize outputs'
                'Ppv = 0; Pwind = 0; Pbat_power = 0; Pdiesel = 0;'
                'Pemergency = 0; Pstandard = 0; Pgrid = 0;'
                'tariff = 0.30;'
                'SOC_perc = 50;'
                ''
                '%% Calculate renewable generation'
                'panel_area = 300; solar_eff = 0.18;'
                'rotor_diameter = 50; rho = 1.225; cp = 0.4;'
                'rotor_area = pi * (rotor_diameter/2)^2;'
                ''
                'if weatherCondition == 0 % Poor'
                '    solar_eff = solar_eff * 0.7;'
                '    cp = cp * 0.8;'
                'elseif weatherCondition == 2 % Excellent'
                '    solar_eff = solar_eff * 1.2;'
                '    cp = cp * 1.1;'
                'end'
                ''
                'Ppv = irradiance * panel_area * solar_eff / 1000;'
                'Pwind = 0.5 * rho * rotor_area * (wind^3) * cp / 1000;'
                'P_total = Ppv + Pwind;'
                ''
                '%% Simple priority logic (avoiding helper functions for Simulink compatibility)'
                'battery_capacity = 500;'
                'charge_eff = 0.95;'
                'discharge_eff = 0.95;'
                'diesel_min_soc = 0.2;'
                ''
                '%% Supply emergency demand first'
                'if P_total >= emergency_demand'
                '    Pemergency = emergency_demand;'
                '    excess = (P_total - emergency_demand) * charge_eff;'
                '    soc_kwh = min(battery_capacity, soc_kwh + excess);'
                'else'
                '    Pemergency = P_total;'
                '    remaining_emergency = emergency_demand - P_total;'
                '    '
                '    if soc_kwh >= remaining_emergency / discharge_eff'
                '        Pemergency = Pemergency + remaining_emergency;'
                '        soc_kwh = soc_kwh - (remaining_emergency / discharge_eff);'
                '    else'
                '        available_from_battery = soc_kwh * discharge_eff;'
                '        Pemergency = Pemergency + available_from_battery;'
                '        soc_kwh = 0;'
                '        remaining_emergency = emergency_demand - Pemergency;'
                '        '
                '        if remaining_emergency > 0'
                '            Pgrid = remaining_emergency;'
                '            Pemergency = Pemergency + remaining_emergency;'
                '        end'
                '    end'
                'end'
                ''
                '%% Supply standard demand with remaining resources'
                'remaining_gen = max(0, P_total - Pemergency);'
                ''
                'if remaining_gen >= standard_demand'
                '    Pstandard = standard_demand;'
                '    excess = (remaining_gen - standard_demand) * charge_eff;'
                '    soc_kwh = min(battery_capacity, soc_kwh + excess);'
                'else'
                '    Pstandard = remaining_gen;'
                '    remaining_standard = standard_demand - remaining_gen;'
                '    '
                '    if soc_kwh >= remaining_standard / discharge_eff'
                '        Pstandard = Pstandard + remaining_standard;'
                '        soc_kwh = soc_kwh - (remaining_standard / discharge_eff);'
                '    else'
                '        available_from_battery = soc_kwh * discharge_eff;'
                '        Pstandard = Pstandard + available_from_battery;'
                '        soc_kwh = 0;'
                '        remaining_standard = standard_demand - Pstandard;'
                '        '
                '        %% Diesel activation rule'
                '        if weatherCondition == 0 && soc_kwh <= diesel_min_soc * battery_capacity'
                '            Pdiesel = remaining_standard;'
                '            Pstandard = Pstandard + remaining_standard;'
                '        elseif remaining_standard > 0'
                '            Pgrid = Pgrid + remaining_standard;'
                '            Pstandard = Pstandard + remaining_standard;'
                '        end'
                '    end'
                'end'
                ''
                '%% Calculate battery power flow (simplified for Simulink)'
                'Pbat_power = 0;'
                ''
                '%% Calculate renewable share and tariff'
                'total_supplied = Pemergency + Pstandard;'
                'if total_supplied > 0'
                '    renewable_share = (min(P_total, total_supplied) / total_supplied) * 100;'
                'else'
                '    renewable_share = 0;'
                'end'
                ''
                'if renewable_share >= 75'
                '    tariff = 0.15;'
                'elseif renewable_share >= 50'
                '    tariff = 0.225;'
                'else'
                '    tariff = 0.30;'
                'end'
                ''
                'SOC_perc = (soc_kwh / battery_capacity) * 100;'
                'end'
            }, newline);
            
            chart.Script = controllerCode;
            
            % Wiring
            add_line(modelName, 'Irradiance/1', 'Controller/1', 'autorouting', 'on');
            add_line(modelName, 'WindSpeed/1', 'Controller/2', 'autorouting', 'on');
            add_line(modelName, 'WeatherCondition/1', 'Controller/6', 'autorouting', 'on');
            add_line(modelName, 'EmergencyDemand/1', 'TotalDemand/1', 'autorouting', 'on');
            add_line(modelName, 'StandardDemand/1', 'TotalDemand/2', 'autorouting', 'on');
            add_line(modelName, 'EmergencyDemand/1', 'Controller/3', 'autorouting', 'on');
            add_line(modelName, 'StandardDemand/1', 'Controller/4', 'autorouting', 'on');
            
            outputNames = {'Ppv','Pwind','Pbat','Pdiesel','SOC','Tariff','Pemergency','Pstandard','Pgrid'};
            for k = 1:length(outputNames)
                blkName = sprintf('%s/ToW_%s', modelName, outputNames{k});
                add_block('simulink/Sinks/To Workspace', blkName, ...
                    'Position', [x0+400 y0+30+40*k x0+480 y0+30+40*k+20]);
                set_param(blkName, 'VariableName', outputNames{k}, 'SaveFormat', 'timeseries');
                add_line(modelName, sprintf('Controller/%d', k), sprintf('ToW_%s/1', outputNames{k}), 'autorouting', 'on');
            end
            
            % Connect battery loop
            add_line(modelName, 'Controller/3', 'Battery Power Sum/1', 'autorouting', 'on');
            add_line(modelName, 'Battery Power Sum/1', 'Battery Energy (kWh)/1', 'autorouting', 'on');
            add_line(modelName, 'Battery Energy (kWh)/1', 'SOC Saturation/1', 'autorouting', 'on');
            add_line(modelName, 'SOC Saturation/1', 'SOC Gain/1', 'autorouting', 'on');
            add_line(modelName, 'SOC Gain/1', 'Controller/5', 'autorouting', 'on');
            
            save_system(modelName);
            set_param(modelName,'SimulationCommand','update');
            pause(2);
            
            app.statusArea.Value = [app.statusArea.Value; {'✅ HybridEVModel built and saved successfully.'}];
            
        end
    end
end