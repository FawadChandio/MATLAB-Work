url = 'http://192.168.4.1/';

try
    response = webread(url);
    disp('Live Sensor Data from ESP32:');
    disp(response);
catch ME
    disp('Could not connect to ESP32. Make sure WiFi is connected and ESP32 is running.');
    disp(ME.message);
end
