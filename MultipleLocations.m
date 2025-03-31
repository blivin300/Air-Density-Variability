function uk_wind_map()
    % UK Wind Turbine Output Heatmap using NASA POWER Data

    % 16 UK cities [name, latitude, longitude]
    locations = {
        'Stornoway',   58.215, -6.388;
        'Aberdeen',    57.1497, -2.0943;
        'Inverness',   57.4778, -4.2247;
        'Glasgow',     55.8642, -4.2518;
        'Belfast',     54.5973, -5.9301;
        'Newcastle',   54.9784, -1.6174;
        'Leeds',       53.8008, -1.5491;
        'Manchester',  53.4808, -2.2426;
        'Liverpool',   53.4084, -2.9916;
        'Birmingham',  52.4862, -1.8904;
        'Norwich',     52.6309, 1.2974;
        'Cardiff',     51.4816, -3.1791;
        'Bristol',     51.4545, -2.5879;
        'Southampton', 50.9097, -1.4043;
        'Plymouth',    50.3755, -4.1427;
        'London',      51.5072, -0.1276;
    };

    % Storage for plotting
    lat = [];
    lon = [];
    avgPower = [];
    names = {};

    % Loop through each city and fetch wind power
    for i = 1:size(locations,1)
        name = locations{i,1};
        lati = locations{i,2};
        loni = locations{i,3};

        fprintf("⏳ Fetching data for %s...\n", name);
        data = fetch_weather_data(name, lati, loni);

        lat(end+1) = lati;
        lon(end+1) = loni;
        avgPower(end+1) = mean(data.WindPower, 'omitnan');
        names{end+1} = name;
    end

    % GeoBaseMap and GeoScatter
    figure('Name','UK Wind Power Density Map');
    geobasemap streets;  % Requires Mapping Toolbox
    geoscatter(lat, lon, 120, avgPower, 'filled');
    c = colorbar;
    c.Label.String = 'Average Wind Power Output (kW)';
    title('Wind Turbine Output Across UK Locations');

    % Add city labels
    for i = 1:numel(names)
        text(lon(i), lat(i), [' ', names{i}], 'FontSize', 8);
    end
end

%% Fetch Weather Data Function
function data = fetch_weather_data(name, lat, lon)
    % Fetches weather data for a location and calculates wind power
    %same as NorthSouth, start 1st Jan 2001 and end yday
    startDate = '20000101';
    endDate = datestr(datetime('yesterday'), 'yyyymmdd');
    variables = 'T2M,RH2M,PS,WS2M';
    filename = sprintf('%s_power_weather.csv', lower(name));

    % Build NASA POWER API URL
    url = sprintf(['https://power.larc.nasa.gov/api/temporal/daily/point?' ...
        'parameters=%s&community=AG&latitude=%.3f&longitude=%.3f&start=%s&end=%s&format=CSV'], ...
        variables, lat, lon, startDate, endDate);

    try
        options = weboptions('Timeout', 60);
        websave(filename, url, options);
    catch
        error('Failed to download data for %s', name);
    end

    % Load CSV data
    opts = detectImportOptions(filename);
    opts.DataLines = [10 Inf];  % Skip header
    data = readtable(filename, opts);
    data.Date = datetime(data.YEAR, 1, 1) + days(data.DOY - 1);

    % Clean missing flags
    missingFlags = [-999, -9999];
    vars = {'T2M', 'RH2M', 'PS', 'WS2M'};
    data{:, vars} = standardizeMissing(data{:, vars}, missingFlags);
    data = rmmissing(data);

    % Compute air density
    T_C = data.T2M;
    T_K = T_C + 273.15;
    RH = data.RH2M;
    P_Pa = data.PS * 1000;

    e_s = 6.112 .* exp((17.67 .* T_C) ./ (T_C + 243.5));  % hPa
    e = RH .* e_s / 100;
    e_Pa = e * 100;

    Rd = 287.05;  % J/kg·K
    data.AirDensity = (P_Pa ./ (Rd .* T_K)) .* (1 - (0.378 .* e_Pa ./ P_Pa));

    % Wind turbine parameters
    Cp = 0.35;     % Power coefficient
    r = 40;        % Rotor radius (m)
    A = pi * r^2;  % Rotor swept area
    v = data.WS2M;

    % Compute mechanical wind power (kW)
    data.WindPower = 0.5 .* data.AirDensity .* A .* v.^3 .* Cp / 1000;
end
