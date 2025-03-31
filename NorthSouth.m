%% This snippet reviews two locations to represent the extreme north and south of the UK


% Location parameters
sites = {
    'Stornoway',     58.215, -6.388;
    'Southampton',   50.910, -1.404
};

% create a figure and loop through the number of sites
figure('Name','Wind Power Comparison');
hold on;

for i = 1:size(sites,1)
    name = sites{i,1};
    lat  = sites{i,2};
    lon  = sites{i,3};

    % print the name of the location extracting currently
    fprintf('\n🔍 Processing %s (%.3f, %.3f)...\n', name, lat, lon);

    data = fetch_weather_data(name, lat, lon);

    %% Plot smoothed variables (temperature, humidity, pressure)
    %% Commented out to reduce load time 
   % data.T2M_Smooth = movmean(data.T2M, 30);
   % data.RH2M_Smooth = movmean(data.RH2M, 30);
   % data.PS_Smooth = movmean(data.PS, 30);

   % figure('Name', sprintf('Smoothed Variables - %s', name));
   % subplot(3,1,1);
   % plot(data.Date, data.T2M, ':', data.Date, data.T2M_Smooth, '-');
   % ylabel('Temp (°C)'); title([name ' - Temperature']); legend('Raw','Smoothed');

   % subplot(3,1,2);
   % plot(data.Date, data.RH2M, ':', data.Date, data.RH2M_Smooth, '-');
   % ylabel('Humidity (%)'); title([name ' - Humidity']);

   % subplot(3,1,3);
   % plot(data.Date, data.PS, ':', data.Date, data.PS_Smooth, '-');
   % ylabel('Pressure (kPa)'); xlabel('Date'); title([name ' - Pressure']); legend('Raw','Smoothed');

    %% Plot air density
    %figure('Name', sprintf('Air Density - %s', name));
    %plot(data.Date, data.AirDensity);
    %ylabel('Air Density (kg/m³)');
    %title([name ' - Air Density Over Time']);
    %grid on;

    % Smooth air density (30-day moving average)
data.AirDensity_Smooth = movmean(data.AirDensity, 30);
figure;
plot(data.Date, data.AirDensity, ':', ...
     data.Date, data.AirDensity_Smooth, '-');
ylabel('Air Density (kg/m³)');
xlabel('Date');
legend('Raw', '30-Day Smoothed');
title(sprintf('Air Density Over Time – %s', name));
grid on;



    %% Plot wind power for this site (for individual check)
  %  figure('Name', sprintf('Wind Power - %s', name));
  %  plot(data.Date, data.WindPower);
  %  ylabel('Mechanical Power (kW)');
  %  title([name ' - Wind Turbine Output']);
  %  grid on;

    %% Add to comparison plot
    figure(1);
    plot(data.Date, data.WindPower, 'DisplayName', name);
end

%% Finalize comparison figure
hold off;
ylabel('Mechanical Power (kW)');
xlabel('Date');
title('Wind Turbine Power Output: Stornoway vs Southampton');
legend('show');
grid on;


%% FETCH_WEATHER_DATA FUNCTION
function data = fetch_weather_data(name, lat, lon)
    %% Fetch weather data from NASA POWER API
    % select data from 1st Jan 2000 and stop yesterday
    startDate = '20000101';   
    endDate = datestr(datetime('yesterday'), 'yyyymmdd');
    variables = 'T2M,RH2M,PS,WS2M';
    filename = sprintf('%s_power_weather.csv', lower(name));

    url = sprintf(['https://power.larc.nasa.gov/api/temporal/daily/point?' ...
        'parameters=%s&community=AG&latitude=%.3f&longitude=%.3f&start=%s&end=%s&format=CSV'], ...
        variables, lat, lon, startDate, endDate);

    options = weboptions('Timeout', 60);
    websave(filename, url, options);

    %% Load and clean
    opts = detectImportOptions(filename);
    opts.DataLines = [10 Inf];
    data = readtable(filename, opts);
    data.Date = datetime(data.YEAR, 1, 1) + days(data.DOY - 1);

    % Replace missing value flags
    missingFlags = [-999, -9999];
    vars = {'T2M', 'RH2M', 'PS', 'WS2M'};
    data{:, vars} = standardizeMissing(data{:, vars}, missingFlags);
    data = rmmissing(data);

    %% Compute Air Density
    T_C = data.T2M;
    T_K = T_C + 273.15;
    RH = data.RH2M;
    P_Pa = data.PS * 1000;

    e_s = 6.112 .* exp((17.67 .* T_C) ./ (T_C + 243.5));  % hPa
    e = RH .* e_s / 100;
    e_Pa = e * 100;

    Rd = 287.05;
    data.AirDensity = (P_Pa ./ (Rd .* T_K)) .* (1 - (0.378 .* e_Pa ./ P_Pa));

    %% Compute Wind Power Output
    Cp = 0.35;         % Power coefficient
    r = 40;            % Rotor radius (m)
    A = pi * r^2;      % Swept area
    v = data.WS2M;     % Wind speed (m/s)

    data.WindPower = 0.5 .* data.AirDensity .* A .* v.^3 .* Cp / 1000;  % kW
end

if strcmp(name, 'Stornoway')
    figure('Name', 'Stornoway: Smoothed Temp/Humidity/Pressure');

    subplot(3,1,1);
    plot(data.Date, data.T2M, ':', data.Date, data.T2M_Smooth, '-');
    ylabel('Temp (°C)');
    title('Stornoway - Temperature');
    legend('Raw', 'Smoothed');

    subplot(3,1,2);
    plot(data.Date, data.RH2M, ':', data.Date, data.RH2M_Smooth, '-');
    ylabel('Humidity (%)');
    title('Stornoway - Humidity');

    subplot(3,1,3);
    plot(data.Date, data.PS, ':', data.Date, data.PS_Smooth, '-');
    ylabel('Pressure (kPa)');
    xlabel('Date');
    title('Stornoway - Pressure');
    legend('Raw', 'Smoothed');
end

