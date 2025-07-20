function faultZone = duvalTriangle(H2, CH4, C2H2, plotAxes)
    % Normalize gas values to total = 100
    total = H2 + CH4 + C2H2;
    if total == 0
        faultZone = 'Invalid Input (All gases zero)';
        return;
    end
    percCH4  = (CH4 / total) * 100;
    percC2H2 = (C2H2 / total) * 100;
    percH2   = (H2 / total) * 100;

    % Coordinates in triangle space (simplified projection)
    x = 0.5 * (2 * percC2H2 + percCH4) / 100;
    y = sqrt(3)/2 * percCH4 / 100;

    % Duval Triangle Zones (Approximate Logic)
    if percC2H2 > 29
        faultZone = 'D1 (Low-Energy Discharge)';
    elseif percC2H2 > 13 && percCH4 > 23
        faultZone = 'D2 (High-Energy Discharge)';
    elseif percCH4 > 20
        faultZone = 'T3 (Thermal Fault >700°C)';
    elseif percCH4 > 13
        faultZone = 'T2 (300°C–700°C)';
    elseif percCH4 > 4
        faultZone = 'T1 (150°C–300°C)';
    else
        faultZone = 'PD (Partial Discharge)';
    end

    % Plotting (optional)
    if nargin == 4 && isgraphics(plotAxes)
        axes(plotAxes);
        cla;
        fill([0 1 0.5 0], [0 0 sqrt(3)/2 sqrt(3)/2], [0.9 0.9 0.9]); % Triangle Base

        hold on;
        plot(x, y, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
        text(x+0.02, y, faultZone, 'FontWeight', 'bold');
        title('Duval Triangle Approximation');
        axis equal;
        axis off;
        hold off;
    end
end
