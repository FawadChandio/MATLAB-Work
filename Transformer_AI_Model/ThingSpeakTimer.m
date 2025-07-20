classdef ThingSpeakTimer < handle
    % ThingSpeakTimer - Custom timer class for polling ThingSpeak data
    
    properties
        ChannelID double
        ReadAPIKey char
        UpdateInterval double = 15 % Default 15s (ThingSpeak free limit)
        TimerObj timer
        ParentApp % Handle to main app
    end
    
    methods
        function obj = ThingSpeakTimer(parentApp, channelID, readAPIKey)
            % Constructor
            obj.ParentApp = parentApp;
            obj.ChannelID = channelID;
            obj.ReadAPIKey = readAPIKey;
        end
        
        function start(obj)
            % Start/restart the polling timer
            obj.stop(); % Ensure any existing timer is cleared
            
            obj.TimerObj = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', obj.UpdateInterval, ...
                'TimerFcn', @(~,~)obj.fetchData(), ...
                'ErrorFcn', @(~,~)obj.handleError());
            
            start(obj.TimerObj);
            obj.ParentApp.updateStatus('ThingSpeak polling started', 'green');
        end
        
        function stop(obj)
            % Stop the timer if it exists
            if ~isempty(obj.TimerObj) && isvalid(obj.TimerObj)
                stop(obj.TimerObj);
                delete(obj.TimerObj);
            end
        end
        
        function fetchData(obj)
            % Fetch data from ThingSpeak
            try
                data = thingSpeakRead(obj.ChannelID, ...
                    'Fields', 1:8, ...
                    'NumPoints', 1, ...
                    'ReadKey', obj.ReadAPIKey, ...
                    'OutputFormat', 'table');
                
                if ~isempty(data)
                    % Format data for parent app
                    newData = table(...
                        data.Field1, data.Field2, data.Field3, ...
                        data.Field4, data.Field5, data.Field6, ...
                        data.Field7, data.Field8, ...
                        NaN, NaN, ... % Temp and Load placeholders
                        'VariableNames', {'h2','ch4','c2h6','c2h4','c2h2','co','co2','h2o','temperature','load'});
                    
                    newData.Time = datetime('now');
                    
                    % Send to parent app
                    obj.ParentApp.processThingSpeakData(newData);
                end
            catch ME
                obj.handleError(ME);
            end
        end
        
        function handleError(obj, ME)
            % Error handling
            if nargin < 2
                ME = MException('ThingSpeakTimer:UnknownError', 'Unknown error');
            end
            
            obj.ParentApp.updateStatus(['ThingSpeak error: ' ME.message], 'red');
            obj.stop();
        end
        
        function delete(obj)
            % Destructor
            obj.stop();
        end
    end
end