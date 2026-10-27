function [anchor, info] = rcei_reversal_anchors(t_s, fHz, varargin)
%RCEI_REVERSAL_ANCHORS Reversal-valley anchors and anchor-referenced carrier phase.
%
%   [anchor, info] = rcei_reversal_anchors(t_s, fHz)
%   [anchor, info] = rcei_reversal_anchors(t_s, fHz, 'Name', value, ...)
%
%   The event rate is folded at the carrier frequency fHz over the complete
%   carrier cycles. Valleys of the folded rate are detected with the fixed
%   rule of Supplementary Section 2.6, and the two valleys of the reciprocal
%   sweep are used as half-cycle anchors in every cycle. Successive anchors
%   are separated by pi, and the continuous phase is obtained by
%   shape-preserving piecewise cubic Hermite interpolation (PCHIP) through
%   the anchors (Supplementary Eq. S15). Unequal half-cycle durations are
%   therefore mapped onto equal phase intervals.
%
%   Inputs
%     t_s   event timestamps in seconds (vector, nondecreasing)
%     fHz   carrier frequency in Hz, e.g. from rcei_carrier_frequency
%
%   Options (defaults follow Supplementary Section 2.6)
%     'NumBins'        phase bins per cycle for the folded rate     (40)
%     'Prominence'     minimum valley prominence, normalized rate   (0.02)
%     'FlankCycles'    flank width for the prominence, in cycles    (1/3)
%     'MinSeparation'  valleys closer than this are merged, in pi   (0.25)
%     'PhaseOrigin'    'line': the fundamental of the folded rate peaks at
%                      phase 0, as in main-text Fig. 3; 'first': phase 0 at
%                      the first event                              ('line')
%
%   Outputs
%     anchor.valley_phase_pi   phases of the two valleys within a cycle (pi),
%                              in the coordinate set by 'PhaseOrigin'
%     anchor.prominence        their prominences (normalized rate)
%     anchor.num_valleys       number of valleys after merging; anchors are
%                              formed only when it equals two
%     anchor.separation_pi     spacing between the two valleys (pi)
%     anchor.times_s           anchor times over the complete cycles (s)
%     anchor.phase_rad         anchor phases, 0, pi, 2*pi, ... (rad)
%     anchor.event_phase       anchor-referenced phase of each event, in
%                              cycles [0, 1); NaN outside the anchored span
%     info.profile             folded event rate, normalized to mean 1
%     info.smoothed            profile after circular three-bin averaging
%     info.bin_phase_pi        bin centres (pi)
%     info.candidates          [phase_pi, prominence] of all accepted minima
%                              before merging
%     info.num_complete_cycles number of complete carrier cycles
%
%   Example
%     [fHz, ~] = rcei_carrier_frequency(t_s, 'Band', [8 14], 'BinWidth', 1e-3);
%     [anchor, info] = rcei_reversal_anchors(t_s, fHz);

opt = struct('NumBins', 40, 'Prominence', 0.02, 'FlankCycles', 1/3, ...
    'MinSeparation', 0.25, 'PhaseOrigin', 'line');
if mod(numel(varargin), 2) ~= 0
    error('rcei:Options', 'Options must be given as name-value pairs.');
end
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~ischar(name) || ~isfield(opt, name)
        error('rcei:Options', 'Unknown option.');
    end
    opt.(name) = varargin{k+1};
end
validateattributes(t_s, {'numeric'}, {'vector', 'real', 'finite'});
validateattributes(fHz, {'numeric'}, {'scalar', 'real', 'positive', 'finite'});
nb = opt.NumBins;

t_s = double(t_s(:));
t0 = t_s(1);
u = (t_s - t0) * fHz;                 % carrier cycles since the first event
nC = floor(u(end));
if nC < 2
    error('rcei:TooShort', 'At least two complete carrier cycles are required.');
end
switch lower(opt.PhaseOrigin)
    case 'line'
        % Phase of the event-rate line at fHz, so that the fundamental of the
        % folded rate peaks at phase 0.
        z = sum(exp(-1i * 2 * pi * u));
        shift = angle(z) / (2 * pi);
    case 'first'
        shift = 0;
    otherwise
        error('rcei:Options', 'PhaseOrigin must be ''line'' or ''first''.');
end
inC = u < nC;
ph = mod(u(inC) + shift, 1);
bin = min(floor(ph * nb) + 1, nb);

% Folded event rate, normalized to mean 1, and circular three-bin average.
counts = accumarray(bin, 1, [nb 1]);
prof = counts / mean(counts);
sm = (circshift(prof, 1) + prof + circshift(prof, -1)) / 3;

% Local minima and their prominence: the lower of the two flanking maxima
% within one third of a cycle, minus the minimum.
w = max(1, round(nb * opt.FlankCycles)) - 1;
cand = zeros(0, 2);
for i = 1:nb
    prev = sm(mod(i - 2, nb) + 1);
    next = sm(mod(i, nb) + 1);
    if sm(i) < prev && sm(i) < next
        left = sm(mod(i - 1 - (1:w), nb) + 1);
        right = sm(mod(i - 1 + (1:w), nb) + 1);
        prom = min(max(left), max(right)) - sm(i);
        if prom >= opt.Prominence
            cand(end + 1, :) = [(i - 0.5) / nb * 2, prom]; %#ok<AGROW>
        end
    end
end

% Merge minima closer than MinSeparation, keeping the larger prominence.
[~, order] = sort(cand(:, 2), 'descend');
cand = cand(order, :);
keep = false(size(cand, 1), 1);
for k = 1:size(cand, 1)
    sep = abs(cand(keep, 1) - cand(k, 1));
    sep = min(sep, 2 - sep);
    if all(sep >= opt.MinSeparation)
        keep(k) = true;
    end
end
valleys = sortrows(cand(keep, :), 1);
nV = size(valleys, 1);
tA = zeros(0, 1); phA = zeros(0, 1);
evPhase = nan(size(t_s));
if nV == 2
    % Two anchors per complete cycle, separated by pi in phase.
    vCyc = sort(mod(valleys(:, 1)' / 2 - shift, 1));   % cycles since the first event
    cyc = (0:nC - 1)';
    tA = (repmat(cyc, 1, 2) + repmat(vCyc, nC, 1))';
    tA = t0 + tA(:) / fHz;
    phA = (0:numel(tA) - 1)' * pi;

    % Anchor-referenced phase of each event (Supplementary Eq. S15).
    span = t_s >= tA(1) & t_s <= tA(end);
    phi = pchip(tA, phA, t_s(span));
    evPhase(span) = mod(phi / (2 * pi), 1);
end

if nV == 2
    sepPi = valleys(2, 1) - valleys(1, 1);
else
    sepPi = NaN;
end
anchor = struct('valley_phase_pi', valleys(:, 1)', ...
    'prominence', valleys(:, 2)', ...
    'num_valleys', nV, 'separation_pi', sepPi, ...
    'times_s', tA, 'phase_rad', phA, 'event_phase', evPhase);
info = struct('profile', prof, 'smoothed', sm, ...
    'bin_phase_pi', ((1:nb)' - 0.5) / nb * 2, ...
    'candidates', sortrows(cand, 1), 'num_complete_cycles', nC, ...
    'settings', opt);
end
