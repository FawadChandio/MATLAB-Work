function runHybridEVModel()
% RUNHYBRIDEVMODEL
% Builds the model if missing, runs sim, extracts To Workspace results and plots.

    modelName = 'HybridEVModel';

    % Build if needed
    if ~exist([modelName '.slx'],'file')
        buildSimulinkModel();
    else
        if ~bdIsLoaded(modelName)
            load_system(modelName);
        end
    end

    % Ensure a reasonable StopTime (seconds)
    set_param(modelName,'StopTime','100');

    % Run simulation
    simOut = sim(modelName, 'ReturnWorkspaceOutputs','on');

    % Helper to retrieve a variable from simOut or base workspace
    function val = getSimVar(name)
        % Try simOut.get first
        try
            val = simOut.get(name);
            return;
        catch
            % fallback to base workspace (older Simulink setups)
            if evalin('base', ['exist(''' name ''',''var'')'])
                val = evalin('base', name);
                return;
            else
                error('Variable "%s" not found in SimulationOutput or base workspace.', name);
            end
        end
    end

    % Retrieve structs written by To Workspace (StructureWithTime)
    PpvStruct     = getSimVar('Ppv');
    PwindStruct   = getSimVar('Pwind');
    PbatStruct    = getSimVar('Pbat');
    PdieselStruct = getSimVar('Pdiesel');

    % Convert different possible formats to (t, y)
    function [t,y] = extractTimeData(S)
        if isa(S, 'timeseries')
            t = S.Time; y = S.Data;
            return;
        end
        if isstruct(S)
            % StructureWithTime: fields 'time' and 'signals'
            if isfield(S,'time') && isfield(S,'signals')
                t = S.time;
                sig = S.signals;
                if isfield(sig,'values')
                    y = sig.values;
                elseif numel(sig) >= 1 && isfield(sig(1),'values')
                    y = sig(1).values;
                else
                    % try to use .values directly if present
                    try y = sig.values; catch y = []; end
                end
                return;
            end
            % older 'timeseries' stored as struct with .time .signals.values
            if isfield(S,'signals') && isfield(S.signals,'values') && isfield(S,'time')
                t = S.time; y = S.signals.values; return;
            end
        end
        % final fallback: treat S as numeric (single value) -> create short vector
        t = 0; y = double(S);
    end

    [t_pv,  pv ] = extractTimeData(PpvStruct);
    [t_w,   wnd] = extractTimeData(PwindStruct);
    [t_b,   bat] = extractTimeData(PbatStruct);
    [t_d,   dsl] = extractTimeData(PdieselStruct);

    % If times differ, resample or use the shortest, here we use pv time if available
    tplot = t_pv;
    if isempty(tplot), tplot = t_w; end
    if isempty(tplot), tplot = t_b; end
    if isempty(tplot), tplot = t_d; end

    % Plot combined
    figure('Name','Hybrid EV Power Contributions','NumberTitle','off');
    hold on;
    if ~isempty(pv),  plot(tplot, pv,  'LineWidth',2); end
    if ~isempty(wnd), plot(tplot, wnd, 'LineWidth',2); end
    if ~isempty(bat), plot(tplot, bat, 'LineWidth',2); end
    if ~isempty(dsl), plot(tplot, dsl, 'LineWidth',2); end
    hold off;
    grid on;
    xlabel('Time (s)');
    ylabel('Power (pu)');
    title('PV / Wind / Battery ( + charge / - discharge ) / Diesel');
    legend_entries = {};
    if ~isempty(pv),  legend_entries{end+1} = 'PV'; end
    if ~isempty(wnd), legend_entries{end+1} = 'Wind'; end
    if ~isempty(bat), legend_entries{end+1} = 'Battery'; end
    if ~isempty(dsl), legend_entries{end+1} = 'Diesel'; end
    if ~isempty(legend_entries)
        legend(legend_entries,'Location','best');
    end

    disp('✅ Simulation finished. Plot displayed.');
end
