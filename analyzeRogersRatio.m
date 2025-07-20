function faultType = analyzeRogersRatio(H2, CH4, C2H6, C2H2, C2H4)
    % Prevent division by zero by adding a small epsilon
    eps = 1e-5;
    ratio1 = (CH4 + eps) / (H2 + eps);          % CH4/H2
    ratio2 = (C2H6 + eps) / (CH4 + eps);        % C2H6/CH4
    ratio3 = (C2H2 + eps) / (C2H4 + eps);       % C2H2/C2H4
    ratio4 = (C2H4 + eps) / (C2H6 + eps);       % C2H4/C2H6

    % Decision logic based on Rogers Ratio Table (simplified)
    if ratio1 > 0.1 && ratio1 < 1 && ...
       ratio2 > 0.2 && ratio2 < 1 && ...
       ratio3 < 0.5 && ...
       ratio4 > 1
        faultType = 'Thermal Fault (Low Temp)';
    elseif ratio3 > 1 && ratio4 > 1
        faultType = 'Arcing / High-Energy Discharge';
    elseif ratio1 > 1 && ratio2 < 1 && ratio4 < 1
        faultType = 'Thermal Fault (High Temp)';
    elseif ratio1 > 1 && ratio3 < 0.5
        faultType = 'Partial Discharge';
    else
        faultType = 'Unclassified / Unknown Pattern';
    end
end
