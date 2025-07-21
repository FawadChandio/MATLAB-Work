function [serialObj, success] = serialConnect(port)
    % Initialize output
    serialObj = [];
    success = false;
    
    try
        % Create serial connection
        serialObj = serialport(port, 9600);
        configureTerminator(serialObj, "LF");
        serialObj.Timeout = 5;
        
        % Flush any old data
        flush(serialObj);
        
        % Send handshake
        pause(2);  % Wait for Arduino to initialize
        writeline(serialObj, "TEST");
        
        % Verify connection
        response = readline(serialObj);
        if contains(response, "ARDUINO")
            success = true;
            configureCallback(serialObj, "terminator", @readLiveData);
        else
            delete(serialObj);
            serialObj = [];
            error('Invalid handshake response');
        end
    catch ME
        if ~isempty(serialObj) && isvalid(serialObj)
            delete(serialObj);
        end
        rethrow(ME);
    end
end