function prof = rcei_phase_profile(cycleIdx, binIdx, numBins)
%RCEI_PHASE_PROFILE Phase-folded event rate over the complete carrier cycles.
%
%   prof = rcei_phase_profile(cycleIdx, binIdx, numBins)
%
%   prof.per_cycle   event count per cycle and phase bin, divided by the
%                    mean count of that cycle (cycles x bins)
%   prof.mean        mean over cycles (1 x bins)
%   prof.sem         standard error of the mean over cycles (1 x bins)
%   prof.depth       (max - min) of prof.mean, i.e. the cycle-averaged
%                    modulation depth of the event rate

validateattributes(cycleIdx, {'numeric'}, {'vector', 'integer', 'nonnegative', 'finite'});
validateattributes(binIdx, {'numeric'}, {'vector', 'integer', 'positive', 'finite'});
validateattributes(numBins, {'numeric'}, {'scalar', 'integer', 'positive'});
cycleIdx = cycleIdx(:); binIdx = binIdx(:);
if numel(cycleIdx) ~= numel(binIdx) || any(binIdx > numBins)
    error('rcei:PhaseBins', 'Cycle indices and phase bins must have matching valid entries.');
end
ok = cycleIdx > 0;
if ~any(ok)
    error('rcei:NoCompleteCycle', 'The selected events contain no complete carrier cycle.');
end
nC = max(cycleIdx);
counts = accumarray([cycleIdx(ok), binIdx(ok)], 1, [nC numBins]);
if any(sum(counts, 2) == 0)
    error('rcei:EmptyCycle', 'A complete carrier cycle has no events.');
end
perCycle = counts ./ mean(counts, 2);
prof.per_cycle = perCycle;
prof.mean = mean(perCycle, 1);
prof.sem = std(perCycle, 0, 1)/sqrt(nC);
prof.depth = max(prof.mean) - min(prof.mean);
prof.num_cycles = nC;
end
