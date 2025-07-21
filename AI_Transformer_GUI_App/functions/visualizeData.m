function visualizeData(data, axesHandles)
    % axesHandles: Struct with fields for different plots
    % Example:
    % axesHandles.moistureAxes, .gasAxes, .tempAxes, .loadAxes

    try
        % Moisture Content
        if isfield(axesHandles, 'moistureAxes') && any(strcmpi('Moisture', data.Properties.VariableNames))
            axes(axesHandles.moistureAxes);
            plot(data.Moisture, '-o');
            title('Moisture Content');
            xlabel('Sample Index');
            ylabel('ppm');
            grid on;
        end

        % Acid Number
        if isfield(axesHandles, 'acidAxes') && any(strcmpi('AcidNumber', data.Properties.VariableNames))
            axes(axesHandles.acidAxes);
            plot(data.AcidNumber, '-s', 'Color', [0.8 0.3 0.3]);
            title('Acid Number');
            xlabel('Sample Index');
            ylabel('mg KOH/g');
            grid on;
        end

        % Dissolved Gas Levels
        gasVars = {'Hydrogen', 'Methane', 'Acetylene'};
        presentGases = gasVars(ismember(gasVars, data.Properties.VariableNames));

        if isfield(axesHandles, 'gasAxes') && ~isempty(presentGases)
            axes(axesHandles.gasAxes);
            hold on;
            for i = 1:length(presentGases)
                plot(data.(presentGases{i}), 'DisplayName', presentGases{i});
            end
            title('Dissolved Gas Analysis');
            xlabel('Sample Index');
            ylabel('ppm');
            legend show;
            grid on;
            hold off;
        end

        % Time-series Temperature
        if isfield(axesHandles, 'tempAxes') && any(strcmpi('Temperature', data.Properties.VariableNames))
            axes(axesHandles.tempAxes);
            plot(data.Temperature, 'Color', [0.2 0.4 0.7]);
            title('Temperature Over Time');
            xlabel('Time Index');
            ylabel('°C');
            grid on;
        end

        % Time-series Load
        if isfield(axesHandles, 'loadAxes') && any(strcmpi('Load', data.Properties.VariableNames))
            axes(axesHandles.loadAxes);
            plot(data.Load, 'Color', [0.4 0.7 0.2]);
            title('Load Over Time');
            xlabel('Time Index');
            ylabel('MVA');
            grid on;
        end
    catch ME
        disp(['Visualization error: ', ME.message]);
    end
end
