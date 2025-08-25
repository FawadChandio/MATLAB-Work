function SolarWindEVChargingSystem1()
    clc; 
    clear;
    close all;
    
    fig = uifigure('Name', 'Modern Solar-Wind EV Charging Controller', ...
                  'Position', [100, 100, 900, 700]);
    
    fig.CloseRequestFcn = @(src, event) onCloseRequest(fig);
    
    uilabel(fig, 'Text', 'OpenWeatherMap API Parameters', ...
                         'Position', [330, 650, 250, 22], 'FontSize', 14, 'FontWeight', 'bold');
    
    uilabel(fig, 'Text', 'OpenWeatherMap API Key:', 'Position', [50, 600, 150, 22]);
    apiKeyField = uieditfield(fig, 'Position', [200, 600, 200, 22], 'Value', '8729a157fde93d0fe0368cab277d729b');
    
    uilabel(fig, 'Text', 'Latitude:', 'Position', [450, 600, 100, 22]);
    latField = uieditfield(fig, 'numeric', 'Position', [550, 600, 100, 22], 'Value', 50.2667);
    
    uilabel(fig, 'Text', 'Longitude:', 'Position', [450, 560, 100, 22]);
    lonField = uieditfield(fig, 'numeric', 'Position', [550, 560, 100, 22], 'Value', -5.0527);
    
    uilabel(fig, 'Text', 'OpenWeatherMap API URL:', 'Position', [50, 560, 150, 22]);
    % UPDATED URL for One Call API
    urlField = uieditfield(fig, 'Position', [200, 560, 200, 22], 'Value', 'https://api.openweathermap.org/data/3.0/onecall');
    
    runButton = uibutton(fig, 'push', ...
        'Text', 'Run Simulation', ...
        'Position', [720, 580, 120, 30], ...
        'ButtonPushedFcn', @(src,event) runSimulation(src,event));
    
    weatherLabel = uilabel(fig, 'Text', 'Weather Condition: Not Fetched', ...
                          'Position', [50, 520, 400, 22]);
    
    resultsTitle = uilabel(fig, 'Text', 'Advanced Hybrid System Performance', ...
                          'Position', [50, 480, 300, 22], 'FontWeight', 'bold');
    
    resultsText = uitextarea(fig, ...
        'Position', [40, 75, 820, 400], ...
        'Value', 'Simulation results will appear here...');
    
    fig.UserData.weatherLabel = weatherLabel;
    fig.UserData.resultsText = resultsText;
    fig.UserData.runButton = runButton;
    fig.UserData.apiKeyField = apiKeyField;
    fig.UserData.latField = latField;
    fig.UserData.lonField = lonField;
    fig.UserData.urlField = urlField;
    
    function runSimulation(~, ~)
        fig.UserData.weatherLabel.Text = 'Weather Condition: Fetching data...';
        fig.UserData.runButton.Enable = 'off';
        drawnow; 
        
        try
            apiKey = fig.UserData.apiKeyField.Value;
            lat = fig.UserData.latField.Value;
            lon = fig.UserData.lonField.Value;
            apiUrl = fig.UserData.urlField.Value;
            
            if isempty(apiKey) || isempty(lat) || isempty(lon) || isempty(apiUrl)
                error('Please fill in all API parameters.');
            end
            
            results = runLiveWeatherSimulation(apiKey, lat, lon, apiUrl);
            displayResults(results, fig.UserData.resultsText);
            
            fig.UserData.weatherLabel.Text = ['Weather Condition: ', results.weatherCondition];
            drawnow; 
            
        catch ME
            fig.UserData.resultsText.Value = ['Error details: ', getReport(ME)];
            fig.UserData.weatherLabel.Text = 'Weather Condition: Error';
        end
        
        fig.UserData.runButton.Enable = 'on';
    end
end
% -------------------------------------------------------------------------
function onCloseRequest(src, ~)
    selection = uiconfirm(src, 'Are you sure you want to close?', 'Confirmation', ...
        'Options', {'Yes', 'No'});
    if strcmp(selection, 'Yes')
        delete(src);
    end
end
% -------------------------------------------------------------------------
function results = runLiveWeatherSimulation(apiKey, lat, lon, apiUrl)
    fprintf('=== FETCHING LIVE WEATHER DATA ===\n');
    fprintf('API Endpoint: %s\n', apiUrl);
    fprintf('Parameters: lat=%.4f, lon=%.4f\n', lat, lon);
    
    forecastData = getWeatherForecast(apiUrl, apiKey, lat, lon);
    
    if isempty(forecastData)
        error('Failed to fetch weather data from API');
    end
    
    [dates, solar_irradiance, wind_speed, weatherCondition, weather_descriptions] = processForecastData(forecastData);
    
    fig = findobj('Type', 'uifigure', 'Name', 'Modern Solar-Wind EV Charging Controller');
    if ~isempty(fig)
        fig.UserData.weatherLabel.Text = ['Weather forecast for ', datestr(dates(1), 'dd-mmm HH:MM'), ': ', weatherCondition];
        drawnow;
    end
    
    results = runEVChargingSimulation(dates, solar_irradiance, wind_speed, weatherCondition);
    results.dataSource = 'Live Weather API';
    results.weatherCondition = weatherCondition;
    results.weather_descriptions = weather_descriptions;
    
    createResultsVisualization(results);
end
% -------------------------------------------------------------------------
function results = runEVChargingSimulation(dates, solar_irradiance, wind_speed, weatherCondition)
    fprintf('=== RUNNING SIMULATION ===\n');
    fprintf('Weather Condition: %s\n', weatherCondition);
    fprintf('Data Points: %d\n', length(solar_irradiance));
    
    panel_area = 300;         
    solar_eff = 0.18;         
    rotor_diameter = 50;      
    rotor_area = pi * (rotor_diameter/2)^2;
    rho = 1.225;              
    cp = 0.4;                 
    
    total_daily_demand = 1300; 
    emergency_fraction = 0.1;
    emergency_demand = total_daily_demand * emergency_fraction;
    standard_demand = total_daily_demand - emergency_demand;
    
    storage_capacity = 500;
    soc = 0.5 * storage_capacity; 
    charge_eff = 0.95;
    discharge_eff = 0.95;
    
    diesel_cost = 0.45;    
    diesel_min_soc = 0.2;  
    
    market_price = 0.30;
    
    if strcmpi(weatherCondition, 'Poor')
        solar_eff = solar_eff * 0.7; 
        cp = cp * 0.8; 
        fprintf('Weather adjustment: Reduced efficiency due to poor conditions\n');
    elseif strcmpi(weatherCondition, 'Excellent')
        solar_eff = solar_eff * 1.2; 
        cp = cp * 1.1; 
    end
    
    max_data_points = min(12, length(solar_irradiance));
    dates = dates(1:max_data_points);
    solar_irradiance = solar_irradiance(1:max_data_points);
    wind_speed = wind_speed(1:max_data_points);
    
    n = length(solar_irradiance);
    
    renewable_gen = zeros(n,1);
    emergency_supplied = zeros(n,1);
    standard_supplied = zeros(n,1);
    grid_energy = zeros(n,1);
    diesel_used = zeros(n,1);
    soc_trace = zeros(n,1);
    tariff = zeros(n,1);
    renewable_share = zeros(n,1);
    
    for t = 1:n
        solar_power = solar_irradiance(t) * panel_area * solar_eff;
        wind_power = 0.5 * rho * rotor_area * (wind_speed(t)^3) * cp;
        wind_power_kwh = (wind_power / 1000) * 24;
        total_gen = solar_power + wind_power_kwh;
        renewable_gen(t) = total_gen;
        
        [emergency_supplied(t), soc, grid_for_emergency] = ...
            supplyEmergencyBays(emergency_demand, total_gen, soc, storage_capacity, ...
                               charge_eff, discharge_eff);
        
        remaining_gen = max(0, total_gen - emergency_supplied(t));
        
        [standard_supplied(t), soc, grid_for_standard, diesel_for_standard] = ...
            supplyStandardBays(standard_demand, remaining_gen, soc, storage_capacity, ...
                              charge_eff, discharge_eff, diesel_min_soc, weatherCondition);
        
        grid_energy(t) = grid_for_emergency + grid_for_standard;
        diesel_used(t) = diesel_for_standard;
        soc_trace(t) = soc;
        
        total_supplied = emergency_supplied(t) + standard_supplied(t);
        if total_supplied > 0
            renewable_share(t) = (min(total_gen, total_supplied) / total_supplied) * 100;
        else
            renewable_share(t) = 0;
        end
        
        if renewable_share(t) >= 75
            tariff(t) = 0.5 * market_price;      
        elseif renewable_share(t) >= 50
            tariff(t) = 0.75 * market_price;     
        else
            tariff(t) = market_price;            
        end
    end
    
    total_renewable_energy = sum(renewable_gen);
    total_grid_energy = sum(grid_energy);
    total_diesel_energy = sum(diesel_used);
    total_energy_consumed = sum(emergency_supplied + standard_supplied);
    
    avg_renewable_share = mean(renewable_share);
    percent_from_renewables = (total_renewable_energy / total_energy_consumed) * 100;
    total_diesel_cost = total_diesel_energy * diesel_cost;
    
    results.dates = dates;
    results.renewable_gen = renewable_gen;
    results.emergency_supplied = emergency_supplied;
    results.standard_supplied = standard_supplied;
    results.soc_trace = soc_trace;
    results.grid_energy = grid_energy;
    results.diesel_used = diesel_used;
    results.renewable_share = renewable_share;
    results.tariff = tariff;
    results.summary.total_renewable = total_renewable_energy;
    results.summary.total_grid = total_grid_energy;
    results.summary.total_diesel = total_diesel_energy;
    results.summary.total_diesel_cost = total_diesel_cost;
    results.summary.avg_renewable_share = avg_renewable_share;
    results.summary.percent_from_renewables = percent_from_renewables;
    results.summary.final_soc = soc;
    results.summary.avg_tariff = mean(tariff);
    results.summary.forecast_hours = n;
end
% -------------------------------------------------------------------------
function [emergency_supplied, soc_updated, grid_energy] = ...
         supplyEmergencyBays(emergency_demand, total_gen, soc, storage_capacity, ...
                           charge_eff, discharge_eff)
    emergency_supplied = 0;
    grid_energy = 0;
    soc_updated = soc;
    
    if total_gen >= emergency_demand
        emergency_supplied = emergency_demand;
        excess = (total_gen - emergency_demand) * charge_eff;
        soc_updated = min(storage_capacity, soc + excess);
        return;
    else
        emergency_supplied = total_gen;
        remaining_demand = emergency_demand - total_gen;
        
        if soc_updated >= remaining_demand / discharge_eff
            emergency_supplied = emergency_supplied + remaining_demand;
            soc_updated = soc_updated - (remaining_demand / discharge_eff);
            return;
        else
            available_from_battery = soc_updated * discharge_eff;
            emergency_supplied = emergency_supplied + available_from_battery;
            soc_updated = 0;
            remaining_demand = emergency_demand - emergency_supplied;
            
            if remaining_demand > 0
                grid_energy = remaining_demand;
                emergency_supplied = emergency_supplied + remaining_demand;
            end
        end
    end
end
% -------------------------------------------------------------------------
function [standard_supplied, soc_updated, grid_energy, diesel_energy] = ...
         supplyStandardBays(standard_demand, available_gen, soc, storage_capacity, ...
                          charge_eff, discharge_eff, diesel_min_soc, weatherCondition)
    standard_supplied = 0;
    grid_energy = 0;
    diesel_energy = 0;
    soc_updated = soc;
    
    if available_gen >= standard_demand
        standard_supplied = standard_demand;
        excess = (available_gen - standard_demand) * charge_eff;
        soc_updated = min(storage_capacity, soc + excess);
        return;
    end
    
    standard_supplied = available_gen;
    remaining_demand = standard_demand - available_gen;
    
    if soc_updated >= remaining_demand / discharge_eff
        standard_supplied = standard_supplied + remaining_demand;
        soc_updated = soc_updated - (remaining_demand / discharge_eff);
        return;
    end
    
    if soc_updated > 0
        available_from_battery = soc_updated * discharge_eff;
        standard_supplied = standard_supplied + available_from_battery;
        soc_updated = 0;
        remaining_demand = standard_demand - standard_supplied;
    end
    
    if strcmp(weatherCondition, 'Poor') && soc_updated <= diesel_min_soc * storage_capacity
        diesel_energy = remaining_demand;
        standard_supplied = standard_supplied + diesel_energy;
        remaining_demand = 0; 
    end
    
    if remaining_demand > 0
        grid_energy = remaining_demand;
        standard_supplied = standard_supplied + remaining_demand;
    end
end
% -------------------------------------------------------------------------
function displayResults(results, textArea)
    summary = results.summary;
    resultText = sprintf('Advanced Hybrid System Performance\n\n');
    resultText = [resultText, sprintf('Data Source: %s\n', results.dataSource)];
    resultText = [resultText, sprintf('Weather Condition: %s\n', results.weatherCondition)];
    resultText = [resultText, sprintf('Simulation Period: %s to %s\n\n', ...
        datestr(results.dates(1), 'dd-mmm-yyyy HH:MM'), datestr(results.dates(end), 'dd-mmm-yyyy HH:MM'))];
    resultText = [resultText, sprintf('• Total Renewable Generation: %.2f kWh\n', summary.total_renewable)];
    resultText = [resultText, sprintf('• Total Grid Energy Used: %.2f kWh\n', summary.total_grid)];
    resultText = [resultText, sprintf('• Total Diesel Generator Usage: %.2f kWh\n', summary.total_diesel)];
    resultText = [resultText, sprintf('• Total Diesel Cost: £%.2f\n', summary.total_diesel_cost)];
    resultText = [resultText, sprintf('• Average Renewable Share: %.2f %%\n', summary.avg_renewable_share)];
    resultText = [resultText, sprintf('• Percentage of Demand Met by Renewables: %.2f %%\n', summary.percent_from_renewables)];
    resultText = [resultText, sprintf('• Final Battery State of Charge (SOC): %.2f kWh\n', summary.final_soc)];
    resultText = [resultText, sprintf('• Average Dynamic Tariff: £%.3f/kWh\n\n', summary.avg_tariff)];
    resultText = [resultText, sprintf('Simulation completed successfully.')];
    textArea.Value = resultText;
end
% -------------------------------------------------------------------------
function createResultsVisualization(results)
    fig = figure('Name', 'Advanced Hybrid System Performance', ...
                'Position', [100, 100, 1200, 900]);
    
    subplot(4, 2, [1, 2]);
    plot(results.dates, results.renewable_gen, 'g-', 'LineWidth', 2, 'DisplayName', 'Renewables'); hold on;
    demand = results.emergency_supplied + results.standard_supplied;
    plot(results.dates, demand, 'r--', 'LineWidth', 2, 'DisplayName', 'Total Demand');
    plot(results.dates, results.emergency_supplied, 'b-', 'LineWidth', 2, 'DisplayName', 'Emergency Demand');
    ylabel('kWh');
    title('Energy Generation vs Demand');
    legend('show', 'Location', 'best');
    grid on;
    datetick('x', 'dd-mmm HH:MM'); 
    
    subplot(4, 2, 3);
    sources = [sum(results.renewable_gen), sum(results.grid_energy), sum(results.diesel_used)];
    pie(sources, {'Renewables', 'Grid', 'Diesel'});
    title('Energy Source Distribution');
    
    subplot(4, 2, 4);
    plot(results.dates, results.emergency_supplied, 'b-', 'LineWidth', 2, 'DisplayName', 'Emergency'); hold on;
    plot(results.dates, results.standard_supplied, 'c-', 'LineWidth', 2, 'DisplayName', 'Standard');
    ylabel('kWh');
    title('Emergency vs Standard Charging');
    legend('show', 'Location', 'best');
    grid on;
    datetick('x', 'dd-mmm HH:MM');
    
    subplot(4, 2, 5);
    plot(results.dates, results.soc_trace, 'm-', 'LineWidth', 2, 'DisplayName', 'SOC');
    ylabel('kWh');
    title('Battery State of Charge');
    grid on;
    datetick('x', 'dd-mmm HH:MM');
    
    subplot(4, 2, 6);
    plot(results.dates, results.grid_energy, 'r-', 'LineWidth', 2, 'DisplayName', 'Grid'); hold on;
    plot(results.dates, results.diesel_used, 'k-', 'LineWidth', 2, 'DisplayName', 'Diesel');
    ylabel('kWh');
    title('Grid & Diesel Usage');
    legend('show', 'Location', 'best');
    grid on;
    datetick('x', 'dd-mmm HH:MM');
    
    subplot(4, 2, 7);
    plot(results.dates, results.renewable_share, 'c-', 'LineWidth', 2, 'DisplayName', 'Renewable Share');
    ylabel('%');
    title('Renewable Energy Share');
    grid on;
    datetick('x', 'dd-mmm HH:MM');
    
    subplot(4, 2, 8);
    plot(results.dates, results.tariff, 'k-', 'LineWidth', 2, 'DisplayName', 'Tariff');
    ylabel('£/kWh');
    title('Dynamic Charging Tariff');
    grid on;
    datetick('x', 'dd-mmm HH:MM');
end
% -------------------------------------------------------------------------
function forecastData = getWeatherForecast(url, apiKey, lat, lon)
   
    fullUrl = sprintf('%s?lat=%f&lon=%f&appid=%s&units=metric&exclude=current,minutely,daily,alerts', ...
              url, lat, lon, apiKey);
    
    fprintf('Making API request to: %s\n', fullUrl);
    
    try
        options = weboptions('Timeout', 30, 'ContentType', 'json');
        forecastData = webread(fullUrl, options);
        
        if isempty(forecastData)
            error('API call returned no data. Check API key and connection.');
        end
        
        fprintf('Successfully retrieved data from OpenWeatherMap API\n');
        fprintf('API Response: %d data points received\n', length(forecastData.hourly));
    catch ME
        fprintf('Failed to fetch weather data: %s\n', ME.message);
        forecastData = [];
    end
end
% -------------------------------------------------------------------------
function [dates, solar_irradiance, wind_speed, weatherCondition, weather_descriptions] = processForecastData(forecastData)
    fprintf('Processing forecast data...\n');
    
    if isfield(forecastData, 'hourly')
        records = forecastData.hourly;
    else
        error('forecastData does not contain field "hourly".');
    end

    n = min(12, numel(records));
    records = records(1:n);
    
timestamps = [records.dt]';
cloud_cover = [records.clouds]';
wind_speed = [records.wind_speed]';
weather_descriptions = cell(n, 1);
for i = 1:n
    if ~isempty(records(i).weather)
        weather_descriptions{i} = records(i).weather(1).description;
    else
        weather_descriptions{i} = 'No description';
    end
end
    try
        dates = datetime(timestamps, 'ConvertFrom', 'posixtime');
    catch
        warning('Failed to convert timestamps, using sequential hours instead.');
        dates = datetime('now') + hours(0:n-1);
    end
    
    solar_irradiance = (1 - cloud_cover/100) * 1000;
    
    avg_cloud_cover = mean(cloud_cover);
    avg_wind_speed = mean(wind_speed);
    
    if avg_cloud_cover < 30 && avg_wind_speed > 3
        weatherCondition = 'Excellent';
    elseif avg_cloud_cover < 50
        weatherCondition = 'Good';
    else
        weatherCondition = 'Poor';
    end
    
    fprintf('Weather analysis: %.1f%% cloud cover, %.1f m/s wind speed -> %s conditions\n', ...
            avg_cloud_cover, avg_wind_speed, weatherCondition);
    
    fprintf('Weather descriptions:\n');
    for i = 1:min(5, length(weather_descriptions))
        fprintf('  %s: %s\n', datestr(dates(i), 'dd-mmm HH:MM'), weather_descriptions{i});
    end
end