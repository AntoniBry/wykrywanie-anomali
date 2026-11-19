function interface_old()

try
    dane.PS1 = load('PS1.mat').dane_PS1;
    dane.TS1 = load('TS1.mat').dane_TS1;
    dane.FS1 = load('FS1.mat').dane_FS1;
    dane.VS1 = load('VS1.mat').dane_VS1;
    dane.EPS1 = load('EPS1.mat').dane_EPS1;
    dane.CE = load('CE.mat').dane_CE;
    dane.CP = load('CP.mat').dane_CP;
    dane.SE = load('SE.mat').dane_SE;
catch
    disp('Brakuje plików z danymi. Uruchom najpierw skrypt konwertujący.');
    return;
end

% Kalibracja statystyk bazowych raz przy starcie (bez użycia danych testowych)
idx_kal = [];
if isfile('profile.txt')
    try
        prof = readmatrix('profile.txt');
        if size(prof, 2) >= 5
            idx_kal = find(prof(:, 1) == 100 & prof(:, 2) == 100 & ...
                           prof(:, 3) == 0 & prof(:, 4) == 130 & prof(:, 5) == 0);
            if length(idx_kal) < 20
                idx_kal = find(prof(:, 5) == 0);
            end
        end
    catch
        idx_kal = [];
    end
end

pola_danych = fieldnames(dane);
stat_kal = struct();
for i = 1:length(pola_danych)
    k = pola_danych{i};
    m = dane.(k);
    n_wierszy = size(m, 1);
    col = size(m, 2);
    dt = 60 / col;

    idx_k = idx_kal(idx_kal <= n_wierszy);
    if isempty(idx_k)
        idx_k = 1:min(200, max(1, floor(0.2 * n_wierszy)));
    elseif length(idx_k) > 200
        idx_k = idx_k(1:200);
    end
    m_kal = m(idx_k, :);

    s_sort = sort(m_kal(:));
    i5 = max(1, round(0.05 * numel(s_sort)));
    i95 = max(1, round(0.95 * numel(s_sort)));
    stat_kal.(k).rozpietosc = s_sort(i95) - s_sort(i5);
    stat_kal.(k).mediana = median(m_kal(:));

    if col > 60
        okno_k = max(3, round(5 / dt));
        n_pod = min(30, size(m_kal, 1));
        s_pod = m_kal(1:n_pod, :)';
        s_pod = s_pod(:);
        odch_k = abs(s_pod - movmedian(s_pod, okno_k));
        stat_kal.(k).mad = 1.4826 * median(odch_k);
        stat_kal.(k).wzorzec = [];
    else
        wzorzec_k = median(m_kal, 1);
        odch_k = abs(m_kal - wzorzec_k);
        stat_kal.(k).wzorzec = wzorzec_k;
        stat_kal.(k).mad = 1.4826 * median(odch_k(:));
    end
end

czy_jest_ae = false;
modele = struct();
progi = struct();

try
    plik_ae = load('modele_ae.mat');
    modele = plik_ae.modele;
    progi = plik_ae.progi;
    czy_jest_ae = true;
catch
    disp('Nie znaleziono pliku modele_ae.mat. Tryb autokodera będzie nieaktywny.');
end

okno = uifigure('Name', 'Analiza Czujników', 'Position', [100, 100, 1080, 760]);

siatka = uigridlayout(okno, [1, 2]);
siatka.ColumnWidth = {265, '1x'};

panel_lewy = uigridlayout(siatka, [20, 1]);
panel_lewy.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 68, 'fit', 'fit', 'fit', 'fit', 45, 'fit', 90, 30, '1x'};
panel_lewy.RowSpacing = 5;
panel_lewy.Scrollable = 'on';

uilabel(panel_lewy, 'Text', 'Wybierz wielkości do analizy:');

cb_ps1 = uicheckbox(panel_lewy, 'Text', 'Ciśnienie', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_ts1 = uicheckbox(panel_lewy, 'Text', 'Temperatura', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_fs1 = uicheckbox(panel_lewy, 'Text', 'Przepływ', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_vs1 = uicheckbox(panel_lewy, 'Text', 'Drgania', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_eps1 = uicheckbox(panel_lewy, 'Text', 'Moc silnika', 'ValueChangedFcn', @(src, event) odswiez());
cb_ce = uicheckbox(panel_lewy, 'Text', 'Wydajność chłodzenia', 'ValueChangedFcn', @(src, event) odswiez());
cb_cp = uicheckbox(panel_lewy, 'Text', 'Moc chłodzenia', 'ValueChangedFcn', @(src, event) odswiez());
cb_se = uicheckbox(panel_lewy, 'Text', 'Współczynnik sprawności', 'ValueChangedFcn', @(src, event) odswiez());

uilabel(panel_lewy, 'Text', 'Metoda wykrywania anomalii:');

grupa_metod = uibuttongroup(panel_lewy, 'SelectionChangedFcn', @(src, event) odswiez());
grupa_metod.BorderType = 'none';

rb_mediana = uiradiobutton(grupa_metod, 'Position', [0, 45, 240, 22], 'Text', 'Filtr medianowy (statystyka)', 'Tag', 'mediana');
uiradiobutton(grupa_metod, 'Position', [0, 23, 240, 22], 'Text', 'Autokoder (sieć neuronowa)', 'Tag', 'ae');
uiradiobutton(grupa_metod, 'Position', [0, 1, 240, 22], 'Text', 'Porównaj obie metody naraz', 'Tag', 'obie');

grupa_metod.SelectedObject = rb_mediana;

uilabel(panel_lewy, 'Text', 'Opcje wyświetlania:');

cb_trend = uicheckbox(panel_lewy, 'Text', 'Pokaż linię trendu', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_anomalie = uicheckbox(panel_lewy, 'Text', 'Oznacz anomalie', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());

lbl_prog = uilabel(panel_lewy, 'Text', 'Próg odchylenia: 2.0% (AE: 1.0x)');
suwak_prog = uislider(panel_lewy, 'Limits', [0.5 15], 'Value', 2, 'MajorTicks', [1 3 6 9 12 15], 'ValueChangedFcn', @(src, event) zmieniono_prog());

uilabel(panel_lewy, 'Text', 'Liczba cykli na wykresie:');

grupa_cykli = uibuttongroup(panel_lewy, 'SelectionChangedFcn', @(src, event) odswiez());
grupa_cykli.BorderType = 'none';

przycisk_1 = uiradiobutton(grupa_cykli, 'Position', [0, 65, 50, 22], 'Text', '1', 'Tag', '1');
uiradiobutton(grupa_cykli, 'Position', [60, 65, 50, 22], 'Text', '2', 'Tag', '2');
uiradiobutton(grupa_cykli, 'Position', [120, 65, 50, 22], 'Text', '3', 'Tag', '3');
uiradiobutton(grupa_cykli, 'Position', [180, 65, 50, 22], 'Text', '4', 'Tag', '4');

uiradiobutton(grupa_cykli, 'Position', [0, 35, 50, 22], 'Text', '5', 'Tag', '5');
uiradiobutton(grupa_cykli, 'Position', [60, 35, 50, 22], 'Text', '10', 'Tag', '10');
uiradiobutton(grupa_cykli, 'Position', [120, 35, 50, 22], 'Text', '20', 'Tag', '20');
uiradiobutton(grupa_cykli, 'Position', [180, 35, 50, 22], 'Text', '50', 'Tag', '50');

przycisk_wlasny = uiradiobutton(grupa_cykli, 'Position', [0, 5, 150, 22], 'Text', 'Własny przedział', 'Tag', 'wlasny');

grupa_cykli.SelectedObject = przycisk_1;

panel_zakres = uigridlayout(panel_lewy, [1, 4]);
panel_zakres.ColumnWidth = {'fit', '1x', 'fit', '1x'};
panel_zakres.Padding = [0 0 0 0];

uilabel(panel_zakres, 'Text', 'Od:');
pole_od = uieditfield(panel_zakres, 'numeric', 'Value', 1, 'Limits', [1 2205], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) zmieniono_zakres());

uilabel(panel_zakres, 'Text', 'Do:');
pole_do = uieditfield(panel_zakres, 'numeric', 'Value', 10, 'Limits', [1 2205], 'RoundFractionalValues', 'on', 'ValueChangedFcn', @(src, event) zmieniono_zakres());

panel_prawy = uipanel(siatka);
uklad_wykresow = tiledlayout(panel_prawy, 'flow');

odswiez();

    function zmieniono_prog()
        lbl_prog.Text = sprintf('Próg odchylenia: %.1f%% (AE: %.1fx)', suwak_prog.Value, suwak_prog.Value / 2);
        odswiez();
    end

    function zmieniono_zakres()
        grupa_cykli.SelectedObject = przycisk_wlasny;
        odswiez();
    end

    function odswiez()
        metoda = grupa_metod.SelectedObject.Tag;
        
        if (strcmp(metoda, 'ae') || strcmp(metoda, 'obie')) && ~czy_jest_ae
            uialert(okno, 'Najpierw uruchom skrypt trenuj_modele.m, aby utworzyć plik modele_ae.mat.', 'Brak modelu sieci');
            grupa_metod.SelectedObject = rb_mediana;
            metoda = 'mediana';
        end

        delete(uklad_wykresow.Children);
        tag_wyboru = grupa_cykli.SelectedObject.Tag;

        if strcmp(tag_wyboru, 'wlasny')
            cykl_start = pole_od.Value;
            cykl_koniec = pole_do.Value;
            
            if cykl_start > cykl_koniec
                temp = cykl_start;
                cykl_start = cykl_koniec;
                cykl_koniec = temp;
                pole_od.Value = cykl_start;
                pole_do.Value = cykl_koniec;
            end
        else
            cykl_start = 1;
            cykl_koniec = str2double(tag_wyboru);
        end

        rysuj_wykres(cb_ps1, 'PS1', 'Ciśnienie', 'bar', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_ts1, 'TS1', 'Temperatura', '°C', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_fs1, 'FS1', 'Przepływ', 'l/min', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_vs1, 'VS1', 'Drgania', 'mm/s', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_eps1, 'EPS1', 'Moc silnika', 'W', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_ce, 'CE', 'Wydajność chłodzenia', '%', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_cp, 'CP', 'Moc chłodzenia', 'kW', cykl_start, cykl_koniec, metoda);
        rysuj_wykres(cb_se, 'SE', 'Współczynnik sprawności', '%', cykl_start, cykl_koniec, metoda);
    end

    function rysuj_wykres(checkbox, klucz, tytul, jednostka, cykl_start, cykl_koniec, metoda)
        if checkbox.Value
            ax = nexttile(uklad_wykresow);
            macierz = dane.(klucz);

            kolumny = size(macierz, 2);
            liczba_wierszy = size(macierz, 1);

            if cykl_start > liczba_wierszy
                cykl_start = liczba_wierszy;
            end
            if cykl_koniec > liczba_wierszy
                cykl_koniec = liczba_wierszy;
            end

            wybrane = cykl_start:cykl_koniec;
            sygnal = macierz(wybrane, :);
            
            sygnal_ciagly = sygnal';
            sygnal_ciagly = sygnal_ciagly(:);

            krok_czasu = 60 / kolumny;
            czas = (cykl_start - 1) * 60 + (0:length(sygnal_ciagly)-1) * krok_czasu;
            czas = czas(:);

            if kolumny > 60
                okno_probek = max(3, round(5 / krok_czasu));
                baza = movmedian(sygnal_ciagly, okno_probek);
                odchylenie = abs(sygnal_ciagly - baza);
            else
                reszty_macierz = sygnal - stat_kal.(klucz).wzorzec;
                odchylenie_macierz = abs(reszty_macierz);
                odchylenie = odchylenie_macierz';
                odchylenie = odchylenie(:);
            end

            odchylki_stat = odchylenie > 3 * stat_kal.(klucz).mad;

            wspolczynnik_progu = suwak_prog.Value / 100;
            prog_minimalny = max([wspolczynnik_progu * stat_kal.(klucz).rozpietosc, ...
                0.25 * wspolczynnik_progu * abs(stat_kal.(klucz).mediana), eps]);
            odchylki_med = odchylki_stat & (odchylenie > prog_minimalny);

            odchylki_ae = false(size(sygnal_ciagly));
            if (strcmp(metoda, 'ae') || strcmp(metoda, 'obie')) && isfield(modele, klucz) && isfield(progi, klucz)
                odtworzone = predict(modele.(klucz), sygnal')';
                blad_macierz = abs(sygnal - odtworzone);
                blad_ciagly = blad_macierz';
                blad_ciagly = blad_ciagly(:);
                prog_ae = progi.(klucz) * (suwak_prog.Value / 2);
                odchylki_ae = blad_ciagly > prog_ae;
            end

            if strcmp(metoda, 'mediana')
                aktywne_anomalie = odchylki_med;
            elseif strcmp(metoda, 'ae')
                aktywne_anomalie = odchylki_ae;
            else
                aktywne_anomalie = odchylki_med | odchylki_ae;
            end

            h_syg = plot(ax, czas, sygnal_ciagly, 'LineWidth', 1.2);
            hold(ax, 'on');
            uchwyty = h_syg;
            etykiety = {'Sygnał'};

            if cb_trend.Value
                czas_czysty = czas(~aktywne_anomalie);
                sygnal_czysty = sygnal_ciagly(~aktywne_anomalie);

                if length(czas_czysty) >= 2 && max(czas_czysty) > min(czas_czysty)
                    [wspolczynniki, ~, mu] = polyfit(czas_czysty, sygnal_czysty, 1);
                    linia_trendu = polyval(wspolczynniki, czas, [], mu);
                else
                    linia_trendu = sygnal_ciagly;
                end

                h_trend = plot(ax, czas, linia_trendu, ':g', 'LineWidth', 1.8);
                uchwyty(end+1) = h_trend;
                etykiety{end+1} = 'Linia trendu';
            end

            if cb_anomalie.Value
                if (strcmp(metoda, 'mediana') || strcmp(metoda, 'obie')) && any(odchylki_med)
                    h_med = plot(ax, czas(odchylki_med), sygnal_ciagly(odchylki_med), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 2);
                    uchwyty(end+1) = h_med;
                    etykiety{end+1} = 'Filtr medianowy';
                end
                
                if (strcmp(metoda, 'ae') || strcmp(metoda, 'obie')) && any(odchylki_ae)
                    h_ae = plot(ax, czas(odchylki_ae), sygnal_ciagly(odchylki_ae), 'ms', 'MarkerFaceColor', 'm', 'MarkerSize', 2.5);
                    uchwyty(end+1) = h_ae;
                    etykiety{end+1} = 'Autokoder';
                end
            end

            if length(uchwyty) > 1
                legend(ax, uchwyty, etykiety, 'Location', 'best');
            end

            hold(ax, 'off');
            title(ax, tytul);
            xlabel(ax, 'Czas [s]');
            ylabel(ax, jednostka);
            grid(ax, 'on');
        end
    end
end


%[appendix]{"version":"1.0"}
%---
