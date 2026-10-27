function run_demo
% RUN_DEMO  RCEI demonstration: carrier frequency, carrier phase and reversal
%           anchors from events.
%
% Part 1 uses the two headlight recordings in .\data (frequency estimation,
% phase folding and the hand-corridor cross-check). Part 2 uses a 3-s window
% of the reciprocal-drive recording in .\data\drive_reciprocal and detects the
% reversal valleys that anchor the carrier phase.
%
% Figures, MAT results and summary.csv are written to .\results. See README.md
% for what each output shows.
%
% Requirements: MATLAB R2021b or later, no additional toolboxes.

previousPath = path;
restorePath = onCleanup(@() path(previousPath)); %#ok<NASGU>
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'), fullfile(here, 'src'));

if exist('rcei_carrier_frequency', 'file') == 0 || exist('rcei_carrier_phase', 'file') == 0
    error(['Core functions not found. The folder .\\core must contain ' ...
        'rcei_carrier_frequency.p and rcei_carrier_phase.p.']);
end

outDir = fullfile(here, 'results');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

% Settings used in the paper (Supplementary Section 7).
cfg.band_Hz = [8 14];        % search band around the nominal carrier frequency
cfg.bin_width_s = 1e-3;      % event-rate bins
cfg.num_bins = 16;           % phase bins per carrier cycle
cfg.sensor_hw = [720 1280];
cfg.hand_radii_px = [82 86]; % semi-axes of the hand ellipse
cfg.border_px = 20;

seqs = struct( ...
    'name',   {'headlight_dynamic', 'headlight_static'}, ...
    'title',  {'Headlight scene with a waving hand', 'Headlight scene without the hand'}, ...
    'folder', {fullfile(here, 'data', 'headlight_dynamic'), fullfile(here, 'data', 'headlight_static')});

summary = {};
for s = 1:numel(seqs)
    fprintf('\n== %s ==\n', seqs(s).title);
    ev = rcei_load_events(seqs(s).folder);
    fprintf('Loaded %d events over %.4f s.\n', numel(ev.t_s), max(ev.t_s));

    % 1) Carrier frequency from the event-rate spectrum.
    [fHz, fInfo] = rcei_carrier_frequency(ev.t_s, ...
        'Band', cfg.band_Hz, 'BinWidth', cfg.bin_width_s);
    fprintf('Carrier frequency: %.3f Hz (in-band peak / median = %.1f)\n', ...
        fHz, fInfo.peak_prominence);

    % 2) Fixed-frequency phase folding and the phase-folded event rate.
    [~, cycleIdx, binIdx, pInfo] = rcei_carrier_phase(ev.t_s, fHz, ...
        'NumBins', cfg.num_bins);
    prof = rcei_phase_profile(cycleIdx, binIdx, cfg.num_bins);
    fprintf('Complete carrier cycles: %d\n', pInfo.num_complete_cycles);
    fprintf('Cycle-averaged event-rate modulation (max - min): %.3f (s.e. per bin <= %.3f)\n', ...
        prof.depth, max(prof.sem));
    fprintf('Event-rate minimum at phase %.2f cycle\n', pInfo.rate_minimum_phase);

    % Accumulated events, for orientation only.
    H = cfg.sensor_hw(1); W = cfg.sensor_hw(2);
    countImg = accumarray([double(ev.y)+1, double(ev.x)+1], 1, [H W]);

    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [40 60 1500 800]);
    subplot(2, 3, 1);
    imagesc(log1p(countImg)); axis image off; colormap(gca, gray);
    title('Accumulated events (log scale)');

    subplot(2, 3, 2);
    r10 = accumarray(min(numel(fInfo.rate), floor((0:numel(fInfo.rate)-1)'/10) + 1), fInfo.rate);
    plot((0:numel(r10)-1)*0.01, r10/0.01/1e6, 'k');
    xlabel('Time (s)'); ylabel('Event rate (Mev/s)'); box off;
    title('Event rate (10-ms bins)');

    subplot(2, 3, 3);
    fsel = fInfo.spectrum_f <= 30;
    a = fInfo.spectrum_amp(fsel)/max(fInfo.spectrum_amp(fsel));
    yl = [0 1.05];
    patch([cfg.band_Hz fliplr(cfg.band_Hz)], [yl(1) yl(1) yl(2) yl(2)], ...
        [0.85 0.9 1], 'EdgeColor', 'none'); hold on;
    plot(fInfo.spectrum_f(fsel), a, 'k');
    plot([fHz fHz], yl, 'r--');
    xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); ylim(yl); box off;
    title(sprintf('Event-rate spectrum (shaded: search band), carrier %.3f Hz', fHz));

    ph = ((1:cfg.num_bins) - 0.5)/cfg.num_bins;
    subplot(2, 3, 4);
    imagesc(ph, 1:prof.num_cycles, prof.per_cycle);
    if exist('parula', 'file'), colormap(gca, parula); else, colormap(gca, jet); end
    caxis([0.5 1.5]); colorbar;
    xlabel('Carrier phase (cycle)'); ylabel('Carrier cycle');
    title('Event rate per cycle and phase bin (/ cycle mean)');

    subplot(2, 3, 5);
    errorbar(ph, prof.mean, prof.sem, 'k-o'); hold on;
    plot([0 1], [1 1], ':', 'Color', [0.5 0.5 0.5]);
    xlim([0 1]); xlabel('Carrier phase (cycle)'); ylabel('Event rate (/ cycle mean)'); box off;
    title(sprintf('Phase-folded event rate, mean and s.e. over %d cycles', prof.num_cycles));

    subplot(2, 3, 6);
    plot(((1:numel(pInfo.fine_profile)) - 0.5)/numel(pInfo.fine_profile), pInfo.fine_profile, 'k'); hold on;
    plot(pInfo.rate_minimum_phase*[1 1], ylim, 'r--');
    xlim([0 1]); xlabel('Carrier phase (cycle)'); ylabel('Event rate (/ mean)'); box off;
    title(sprintf('Fine profile (64 bins), minimum at %.2f cycle', pInfo.rate_minimum_phase));

    if exist('sgtitle', 'file'), sgtitle(seqs(s).title); end
    print(fig, fullfile(outDir, [seqs(s).name '_carrier_phase.png']), '-dpng', '-r150');
    close(fig);

    res = struct('frequency_Hz', fHz, 'frequency_info', rmfield(fInfo, 'rate'), ...
        'phase_info', pInfo, 'profile', prof, 'settings', cfg);
    save(fullfile(outDir, [seqs(s).name '_carrier_phase.mat']), '-struct', 'res');

    summary(end+1, :) = {seqs(s).name, 'n_events', numel(ev.t_s)}; %#ok<SAGROW>
    summary(end+1, :) = {seqs(s).name, 'duration_s', max(ev.t_s)}; %#ok<SAGROW>
    summary(end+1, :) = {seqs(s).name, 'carrier_frequency_Hz', fHz}; %#ok<SAGROW>
    summary(end+1, :) = {seqs(s).name, 'complete_carrier_cycles', pInfo.num_complete_cycles}; %#ok<SAGROW>
    summary(end+1, :) = {seqs(s).name, 'phase_folded_rate_modulation', prof.depth}; %#ok<SAGROW>
    summary(end+1, :) = {seqs(s).name, 'rate_minimum_phase_cycle', pInfo.rate_minimum_phase}; %#ok<SAGROW>

    % 3) Frequency cross-check on the recording with the hand.
    if strcmp(seqs(s).name, 'headlight_dynamic')
        keepImg = rcei_hand_corridor_mask(fullfile(here, 'data', 'annotations', ...
            'palm_center_manual.csv'), H, W, cfg.hand_radii_px, cfg.border_px);
        keepEv = keepImg(sub2ind([H W], double(ev.y)+1, double(ev.x)+1));
        [fEx, exInfo] = rcei_carrier_frequency(ev.t_s, 'Band', cfg.band_Hz, ...
            'BinWidth', cfg.bin_width_s, 'EventMask', keepEv);
        fprintf('Cross-check: full field %.3f Hz, hand corridor excluded %.3f Hz (relative difference %.2f%%, %.1f%% of events excluded)\n', ...
            fHz, fEx, 100*abs(fEx - fHz)/fHz, 100*(1 - mean(keepEv)));

        fig2 = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1100 420]);
        subplot(1, 2, 1);
        imagesc(log1p(countImg .* keepImg)); axis image off; colormap(gca, gray);
        title('Events kept after excluding the hand corridor');
        subplot(1, 2, 2);
        sel = fInfo.spectrum_f >= cfg.band_Hz(1) & fInfo.spectrum_f <= cfg.band_Hz(2);
        plot(fInfo.spectrum_f(sel), fInfo.spectrum_amp(sel)/max(fInfo.spectrum_amp(sel)), 'k'); hold on;
        plot(exInfo.spectrum_f(sel), exInfo.spectrum_amp(sel)/max(exInfo.spectrum_amp(sel)), 'r');
        xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); box off;
        legend({sprintf('Full field, %.3f Hz', fHz), sprintf('Hand excluded, %.3f Hz', fEx)}, ...
            'Location', 'northwest');
        title('Carrier frequency with and without the hand region');
        print(fig2, fullfile(outDir, 'headlight_dynamic_frequency_crosscheck.png'), '-dpng', '-r150');
        close(fig2);

        summary(end+1, :) = {seqs(s).name, 'carrier_frequency_hand_excluded_Hz', fEx}; %#ok<SAGROW>
    end
end

% ---------------------------------------------------------------------------
% Part 2. Reversal-valley anchors of the reciprocal carrier (main-text Fig. 3,
% Supplementary Section 2.6 and Eq. S15).
% ---------------------------------------------------------------------------
cfg.drive_nominal_Hz = 25.0;  % commanded carrier frequency of this recording
cfg.drive_band_rel = 0.15;    % search band: nominal frequency +/- 15%
cfg.anchor_bins = 40;         % phase bins of the folded event rate

fprintf('\n== Reciprocal drive, marker scene (3-s window) ==\n');
ev = rcei_load_events(fullfile(here, 'data', 'drive_reciprocal'));
[keepEv, pxRep] = rcei_pixel_filter(ev.x, ev.y);
t_s = ev.t_s(keepEv);
fprintf('Loaded %d events over %.4f s; %d hot pixels removed, %d events kept.\n', ...
    numel(ev.t_s), max(ev.t_s), pxRep.n_hot_pixels, numel(t_s));

band = cfg.drive_nominal_Hz * [1 - cfg.drive_band_rel, 1 + cfg.drive_band_rel];
[fHz, ~] = rcei_carrier_frequency(t_s, 'Band', band, 'BinWidth', cfg.bin_width_s);
[anc, aInfo] = rcei_reversal_anchors(t_s, fHz, 'NumBins', cfg.anchor_bins);
fprintf('Carrier frequency: %.3f Hz\n', fHz);
fprintf('Reversal valleys at %.3f pi and %.3f pi (prominence %.3f and %.3f)\n', ...
    anc.valley_phase_pi, anc.prominence);
fprintf('%d reversal anchors over %d complete cycles\n', numel(anc.times_s), aInfo.num_complete_cycles);

fig4 = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1300 440]);
subplot(1, 2, 1);
plot(aInfo.bin_phase_pi, aInfo.profile, '-', 'Color', [0.7 0.7 0.7]); hold on;
plot(aInfo.bin_phase_pi, aInfo.smoothed, 'k-', 'LineWidth', 1.2);
yl = ylim;
for v = 1:anc.num_valleys
    plot(anc.valley_phase_pi(v)*[1 1], yl, 'r--');
end
xlim([0 2]); xlabel('Carrier phase (\pi rad)'); ylabel('Event rate (/ mean)'); box off;
title(sprintf('Folded event rate at %.3f Hz, reversal valleys marked', fHz));
subplot(1, 2, 2);
nShow = min(numel(anc.times_s), 11);
tShow = linspace(anc.times_s(1), anc.times_s(nShow), 800);
plot((tShow - tShow(1))*1e3, pchip(anc.times_s, anc.phase_rad, tShow)/pi, 'k-', 'LineWidth', 1.2); hold on;
plot((anc.times_s(1:nShow) - tShow(1))*1e3, anc.phase_rad(1:nShow)/pi, 'ro', 'MarkerFaceColor', 'r');
xlabel('Time from first anchor (ms)'); ylabel('Carrier phase (\pi rad)'); box off;
legend({'PCHIP through anchors', 'Reversal anchors'}, 'Location', 'northwest');
title('Carrier phase through successive reversal anchors');
print(fig4, fullfile(outDir, 'drive_reciprocal_reversal_anchors.png'), '-dpng', '-r150');
close(fig4);

save(fullfile(outDir, 'drive_reciprocal_reversal_anchors.mat'), 'fHz', 'anc', 'aInfo', 'pxRep');
summary(end+1, :) = {'drive_reciprocal', 'n_events', numel(ev.t_s)};
summary(end+1, :) = {'drive_reciprocal', 'n_events_kept', numel(t_s)};
summary(end+1, :) = {'drive_reciprocal', 'carrier_frequency_Hz', fHz};
summary(end+1, :) = {'drive_reciprocal', 'reversal_valleys', anc.num_valleys};
summary(end+1, :) = {'drive_reciprocal', 'valley_1_phase_pi', anc.valley_phase_pi(1)};
summary(end+1, :) = {'drive_reciprocal', 'valley_2_phase_pi', anc.valley_phase_pi(2)};
summary(end+1, :) = {'drive_reciprocal', 'reversal_anchors', numel(anc.times_s)};

fid = fopen(fullfile(outDir, 'summary.csv'), 'w');
if fid < 0
    error('rcei:OutputFile', 'Cannot write summary.csv in %s.', outDir);
end
fprintf(fid, 'recording,quantity,value\n');
for k = 1:size(summary, 1)
    fprintf(fid, '%s,%s,%.10g\n', summary{k, :});
end
fclose(fid);
fprintf('\nDone. Figures and summary.csv are in %s\n', outDir);
checks = rcei_check_expected(summary, fullfile(here, 'expected', 'expected_values.csv'));
writetable(checks, fullfile(outDir, 'validation.csv'));
fprintf('%d/%d numerical checks passed.\n', sum(checks.passed), height(checks));

end
