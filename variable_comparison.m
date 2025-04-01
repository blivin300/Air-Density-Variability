function uk_wind_map()
    % UK Wind Turbine Output Map (Dynamic vs Constant Air Density)

    % List of UK cities
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

    lat = [];
    lon = [];
    avgPower = [];
    avgPowerConst = [];
    diffPercent = [];
    names = {};

    for i = 1:size(locations,1)
        name = locations{i,1};
        lati = locations{i,2};
        loni = locations{i,3};

        fprintf("Processing %s...\n", name);
        data = fetch_weather_data(name, lati, loni);

        % Store metrics
        avgDynamic = mean(data.WindPower, 'omitnan');
        avgConstant = mean(data.WindPower_Constant, 'omitnan');
        percentDiff = 100 * (avgDynamic - avgConstant) / avgConstant;

        lat(end+1) = lati;
        lon(end+1) = loni;
        avgPower(end+1) = avgDynamic;
        avgPowerConst(end+1) = avgConstant;
        diffPercent(end+1) = percentDiff;
        names{end+1} = name;
    end

    % Table summary
    results = table(names', lat', lon', avgPower', avgPowerConst', diffPercent', ...
        'VariableNames', {'City', 'Lat', 'Lon', 'Dynamic_kW', 'Constant_kW', 'Diff_Percent'});
    disp(results);

    %% Plot 1: Average Power Output Heatmap
    figure('Name','Average Wind Power Output (Dynamic)');
    geobasemap streets;
    geoscatter(lat, lon, 120, avgPower, 'filled');
    c = colorbar;
    c.Label.String = 'Avg Wind Power (kW)';
    title('Average Wind Turbine Output (Dynamic Air Density)');

    for i = 1:numel(names)
        text(lon(i), lat(i), [' ', names{i}], 'FontSize', 8);
    end

    %% Plot 2: % Difference from Constant Air Density
    figure('Name','Impact of Air Density Assumption');
    geobasemap streets;
    geoscatter(lat, lon, 120, diffPercent, 'filled');
    c = colorbar;
    c.Label.String = 'Difference (%)';
    title('Relative Difference: Dynamic vs Constant Air Density');

    for i = 1:numel(names)
        text(lon(i), lat(i), [' ', names{i}], 'FontSize', 8);
    end
end

%% Weather Data Function
function data = fetch_weather_data(name, lat, lon)
    startDate = '20000101';
    endDate = datestr(datetime('yesterday'), 'yyyymmdd');
    variables = 'T2M,RH2M,PS,WS2M';
    filename = sprintf('%s_power_weather.csv', lower(name));

    url = sprintf(['https://power.larc.nasa.gov/api/temporal/daily/point?' ...
        'parameters=%s&community=AG&latitude=%.3f&longitude=%.3f&start=%s&end=%s&format=CSV'], ...
        variables, lat, lon, startDate, endDate);

    try
        options = weboptions('Timeout', 60);
        websave(filename, url, options);
    catch
        error('Failed to download data for %s', name);
    end

    opts = detectImportOptions(filename);
    opts.DataLines = [10 Inf];
    data = readtable(filename, opts);
    data.Date = datetime(data.YEAR, 1, 1) + days(data.DOY - 1);

    missingFlags = [-999, -9999];
    vars = {'T2M', 'RH2M', 'PS', 'WS2M'};
    data{:, vars} = standardizeMissing(data{:, vars}, missingFlags);
    data = rmmissing(data);

    % Air density calc
    T_C = data.T2M;
    T_K = T_C + 273.15;
    RH = data.RH2M;
    P_Pa = data.PS * 1000;

    e_s = 6.112 .* exp((17.67 .* T_C) ./ (T_C + 243.5));
    e = RH .* e_s / 100;
    e_Pa = e * 100;

    Rd = 287.05;
    data.AirDensity = (P_Pa ./ (Rd .* T_K)) .* (1 - (0.378 .* e_Pa ./ P_Pa));

    % Turbine constants
    Cp = 0.35;
    r = 40;
    A = pi * r^2;
    v = data.WS2M;

    % Power outputs
    data.WindPower = 0.5 .* data.AirDensity .* A .* v.^3 .* Cp / 1000;
    rho_const = 1.225;
    data.WindPower_Constant = 0.5 * rho_const * A .* v.^3 * Cp / 1000;
end
