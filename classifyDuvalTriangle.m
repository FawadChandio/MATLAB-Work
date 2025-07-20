function faultTypes = classifyDuvalTriangle(percentages)
    % Classify faults based on Duval triangle zones
    % Input: percentages matrix with columns [CH4, C2H2, C2H4]
    
    faultTypes = cell(size(percentages,1),1);
    
    for i = 1:size(percentages,1)
        ch4 = percentages(i,1);
        c2h2 = percentages(i,2);
        c2h4 = percentages(i,3);
        
        % Check which zone the point falls into
        if c2h2 < 20 && ch4 > 98-c2h4
            faultTypes{i} = 'PD (Partial Discharge)';
        elseif c2h2 > 20 && c2h2 < 50 && c2h4 > 50
            faultTypes{i} = 'D1 (Discharge of Low Energy)';
        elseif c2h2 > 50 && c2h4 > 30
            faultTypes{i} = 'D2 (Discharge of High Energy)';
        elseif c2h4 > 50 && ch4 > 30
            faultTypes{i} = 'T3 (Thermal Fault > 700°C)';
        else
            faultTypes{i} = 'No Fault (Healthy)';
        end
    end
end