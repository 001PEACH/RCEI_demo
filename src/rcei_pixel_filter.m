function [keep, report] = rcei_pixel_filter(x, y, varargin)
%RCEI_PIXEL_FILTER Event mask that removes hot pixels and the least active pixels.
%
%   [keep, report] = rcei_pixel_filter(x, y)
%   [keep, report] = rcei_pixel_filter(x, y, 'HotFactor', 100, 'MinPercentile', 30)
%
%   Pixels whose event count exceeds HotFactor times the median count of the
%   active pixels are removed, because their constant pedestal masks the
%   carrier modulation. Pixels below the MinPercentile-th percentile of the
%   active-pixel counts are also removed (empty background). The settings
%   are those used for the drive comparison in main-text Fig. 3.
%
%   x, y are zero-based pixel coordinates. keep is a logical vector with one
%   entry per event.

opt = struct('HotFactor', 100, 'MinPercentile', 30, 'SensorSize', [720 1280]);
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k+1};
end
H = opt.SensorSize(1); W = opt.SensorSize(2);
idx = sub2ind([H W], double(y(:)) + 1, double(x(:)) + 1);
cnt = accumarray(idx, 1, [H * W 1]);
act = sort(cnt(cnt > 0));
med = median(act);
hotThr = max(med * opt.HotFactor, 1);
% Percentile with linear interpolation between order statistics, matching
% numpy.percentile with its default settings.
pos = 1 + (numel(act) - 1) * opt.MinPercentile / 100;
lo = floor(pos); hi = ceil(pos);
loThr = act(lo) + (pos - lo) * (act(hi) - act(lo));
keepPix = cnt <= hotThr & cnt >= loThr;
keep = keepPix(idx);
report = struct('n_hot_pixels', sum(cnt > hotThr), ...
    'fraction_in_hot_pixels', sum(cnt(cnt > hotThr)) / sum(cnt), ...
    'fraction_kept', mean(keep), 'median_count', med);
end
