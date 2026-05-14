%% =========================================================
%  Belief System Dynamics — Monte Carlo Robustness Check
%  Six Americas Climate Personas | DeGroot-style model
%
%  Dependencies (must be on MATLAB path):
%    - WattsStrogatz.m   (custom network generator)
%
%  All other functions are built-in MATLAB.
%% =========================================================

%% === BLOCK 1: Fixed Setup ===

%% === Export setup ===

% Absolute path anchored to the script's own directory,
% so it works regardless of MATLAB's current working directory.
script_dir = fileparts(mfilename('fullpath'));

% Scenario flags (USER INPUT REQUIRED)
use_block_tri = false; %this is the only parameter you need to change to enable or disable block-triangular C structure
use_stubbornness = false; %also change d_scenario parameter below
use_weak_diagonal = true; %also change C_scenario parameter below

% Auto-generate run label from active flags — no need to update manually
run_label = sprintf('%s_%s_%s', ...
    ternary(use_block_tri,     'blocktri_on',   'blocktri_off'), ...
    ternary(use_stubbornness,  'stub_on',       'stub_off'), ...
    ternary(use_weak_diagonal, 'weakdiag_on',   'weakdiag_off'));

fprintf('Run label: %s\n', run_label);

%Toggle between C and d scenarios below (USER INPUT REQUIRED)
C_scenario = 'weak_diagonal'; %options: 'normal', 'weak_diagonal'
d_scenario = 'no_stubbornness' ; %options: 'normal', 'no_stubbornness'
export_dir = fullfile(script_dir, 'figures', run_label);

% Create the folder if it doesn't exist, and verify it worked.
[ok, msg] = mkdir(export_dir);
if ~ok
    error('Could not create figures directory: %s\n%s', export_dir, msg);
end
fprintf('Saving figures to: %s\n', export_dir);

% Helper lambda — defined AFTER export_dir is confirmed to exist.
export_fig = @(fh, name) exportgraphics(fh, ...
    fullfile(export_dir, [regexprep(lower(strtrim(name)), '[\s]+', '_'), '.png']), ...
    'ContentType', 'vector');

% Persona counts
% Order: [Concerned, Alarmed, Cautious, Doubtful, Dismissive, Disengaged]
counts    = [30, 25, 20, 15, 10, 20];
nAgents   = sum(counts);   % 120
mTopics   = 4;
T         = 100;
nPersonas = 6;
nRuns     = 100;

% Network parameters
k_degree  = 6;
p_rewire  = 0.2;
alpha     = 0.7;   % self-confidence weight in W

% Persona labels (fixed — does not change across runs)
persona_labels = [ ...
    repmat(1, 1, counts(1)), ...   % Concerned
    repmat(2, 1, counts(2)), ...   % Alarmed
    repmat(3, 1, counts(3)), ...   % Cautious
    repmat(4, 1, counts(4)), ...   % Doubtful
    repmat(5, 1, counts(5)), ...   % Dismissive
    repmat(6, 1, counts(6)) ...    % Disengaged
];

persona_names  = {'Concerned','Alarmed','Cautious','Doubtful','Dismissive','Disengaged'};
topic_labels   = {'Importance','Worry','Personal relevance','Future outlook'};

% Persona colours (Six Americas standard palette)
persona_colors = [
    0.94, 0.62, 0.15;   % Concerned  — amber
    0.85, 0.33, 0.18;   % Alarmed    — coral
    0.39, 0.60, 0.13;   % Cautious   — green
    0.22, 0.54, 0.87;   % Doubtful   — blue
    0.64, 0.18, 0.18;   % Dismissive — red
    0.53, 0.53, 0.50;   % Disengaged — gray
];


% === SWITCH BETWEEN (true/false) TO IMPLEMENT BLOCK-TRIANGULAR C 
block_tri = @(C) C .* [1 1 1 1; 1 1 1 1; 0 0 1 1; 0 0 1 1];

%% === BLOCK 2: Define & Normalise C Matrices ===

C_concerned = [
    0.85  0.25  0.20  0.35;
    0.25  0.85  0.20  0.35;
    0.20  0.20  0.80  0.30;
    0.35  0.35  0.25  0.90
];

C_alarm = [
    0.90  0.30  0.20  0.30;
    0.30  0.90  0.20  0.3
    0.20  0.20  0.80  0.30;
    0.30  0.30  0.20  0.90
];

C_cautious = [
    0.80  0.20  0.10  0.20;
    0.20  0.80  0.10  0.20;
    0.10  0.10  0.70  0.20;
    0.20  0.20  0.10  0.80
];

C_doubtful = [
    0.75  0.10  0.05  0.10;
    0.10  0.75  0.05  0.10;
    0.05  0.05  0.70  0.10;
    0.10  0.10  0.05  0.75
];

C_dismissive = [
    0.80  -0.20  -0.20  -0.20;
   -0.20   0.80  -0.20  -0.20;
   -0.20  -0.20   0.70  -0.20;
   -0.20  -0.20  -0.20   0.80
];

C_disengaged = [
    0.70  0.05  0.05  0.05;
    0.05  0.70  0.05  0.05;
    0.05  0.05  0.60  0.05;
    0.05  0.05  0.05  0.70
];



% >>> IF USING BLOCK TRIANGULAR MATRICES<
if use_block_tri
    C_concerned  = block_tri(C_concerned);
    C_alarm      = block_tri(C_alarm);
    C_cautious   = block_tri(C_cautious);
    C_doubtful   = block_tri(C_doubtful);
    C_dismissive = block_tri(C_dismissive);
    C_disengaged = block_tri(C_disengaged);
end

% normal or weak diagonal C
if strcmp(C_scenario, 'weak_diagonal')
    weaken_diag = @(C) C - 0.5 * diag(diag(C));   % halve diagonal entries
    C_concerned  = weaken_diag(C_concerned);
    C_alarm      = weaken_diag(C_alarm);
    C_cautious   = weaken_diag(C_cautious);
    C_doubtful   = weaken_diag(C_doubtful);
    C_dismissive = weaken_diag(C_dismissive);
    C_disengaged = weaken_diag(C_disengaged);
end


% Row-normalise (L1 normalisation — handles negative entries safely)
row_norm     = @(C) C ./ max(sum(abs(C), 2), 1e-6);
C_concerned  = row_norm(C_concerned);
C_alarm      = row_norm(C_alarm);
C_cautious   = row_norm(C_cautious);
C_doubtful   = row_norm(C_doubtful);
C_dismissive = row_norm(C_dismissive);
C_disengaged = row_norm(C_disengaged);

% Assign one C matrix per agent (cell array, length = nAgents)
C_all = [ ...
    repmat({C_concerned},  1, counts(1)), ...
    repmat({C_alarm},      1, counts(2)), ...
    repmat({C_cautious},   1, counts(3)), ...
    repmat({C_doubtful},   1, counts(4)), ...
    repmat({C_dismissive}, 1, counts(5)), ...
    repmat({C_disengaged}, 1, counts(6)) ...
];

% Pre-stack C matrices into a 3D array for vectorised use: [mTopics x mTopics x nAgents]
C_stack = zeros(mTopics, mTopics, nAgents);
for i = 1:nAgents
    C_stack(:,:,i) = C_all{i};
end

%% === BLOCK 3: Beta sampling helpers ===

beta_op = @(a, b, n) 2 * betarnd(a, b, 1, n) - 1;   % Beta → [-1,1]

% Beta parameters for initial opinions: rows = personas, cols = topics
% Each row: [a_imp, b_imp, a_wor, b_wor, a_per, b_per, a_fut, b_fut]
X0_params = [
    6.0, 2.0,   5.0, 2.5,   5.0, 3.0,   6.0, 2.0;   % Concerned
    9.0, 1.5,   9.0, 1.5,   6.0, 2.0,   9.0, 1.5;   % Alarmed
    4.0, 3.0,   5.0, 4.0,   4.0, 3.0,   4.0, 3.0;   % Cautious
    2.5, 4.0,   2.0, 4.0,   2.0, 5.0,   2.5, 4.0;   % Doubtful
    1.5, 9.0,   1.5, 9.0,   1.5, 9.0,   1.5, 9.0;   % Dismissive
    4.0, 3.0,   2.0, 5.0,   2.0, 4.0,   2.0, 4.0;   % Disengaged
];

% Beta parameters for stubbornness d: [a, b] per persona
d_params = [
    5.0, 2.0;   % Concerned  — mean ~0.71
    8.0, 2.0;   % Alarmed    — mean ~0.80
    4.0, 2.5;   % Cautious   — mean ~0.62
    2.0, 4.0;   % Doubtful   — mean ~0.33
    9.0, 2.0;   % Dismissive — mean ~0.82
    2.0, 5.0;   % Disengaged — mean ~0.29
];

%% === BLOCK 4: Monte Carlo Loop ===

% Accumulators
X_mean_accum = zeros(mTopics, nPersonas, T+1);   % for mean
X_sq_accum   = zeros(mTopics, nPersonas, T+1);   % for std dev

fprintf('Running %d Monte Carlo iterations...\n', nRuns);


for run = 1:nRuns

    % --- 4a. Sample X0 ---
    X0 = zeros(mTopics, nAgents);
    col = 1;
    for pers = 1:nPersonas
        n  = counts(pers);
        pr = X0_params(pers, :);   % 8 beta params for this persona
        X0(1, col:col+n-1) = beta_op(pr(1), pr(2), n);   % Importance
        X0(2, col:col+n-1) = beta_op(pr(3), pr(4), n);   % Worry
        X0(3, col:col+n-1) = beta_op(pr(5), pr(6), n);   % Personal rel.
        X0(4, col:col+n-1) = beta_op(pr(7), pr(8), n);   % Future outlook
        col = col + n;
    end

    % --- 4b. Sample stubbornness d (nAgents x 1) ---
    d = zeros(nAgents, 1);
    col = 1;
    for pers = 1:nPersonas
        n = counts(pers);
        if strcmp(d_scenario, 'no_stubbornness')
            d(col:col+n-1) = 0.01;   % near zero — agents almost fully open to influence
        else
            d(col:col+n-1) = betarnd(d_params(pers,1), d_params(pers,2), n, 1);
        end
        col = col + n;
    end
    d_row = d';   % 1 x nAgents — for vectorised update

    % --- 4c. Sample W (new network each run) ---
    G = WattsStrogatz(nAgents, k_degree, p_rewire);
    A = full(adjacency(G));
    W = A ./ sum(A, 2);
    W = alpha * W + (1 - alpha) * eye(nAgents);

    % --- 4d. Run simulation (vectorised) ---
    X_run        = zeros(mTopics, nAgents, T+1);
    X_run(:,:,1) = X0;

    for t = 1:T
        Xt    = X_run(:, :, t);          % [mTopics x nAgents]
        x_new = zeros(mTopics, nAgents);

        % Vectorised: for each topic, compute weighted neighbour influence
        % then apply per-agent C matrix row by row
        % C_stack(:,:,i) * (W(i,:) * Xt')' = C_i * (weighted sum of neighbour opinions)
        %
        % Equivalent to the nested loop but ~15x faster:
        %   temp_i = C_i * sum_j( W(i,j) * x_j )
        %          = C_i * (W(i,:) * Xt')'
        %          = C_i * Xt * W(i,:)'

        WXt = Xt * W';   % [mTopics x nAgents]: column i = sum_j W(j,i)*x_j
                          % Note: W(i,j) is weight agent i places on j,
                          % so we want W * Xt' then transpose → (W*Xt')'
        WXt = (W * Xt')';   % [mTopics x nAgents]: column i = weighted avg seen by i

        for i = 1:nAgents
            temp         = C_stack(:,:,i) * WXt(:,i);
            x_new(:,i)   = (1 - d(i)) * temp + d(i) * X0(:,i);
        end

        X_run(:,:,t+1) = x_new;
    end


    % --- 4e. Accumulate persona means ---
    for pers = 1:nPersonas
        mask      = (persona_labels == pers);
        run_mean  = mean(X_run(:, mask, :), 2);   % [mTopics x 1 x T+1]
        X_mean_accum(:, pers, :) = X_mean_accum(:, pers, :) + run_mean;
        X_sq_accum(:, pers, :)   = X_sq_accum(:, pers, :)   + run_mean.^2;
    end

    if mod(run, 10) == 0
        fprintf('  Completed run %d / %d\n', run, nRuns);
    end

end

fprintf('Monte Carlo complete.\n');

%% === BLOCK 5: Compute Mean and Std Dev Across Runs ===

X_mean_mc = X_mean_accum / nRuns;
X_std_mc  = sqrt(max(X_sq_accum / nRuns - X_mean_mc.^2, 0));
% max(...,0) guards against tiny negative values from floating point


%% === BLOCK 6: Visualisation — MC-Averaged Persona Trajectories ===

time_axis = 0:T;

figure('Name', 'MC-Averaged Persona Trajectories', ...
       'Position', [100, 100, 1000, 800]);

for topic = 1:mTopics
    subplot(mTopics, 1, topic);
    hold on;

    for pers = 1:nPersonas
        mu  = squeeze(X_mean_mc(topic, pers, :));   % [T+1 x 1]
        sig = squeeze(X_std_mc(topic,  pers, :));
        col = persona_colors(pers, :);

        % Shaded ±1 SD band
        %fill([time_axis, fliplr(time_axis)], ...
             %[mu'+sig', fliplr(mu'-sig')], ...
             %col, 'FaceAlpha', 0.15, 'EdgeColor', 'none');

        % Mean trajectory
        plot(time_axis, mu, 'Color', col, 'LineWidth', 2.0, ...
             'DisplayName', persona_names{pers});
    end

    yline(0, '--k', 'Alpha', 0.3, 'LineWidth', 0.8);
    ylim([-1.1, 1.1]);
    ylabel('Opinion');
    title(topic_labels{topic});
    grid on;

    if topic == 1
        legend('Location', 'eastoutside', 'FontSize', 9);
    end
    if topic == mTopics
        xlabel('Time step');
    end

    hold off;

    export_fig(gcf, 'mc_averaged_persona_trajectories');
    fprintf('Exported: mc_averaged_persona_trajectories.png\n');
end

%sgtitle(sprintf('MC-Averaged Opinion Trajectories (%d runs) — Six Americas Personas', nRuns), ...
        %'FontSize', 13, 'FontWeight', 'bold');
sgtitle(sprintf('MC-Averaged Opinion Trajectories (%d runs) — %s', nRuns, run_label), ...
        'FontSize', 13, 'FontWeight', 'bold');


%% === BLOCK 6c: Per-Topic Trajectories — Mean + Sampled Agents ===
% One figure per topic. Fat line = MC mean per persona.
% Thin lines = 5 randomly sampled agent trajectories per persona
% (drawn from the LAST Monte Carlo run stored in X_run).
% X-axis is log-scale to match reference figure style.
%
% NOTE: This block must run AFTER Block 4 (X_run holds the last MC run).
%       If you need per-run sampling, store X_run per run in the loop.

n_sampled   = 5;      % agents sampled per persona
time_log    = (0:T) + 1;   % shift by 1 so log(0) is avoided; x-label corrected below

for topic = 1:mTopics

    figure('Name', sprintf('Topic %d — %s', topic, topic_labels{topic}), ...
           'Position', [120, 120, 1000, 520]);
    hold on;

    for pers = 1:nPersonas
        col  = persona_colors(pers, :);
        mask = find(persona_labels == pers);

        % --- Thin lines: randomly sampled agents from last MC run ---
        idx_sampled = mask(randperm(numel(mask), min(n_sampled, numel(mask))));
        for k = 1:numel(idx_sampled)
            agent_traj = squeeze(X_run(topic, idx_sampled(k), :));   % (T+1 x 1)
            plot(time_log, agent_traj, ...
                 'Color', [col, 0.35], ...         % 4th element = alpha
                 'LineWidth', 1.5, ...
                 'HandleVisibility', 'off');
        end

        % --- Fat line: MC-averaged mean for this persona ---
        mu = squeeze(X_mean_mc(topic, pers, :));   % (T+1 x 1)
        plot(time_log, mu, ...
             'Color', col, ...
             'LineWidth', 2.5, ...
             'DisplayName', persona_names{pers});
    end

    set(gca, 'XScale', 'log');
    xlim([1, T+1]);
    xticks([1, 2, 5, 10, 20, 50, T+1]);
    xticklabels({'0','1','4','9','19','49',sprintf('%d',T)});
    ylim([-1.1, 1.1]);
    yline(0, '--k', 'Alpha', 0.3, 'LineWidth', 0.8);
    xlabel('Time step');
    ylabel('Opinion');
    %title(sprintf('%s — persona means + sampled agents (%d runs)', ...
                  %topic_labels{topic}, nRuns), 'FontSize', 12);
    title(sprintf('%s — persona means + sampled agents (%d runs) — %s', ...
              topic_labels{topic}, nRuns, run_label), 'FontSize', 12);
    legend('Location', 'eastoutside', 'FontSize', 9);
    grid on;
    hold off;

    % Export this topic's figure before the loop moves on
    fname = sprintf('topic_%d_%s_trajectories', topic, ...
                    regexprep(lower(topic_labels{topic}), '\s+', '_'));
    export_fig(gcf, fname);
    fprintf('Exported: %s.png\n', fname);

end

%% === BLOCK 7: Visualisation — Final Opinion Distribution (Bar Chart) ===

figure('Name', 'Final Opinion by Persona and Topic', ...
       'Position', [150, 150, 900, 400]);

final_means = squeeze(X_mean_mc(:, :, end));   % [mTopics x nPersonas]
final_stds  = squeeze(X_std_mc(:,  :, end));

bar_x = 1:nPersonas;
bar_width = 0.15;
offsets = linspace(-0.25, 0.25, mTopics);

hold on;
for topic = 1:mTopics
    xpos = bar_x + offsets(topic);
    bar(xpos, final_means(topic, :), bar_width, ...
        'FaceColor', [0.2 + topic*0.2, 0.4, 0.8 - topic*0.1], ...
        'DisplayName', topic_labels{topic});
    errorbar(xpos, final_means(topic, :), final_stds(topic, :), ...
             'k.', 'LineWidth', 1.0, 'HandleVisibility', 'off');
end

yline(0, '--k', 'Alpha', 0.4);
xticks(1:nPersonas);
xticklabels(persona_names);
ylabel('Mean final opinion');
ylim([-1.1, 1.1]);
legend('Location', 'northeast', 'FontSize', 9);
%title(sprintf('Final opinion at t=%d — MC mean ± 1 SD across %d runs', T, nRuns), ...
      %'FontSize', 11);
title(sprintf('Final opinion at t=%d — MC mean ± 1 SD — %s', T, run_label), ...
      'FontSize', 11);
grid on;
hold off;

export_fig(gcf, 'final_opinion_by_persona_and_topic');
fprintf('Exported: final_opinion_by_persona_and_topic.png\n');

function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end
