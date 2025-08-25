function runEV()
    runHybridEVModel();
end

function runHybridEVModel()
    modelName = 'HybridEVModel';
    disp('=== FETCHING LIVE WEATHER DATA ===');
    fprintf('API Endpoint: https://api.openweathermap.org/data/2.5/forecast\n');
    fprintf('Parameters: lat=50.2667, lon=-5.0527\n');
    fprintf('Making API request...\n');
    
    try
        apiKey = '8729a157fde93d0fe0368cab277d729b'; 
        lat = 50.2667;
        lon = -5.0527;
        apiUrl = 'https://api.openweathermap.org/data/2.5/forecast';
        fullUrl = sprintf('%s?lat=%f&lon=%f&appid=%s&units=metric', ...
                  apiUrl, lat, lon, apiKey);
        
        options = weboptions('Timeout', 30);
        weatherData = webread(fullUrl, options);
        
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
        
        avg_cloud_cover = mean(cloud_cover);
        avg_wind_speed = mean(wind_speed);
        if avg_cloud_cover < 30 && avg_wind_speed > 3
            weather_condition = 2;
        elseif avg_cloud_cover < 50
            weather_condition = 1;
        else
            weather_condition = 0;
        end
        
        disp('Successfully fetched and processed live weather data.');
        
    catch ME
        disp('API fetch failed. Using default values.');
        disp(ME.message);
        n = 40;
        time_step_s = 3 * 3600;
        time_points_api = 0:time_step_s:time_step_s*(n-1);
        solar_irradiance = 500 + 300*sin(2*pi*(0:n-1)/n);
        wind_speed = 5 + 3*sin(2*pi*(0:n-1)/n);
        weather_condition = 1;
    end
    assignin('base', 'irradiance_data', timeseries(solar_irradiance, time_points_api));
    assignin('base', 'wind_speed_data', timeseries(wind_speed, time_points_api));
    assignin('base', 'weather_condition_ts', timeseries(weather_condition, 0));
    
    sim_stop_time = time_points_api(end);
    
    buildSimulinkModel(sim_stop_time);
    
    disp('=== STARTING SIMULATION ===');
    
    simOut = sim(modelName, 'ReturnWorkspaceOutputs','on');
    
    PpvStruct         = simOut.Ppv;
    PwindStruct       = simOut.Pwind;
    PbatStruct        = simOut.Pbat;
    PdieselStruct     = simOut.Pdiesel;
    SOCStruct         = simOut.SOC;
    TariffStruct      = simOut.Tariff;
    PemergencyStruct  = simOut.Pemergency;
    PstandardStruct   = simOut.Pstandard;
    PgridStruct       = simOut.Pgrid;
    
    function [t,y] = extractTimeData(S)
        if isa(S, 'timeseries') && ~isempty(S.Data)
            t = S.Time;
            y = S.Data;
        else
            t = []; y = [];
        end
    end
    
    [t, pv]        = extractTimeData(PpvStruct);
    [t, wnd]       = extractTimeData(PwindStruct);
    [t, bat]       = extractTimeData(PbatStruct);
    [t, dsl]       = extractTimeData(PdieselStruct);
    [t, soc]       = extractTimeData(SOCStruct);
    [t, tariff]    = extractTimeData(TariffStruct);
    [t, emergency] = extractTimeData(PemergencyStruct);
    [t, standard]  = extractTimeData(PstandardStruct);
    [t, Pgrid_data]  = extractTimeData(PgridStruct);
    
    t_hours = t / 3600;
    
    figure('Name','Advanced Hybrid EV Charging System - Simulation Results','NumberTitle','off', 'Position', [100, 100, 1200, 900]);
    
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
    
    subplot(4, 2, 3);
    plot(t_hours, emergency, 'b-', 'LineWidth', 2, 'DisplayName', 'Emergency'); hold on;
    plot(t_hours, standard, 'c-', 'LineWidth', 2, 'DisplayName', 'Standard');
    ylabel('Power (kW)');
    title('Emergency vs Standard Charging');
    legend('show', 'Location', 'best');
    grid on;
    xlabel('Time (hours)');
    ylim([0 1200]);
    
    subplot(4, 2, 4);
    plot(t_hours, soc, 'm-', 'LineWidth', 2, 'DisplayName', 'SOC');
    ylabel('SOC (%)');
    title('Battery State of Charge');
    grid on;
    xlabel('Time (hours)');
    ylim([0 100]);
    
    subplot(4, 2, 5);
    plot(t_hours, Pgrid_data, 'r-', 'LineWidth', 2, 'DisplayName', 'Grid'); hold on;
    plot(t_hours, dsl, 'k-', 'LineWidth', 2, 'DisplayName', 'Diesel');
    ylabel('Power (kW)');
    title('Grid & Diesel Usage');
    legend('show', 'Location', 'best');
    grid on;
    xlabel('Time (hours)');
    ylim([0 1200]);
    
    renewable_share = (renewable_gen ./ total_demand) * 100;
    renewable_share(total_demand == 0) = 0;
    subplot(4, 2, 6);
    plot(t_hours, renewable_share, 'c-', 'LineWidth', 2, 'DisplayName', 'Renewable Share');
    ylabel('Percentage (%)');
    title('Renewable Energy Share');
    grid on;
    xlabel('Time (hours)');
    ylim([0 120]);
    
    subplot(4, 2, 7);
    plot(t_hours, tariff, 'k-', 'LineWidth', 2, 'DisplayName', 'Tariff');
    ylabel('£/kWh');
    title('Dynamic Charging Tariff');
    grid on;
    xlabel('Time (hours)');
    ylim([0 0.4]);
    
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
    
    disp('=== SIMULATION RESULTS SUMMARY ===');
    fprintf('Total Renewable Generation: %.2f kWh\n', total_renewable);
    fprintf('Total Grid Energy Used: %.2f kWh\n', total_grid);
    fprintf('Total Diesel Generator Usage: %.2f kWh\n', total_diesel);
    fprintf('Total Diesel Cost: £%.2f\n', total_diesel * 0.45);
    
    if ~isempty(renewable_share)
        fprintf('Average Renewable Share: %.2f %%\n', mean(renewable_share, 'omitnan'));
    else
        fprintf('Average Renewable Share: N/A\n');
    end
    
    if ~isempty(soc)
        fprintf('Final Battery SOC: %.2f %%\n', soc(end));
    else
        fprintf('Final Battery SOC: N/A\n');
    end
    
    if ~isempty(tariff)
        fprintf('Average Dynamic Tariff: £%.3f/kWh\n', mean(tariff, 'omitnan'));
    else
        fprintf('Average Dynamic Tariff: N/A\n');
    end
    
    disp('✅ Simulation finished. Comprehensive dashboard displayed.');
end

function buildSimulinkModel(stopTime)
    modelName = 'HybridEVModel';
    
    if bdIsLoaded(modelName)
        close_system(modelName,0);
    end
    
    new_system(modelName);
    open_system(modelName);
    
    set_param(modelName, 'Solver', 'ode45', ...
        'StopTime', num2str(stopTime), ...
        'SaveOutput', 'on', ...
        'SaveState', 'on', ...
        'SaveFormat', 'Dataset');
    
    x0 = 50;  y0 = 80; 
    dy = 80;
    
    add_block('simulink/Sources/From Workspace', [modelName '/Irradiance'], ...
        'Position', [x0 y0 x0+100 y0+40], 'VariableName', 'irradiance_data');
    add_block('simulink/Sources/From Workspace', [modelName '/WindSpeed'], ...
        'Position', [x0 y0+dy x0+100 y0+dy+40], 'VariableName', 'wind_speed_data');
    add_block('simulink/Sources/From Workspace', [modelName '/WeatherCondition'], ...
        'Position', [x0 y0+2*dy x0+100 y0+2*dy+40], 'VariableName', 'weather_condition_ts');
    
    add_block('simulink/Sources/Constant', [modelName '/EmergencyDemand'], ...
        'Position', [x0 y0+3*dy x0+100 y0+3*dy+40], 'Value', '130');
    
    add_block('simulink/Sources/Step', [modelName '/StandardDemand'], ...
        'Position', [x0 y0+4*dy x0+100 y0+4*dy+40], ...
        'Time','28800','Before','1170','After','1170');
    
    add_block('simulink/Math Operations/Sum', [modelName '/TotalDemand'], ...
        'Inputs','++', 'Position', [x0+120 y0+3.5*dy x0+160 y0+3.5*dy+20]);
    
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
        'Ppv = 0; Pwind = 0; Pbat_power = 0; Pdiesel = 0;'
        'Pemergency = 0; Pstandard = 0; Pgrid = 0;'
        'tariff = 0.30;'
        'SOC_perc = 50;'
        ''
        'panel_area = 300; solar_eff = 0.18;'
        'rotor_diameter = 50; rho = 1.225; cp = 0.4;'
        'rotor_area = pi * (rotor_diameter/2)^2;'
        ''
        'if weatherCondition == 0'
        '    solar_eff = solar_eff * 0.7;'
        '    cp = cp * 0.8;'
        'elseif weatherCondition == 2'
        '    solar_eff = solar_eff * 1.2;'
        '    cp = cp * 1.1;'
        'end'
        ''
        'Ppv = irradiance * panel_area * solar_eff / 1000;'
        'Pwind = 0.5 * rho * rotor_area * (wind^3) * cp / 1000;'
        'P_total = Ppv + Pwind;'
        ''
        'battery_capacity = 500;'
        'charge_eff = 0.95;'
        'discharge_eff = 0.95;'
        'diesel_min_soc = 0.2;'
        ''
        'if P_total >= emergency_demand'
        '    Pemergency = emergency_demand;'
        '    excess = (P_total - emergency_demand) * charge_eff;'
        '    soc_kwh = min(battery_capacity, soc_kwh + excess);'
        'else'
        '    Pemergency = P_total;'
        '    remaining_emergency = emergency_demand - P_total;'
        '    '
        '    if soc_kwh >= remaining_emergency / discharge_eff'
        '        Pemergency = Pemergency + remaining_emergency;'
        '        soc_kwh = soc_kwh - (remaining_emergency / discharge_eff);'
        '    else'
        '        available_from_battery = soc_kwh * discharge_eff;'
        '        Pemergency = Pemergency + available_from_battery;'
        '        soc_kwh = 0;'
        '        remaining_emergency = emergency_demand - Pemergency;'
        '        '
        '        if remaining_emergency > 0'
        '            Pgrid = remaining_emergency;'
        '            Pemergency = Pemergency + remaining_emergency;'
        '        end'
        '    end'
        'end'
        ''
        'remaining_gen = max(0, P_total - Pemergency);'
        ''
        'if remaining_gen >= standard_demand'
        '    Pstandard = standard_demand;'
        '    excess = (remaining_gen - standard_demand) * charge_eff;'
        '    soc_kwh = min(battery_capacity, soc_kwh + excess);'
        'else'
        '    Pstandard = remaining_gen;'
        '    remaining_standard = standard_demand - remaining_gen;'
        '    '
        '    if soc_kwh >= remaining_standard / discharge_eff'
        '        Pstandard = Pstandard + remaining_standard;'
        '        soc_kwh = soc_kwh - (remaining_standard / discharge_eff);'
        '    else'
        '        available_from_battery = soc_kwh * discharge_eff;'
        '        Pstandard = Pstandard + available_from_battery;'
        '        soc_kwh = 0;'
        '        remaining_standard = standard_demand - Pstandard;'
        '        '
        '        if weatherCondition == 0 && soc_kwh <= diesel_min_soc * battery_capacity'
        '            Pdiesel = remaining_standard;'
        '            Pstandard = Pstandard + remaining_standard;'
        '        elseif remaining_standard > 0'
        '            Pgrid = Pgrid + remaining_standard;'
        '            Pstandard = Pstandard + remaining_standard;'
        '        end'
        '    end'
        'end'
        ''
        'Pbat_power = 0;'
        ''
        'total_supplied = Pemergency + Pstandard;'
        'if total_supplied > 0'
        '    renewable_share = (min(P_total, total_supplied) / total_supplied) * 100;'
        'else'
        '    renewable_share = 0;'
        'end'
        ''
        'if renewable_share >= 75'
        '    tariff = 0.15;'
        'elseif renewable_share >= 50'
        '    tariff = 0.225;'
        'else'
        '    tariff = 0.30;'
        'end'
        ''
        'SOC_perc = (soc_kwh / battery_capacity) * 100;'
        'end'
    }, newline);
    
    chart.Script = controllerCode;
    
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
    
    add_line(modelName, 'Controller/3', 'Battery Power Sum/1', 'autorouting', 'on');
    add_line(modelName, 'Battery Power Sum/1', 'Battery Energy (kWh)/1', 'autorouting', 'on');
    add_line(modelName, 'Battery Energy (kWh)/1', 'SOC Saturation/1', 'autorouting', 'on');
    add_line(modelName, 'SOC Saturation/1', 'SOC Gain/1', 'autorouting', 'on');
    add_line(modelName, 'SOC Gain/1', 'Controller/5', 'autorouting', 'on');
    
    save_system(modelName);
    set_param(modelName,'SimulationCommand','update');
    pause(2);
    
    disp('✅ HybridEVModel built and saved successfully.');
end