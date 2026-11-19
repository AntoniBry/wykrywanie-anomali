% TRENUJ_MODELE Trenowanie odszumiającego autokodera wieloczujnikowego (1 Hz)
% oraz okienkowych autokoderów lokalnych dla czujników szybkich (10 Hz / 100 Hz).
clear; clc;
rng(42);

klucze = {'PS1', 'TS1', 'FS1', 'VS1', 'EPS1', 'CE', 'CP', 'SE'};
liczba_czuj = length(klucze);

% 1. Wczytanie danych
dane = struct();
n_cykli = inf;
try
    for c = 1:liczba_czuj
        k = klucze{c};
        plik = load([k '.mat']);
        dane.(k) = plik.(['dane_' k]);
        n_cykli = min(n_cykli, size(dane.(k), 1));
    end
catch
    error('Brakuje plików .mat z danymi. Uruchom najpierw skrypt konwertujący.');
end

% 2. Podział warstwowy na zbiory: treningowy (60%), walidacyjny (20%), testowy (20%)
idx_train = [];
idx_val = [];
idx_test = [];

if isfile('profile.txt')
    prof = readmatrix('profile.txt');
    [~, ~, grupy] = unique(prof(1:n_cykli, 1:4), 'rows');
    for g = 1:max(grupy)
        idx_g = find(grupy == g);
        idx_g = idx_g(randperm(length(idx_g)));
        n_g = length(idx_g);
        if n_g >= 3
            n_tr = max(1, round(0.6 * n_g));
            n_va = max(1, round(0.2 * n_g));
            if n_tr + n_va >= n_g
                n_va = max(1, n_g - n_tr - 1);
            end
            idx_train = [idx_train; idx_g(1:n_tr)]; %#ok<AGROW>
            idx_val   = [idx_val;   idx_g(n_tr+1 : n_tr+n_va)]; %#ok<AGROW>
            idx_test  = [idx_test;  idx_g(n_tr+n_va+1 : end)]; %#ok<AGROW>
        else
            idx_train = [idx_train; idx_g]; %#ok<AGROW>
        end
    end
else
    perm = randperm(n_cykli)';
    n_tr = round(0.6 * n_cykli);
    n_va = round(0.2 * n_cykli);
    idx_train = perm(1:n_tr);
    idx_val   = perm(n_tr+1 : n_tr+n_va);
    idx_test  = perm(n_tr+n_va+1 : end);
end

idx_train = sort(idx_train);
idx_val   = sort(idx_val);
idx_test  = sort(idx_test);

fprintf('Podział cykli -> Trening: %d, Walidacja: %d, Test (nietknięty): %d\n', ... %[output:group:6b56ccd8] %[output:012e9f8c]
    length(idx_train), length(idx_val), length(idx_test)); %[output:group:6b56ccd8] %[output:012e9f8c]

% 3. Sprowadzenie wszystkich 8 czujników do wspólnej bazy 1 Hz (60 próbek/cykl)
dane_1hz = zeros(n_cykli, 60, liczba_czuj);
for c = 1:liczba_czuj
    m = dane.(klucze{c})(1:n_cykli, :);
    kol = size(m, 2);
    if kol == 60
        dane_1hz(:, :, c) = m;
    else
        r = kol / 60;
        tmp = reshape(m', r, 60, n_cykli);
        dane_1hz(:, :, c) = permute(mean(tmp, 1), [3, 2, 1]);
    end
end

% Normalizacja Z-score wyłącznie na podstawie zbioru treningowego
mu_wielo = zeros(1, liczba_czuj);
sigma_wielo = ones(1, liczba_czuj);
dane_1hz_norm = zeros(size(dane_1hz));

for c = 1:liczba_czuj
    wart_tr = dane_1hz(idx_train, :, c);
    mu_wielo(c) = mean(wart_tr(:));
    sd = std(wart_tr(:));
    if sd < 1e-6
        sd = 1;
    end
    sigma_wielo(c) = sd;
    dane_1hz_norm(:, :, c) = (dane_1hz(:, :, c) - mu_wielo(c)) / sigma_wielo(c);
end

% 4. Trenowanie wieloczujnikowego odszumiającego autokodera okienkowego (5 s x 8 czujników)
okno_s = 5;
n_cech = okno_s * liczba_czuj;

X_tr = buduj_okna_wielo(dane_1hz_norm(idx_train, :, :), okno_s);
X_va = buduj_okna_wielo(dane_1hz_norm(idx_val, :, :), okno_s);

% Dodanie szumu wejściowego (Denoising Autoencoder)
poziom_szumu = 0.10;
X_tr_szum = X_tr + poziom_szumu * randn(size(X_tr));

warstwy_wielo = [
    featureInputLayer(n_cech, 'Normalization', 'none')
    fullyConnectedLayer(24)
    reluLayer
    fullyConnectedLayer(10)
    reluLayer
    fullyConnectedLayer(24)
    reluLayer
    fullyConnectedLayer(n_cech)
    regressionLayer
];

opcje_wielo = trainingOptions('adam', ...
    'MaxEpochs', 35, ...
    'MiniBatchSize', 256, ...
    'InitialLearnRate', 1e-3, ...
    'L2Regularization', 1e-4, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', {X_va, X_va}, ...
    'ValidationPatience', 5, ...
    'Verbose', false, ...
    'Plots', 'none');

disp('Trenowanie autokodera wieloczujnikowego (1 Hz)...'); %[output:64956d49]
net_wielo = trainNetwork(X_tr_szum, X_tr, warstwy_wielo, opcje_wielo);

% 5. Wyznaczenie progów czasowych, oknowych i CUSUM wyłącznie na zbiorze walidacyjnym
Y_va_pred = predict(net_wielo, X_va);
err_va = abs(X_va(:, okno_s:okno_s:end) - Y_va_pred(:, okno_s:okno_s:end));
n_va = length(idx_val);

mu_err_t   = zeros(liczba_czuj, 60);
sd_err_t   = zeros(liczba_czuj, 60);
prog_t     = zeros(liczba_czuj, 60);
prog_okno  = zeros(1, liczba_czuj);
prog_cusum = zeros(1, liczba_czuj);
okno_dryf  = 10;
k_cusum    = 0.5;

for c = 1:liczba_czuj
    E_va = reshape(err_va(:, c), 60, n_va)'; % [n_va x 60]
    mu_err_t(c, :) = mean(E_va, 1);
    sd_err_t(c, :) = max(std(E_va, 0, 1), 1e-3);

    E_sort = sort(E_va, 1);
    idx_p99 = max(1, round(0.995 * n_va));
    p99_t = E_sort(idx_p99, :);

    prog_t(c, :) = max([p99_t * 1.15; mu_err_t(c, :) + 3.5 * sd_err_t(c, :); repmat(0.15, 1, 60)], [], 1);

    % Znormalizowane reszty dla dryfu (średnia ruchoma + CUSUM)
    Z_va = (E_va - mu_err_t(c, :)) ./ sd_err_t(c, :);
    M_va = movmean(Z_va, okno_dryf, 2);
    prog_okno(c) = max(2.0, 1.2 * percentyl_prosty(M_va(:), 99.5));

    max_S = zeros(n_va, 1);
    for i = 1:n_va
        S = 0;
        for t = 1:60
            z_clip = min(Z_va(i, t), 3.0);
            S = max(0, S + z_clip - k_cusum);
            if S > max_S(i)
                max_S(i) = S;
            end
        end
    end
    prog_cusum(c) = max(8.0, 1.25 * percentyl_prosty(max_S, 99.5));
end

ae_wielo = struct( ...
    'net', net_wielo, ...
    'klucze', {klucze}, ...
    'okno_s', okno_s, ...
    'mu', mu_wielo, ...
    'sigma', sigma_wielo, ...
    'mu_err_t', mu_err_t, ...
    'sd_err_t', sd_err_t, ...
    'prog_t', prog_t, ...
    'okno_dryf', okno_dryf, ...
    'prog_okno', prog_okno, ...
    'k_cusum', k_cusum, ...
    'prog_cusum', prog_cusum, ...
    'prog_liczba_czujnikow', 3);

% 6. Trenowanie okienkowych autokoderów lokalnych dla czujników szybkich (> 1 Hz)
ae_lokalne = struct();
for c = 1:liczba_czuj %[output:group:3082cdca]
    k = klucze{c};
    m = dane.(k)(1:n_cykli, :);
    kol = size(m, 2);
    if kol <= 60
        continue;
    end

    if kol == 6000
        w_lok = 20; % 0.2 s dla 100 Hz
    else
        w_lok = 10; % 1.0 s dla 10 Hz
    end

    m_tr = m(idx_train, :);
    mu_l = mean(m_tr(:));
    sd_l = std(m_tr(:));
    if sd_l < 1e-6
        sd_l = 1;
    end

    m_tr_norm = (m_tr - mu_l) / sd_l;
    m_va_norm = (m(idx_val, :) - mu_l) / sd_l;

    n_blok = kol / w_lok;
    X_tr_l = reshape(m_tr_norm', w_lok, n_blok * length(idx_train))';
    X_va_l = reshape(m_va_norm', w_lok, n_blok * n_va)';

    % Ograniczenie liczby okien uczących dla szybkości uczenia na CPU
    if size(X_tr_l, 1) > 60000
        los = randperm(size(X_tr_l, 1), 60000);
        X_tr_l_ucz = X_tr_l(los, :);
    else
        X_tr_l_ucz = X_tr_l;
    end
    X_tr_l_szum = X_tr_l_ucz + poziom_szumu * randn(size(X_tr_l_ucz));

    n_h1 = max(6, round(0.6 * w_lok));
    n_h2 = max(3, round(0.3 * w_lok));

    warstwy_lok = [
        featureInputLayer(w_lok, 'Normalization', 'none')
        fullyConnectedLayer(n_h1)
        reluLayer
        fullyConnectedLayer(n_h2)
        reluLayer
        fullyConnectedLayer(n_h1)
        reluLayer
        fullyConnectedLayer(w_lok)
        regressionLayer
    ];

    opcje_lok = trainingOptions('adam', ...
        'MaxEpochs', 25, ...
        'MiniBatchSize', 512, ...
        'InitialLearnRate', 1e-3, ...
        'L2Regularization', 1e-4, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', {X_va_l, X_va_l}, ...
        'ValidationPatience', 4, ...
        'Verbose', false, ...
        'Plots', 'none');

    fprintf('Trenowanie lokalnego autokodera okienkowego dla %s (okno %d próbek)...\n', k, w_lok); %[output:9f9d9bc2]
    net_lok = trainNetwork(X_tr_l_szum, X_tr_l_ucz, warstwy_lok, opcje_lok);

    % Próg zależny od punktu w cyklu wyznaczony na zbiorze walidacyjnym
    Y_va_l = predict(net_lok, X_va_l);
    err_va_l = abs(X_va_l - Y_va_l);
    E_va_l = reshape(err_va_l', kol, n_va)'; % [n_va x kol]

    mu_l_t = mean(E_va_l, 1);
    sd_l_t = max(std(E_va_l, 0, 1), 1e-3);
    E_l_sort = sort(E_va_l, 1);
    p99_l_t = E_l_sort(max(1, round(0.995 * n_va)), :);
    prog_lok_t = max([p99_l_t * 1.20; mu_l_t + 4.0 * sd_l_t; repmat(0.20, 1, kol)], [], 1);

    ae_lokalne.(k) = struct( ...
        'net', net_lok, ...
        'w_lok', w_lok, ...
        'mu', mu_l, ...
        'sigma', sd_l, ...
        'prog_t', prog_lok_t);
end %[output:group:3082cdca]

indeksy = struct('train', idx_train, 'val', idx_val, 'test', idx_test);
save('modele_ae.mat', 'ae_wielo', 'ae_lokalne', 'indeksy', '-v7.3');
disp('Zapisano zaktualizowane modele w pliku modele_ae.mat.'); %[output:99ab6463]

% --- Funkcje pomocnicze ---

function X = buduj_okna_wielo(dane_norm, okno_s)
    [N, T, C] = size(dane_norm);
    X = zeros(N * T, okno_s * C);
    for i = 1:N
        cykl = reshape(dane_norm(i, :, :), T, C);
        cykl_pad = [repmat(cykl(1, :), okno_s - 1, 1); cykl];
        baza_w = (i - 1) * T;
        for t = 1:T
            okno = cykl_pad(t : t + okno_s - 1, :);
            X(baza_w + t, :) = okno(:)';
        end
    end
end

function w = percentyl_prosty(x, p)
    xs = sort(x(:));
    idx = max(1, min(numel(xs), round((p / 100) * numel(xs))));
    w = xs(idx);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":7.1}
%---
%[output:012e9f8c]
%   data: {"dataType":"text","outputData":{"text":"Podział cykli -> Trening: 1323, Walidacja: 441, Test (nietknięty): 441\n","truncated":false}}
%---
%[output:64956d49]
%   data: {"dataType":"text","outputData":{"text":"Trenowanie autokodera wieloczujnikowego (1 Hz)...\n","truncated":false}}
%---
%[output:9f9d9bc2]
%   data: {"dataType":"text","outputData":{"text":"Trenowanie lokalnego autokodera okienkowego dla PS1 (okno 20 próbek)...\nTrenowanie lokalnego autokodera okienkowego dla FS1 (okno 10 próbek)...\nTrenowanie lokalnego autokodera okienkowego dla EPS1 (okno 20 próbek)...\n","truncated":false}}
%---
%[output:99ab6463]
%   data: {"dataType":"text","outputData":{"text":"Zapisano zaktualizowane modele w pliku modele_ae.mat.\n","truncated":false}}
%---
