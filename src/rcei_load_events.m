function ev = rcei_load_events(folder)
%RCEI_LOAD_EVENTS Read all parts of a packaged EVK4 recording.
% Coordinates are zero-based uint16; polarity is uint8 (0 OFF, 1 ON).
files = dir(fullfile(folder, '*_part*of*.mat'));
if isempty(files)
    error('rcei:MissingData', 'No recording parts found in %s.', folder);
end
part = zeros(numel(files), 1);
totalParts = zeros(numel(files), 1);
for k = 1:numel(files)
    token = regexp(files(k).name, '_part(\d+)of(\d+)\.mat$', 'tokens', 'once');
    if isempty(token)
        error('rcei:PartName', 'Unrecognized part name: %s.', files(k).name);
    end
    part(k) = str2double(token{1});
    totalParts(k) = str2double(token{2});
end
[part, order] = sort(part);
files = files(order);
if any(totalParts ~= totalParts(1)) || numel(files) ~= totalParts(1) || ...
        ~isequal(part(:), (1:totalParts(1))')
    error('rcei:MissingPart', 'Recording parts are incomplete or duplicated in %s.', folder);
end
offset = 0;
for k = 1:numel(files)
    S = load(fullfile(folder, files(k).name), 'x', 'y', 'p', 't_us', 'meta');
    if ~all(isfield(S, {'x', 'y', 'p', 't_us', 'meta'}))
        error('rcei:DataSchema', 'Missing event fields in %s.', files(k).name);
    end
    if k == 1
        meta = S.meta;
        validateattributes(meta.n_events_total, {'numeric'}, ...
            {'scalar', 'integer', 'positive', 'finite'});
        n = double(meta.n_events_total);
        x = zeros(n, 1, 'uint16');
        y = zeros(n, 1, 'uint16');
        p = zeros(n, 1, 'uint8');
        t_us = zeros(n, 1, 'uint32');
    end
    if S.meta.part ~= k || S.meta.n_parts ~= numel(files) || ...
            S.meta.n_events_total ~= n || ...
            ~strcmp(S.meta.source_raw_file, meta.source_raw_file)
        error('rcei:Metadata', 'Inconsistent metadata in %s.', files(k).name);
    end
    m = numel(S.t_us);
    if ~isa(S.x, 'uint16') || ~isa(S.y, 'uint16') || ...
            ~isa(S.p, 'uint8') || ~isa(S.t_us, 'uint32') || ...
            m == 0 || any([numel(S.x), numel(S.y), numel(S.p)] ~= m) || offset + m > n
        error('rcei:DataSchema', 'Invalid event arrays in %s.', files(k).name);
    end
    if any(S.x(:) >= 1280) || any(S.y(:) >= 720) || any(S.p(:) > 1)
        error('rcei:EventRange', 'Invalid coordinates or polarity in %s.', files(k).name);
    end
    if any(diff(double(S.t_us(:))) < 0) || ...
            (offset > 0 && S.t_us(1) < t_us(offset))
        error('rcei:TimestampOrder', 'Timestamps are out of order in %s.', files(k).name);
    end
    idx = offset + (1:m);
    x(idx) = S.x(:); y(idx) = S.y(:); p(idx) = S.p(:); t_us(idx) = S.t_us(:);
    offset = offset + m;
end
if offset ~= n || t_us(1) ~= 0
    error('rcei:EventCount', 'Incomplete recording or invalid time origin in %s.', folder);
end
ev = struct('x', x, 'y', y, 'p', p, 't_s', double(t_us)*1e-6, 'meta', meta);
end
