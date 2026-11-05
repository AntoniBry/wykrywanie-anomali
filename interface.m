function interface()

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
    disp('Brakuje plików. Uruchom najpierw skrypt konwertujący dla wszystkich danych.');
    return;
end

okno = uifigure('Name', 'Analiza Czujników', 'Position', [100, 100, 1050, 750]);

siatka = uigridlayout(okno, [1, 2]);
siatka.ColumnWidth = {260, '1x'};

panel_lewy = uigridlayout(siatka, [13, 1]);
panel_lewy.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 90, 30, '1x'};

uilabel(panel_lewy, 'Text', 'Wybierz wielkości do analizy:');

cb_ps1 = uicheckbox(panel_lewy, 'Text', 'Ciśnienie', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_ts1 = uicheckbox(panel_lewy, 'Text', 'Temperatura', 'Value', 1, 'ValueChangedFcn', @(src, event) odswiez());
cb_fs1 = uicheckbox(panel_lewy, 'Text', 'Przepływ', 'ValueChangedFcn', @(src, event) odswiez());
cb_vs1 = uicheckbox(panel_lewy, 'Text', 'Drgania', 'ValueChangedFcn', @(src, event) odswiez());
cb_eps1 = uicheckbox(panel_lewy, 'Text', 'Moc silnika', 'ValueChangedFcn', @(src, event) odswiez());
cb_ce = uicheckbox(panel_lewy, 'Text', 'Wydajność chłodzenia', 'ValueChangedFcn', @(src, event) odswiez());
cb_cp = uicheckbox(panel_lewy, 'Text', 'Moc chłodzenia', 'ValueChangedFcn', @(src, event) odswiez());
cb_se = uicheckbox(panel_lewy, 'Text', 'Współczynnik sprawności', 'ValueChangedFcn', @(src, event) odswiez());

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

    function zmieniono_zakres()
        grupa_cykli.SelectedObject = przycisk_wlasny;
        odswiez();
    end

    function odswiez()
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

        rysuj_wykres(cb_ps1, dane.PS1, 'Ciśnienie', 'bar', cykl_start, cykl_koniec);
        rysuj_wykres(cb_ts1, dane.TS1, 'Temperatura', '°C', cykl_start, cykl_koniec);
        rysuj_wykres(cb_fs1, dane.FS1, 'Przepływ', 'l/min', cykl_start, cykl_koniec);
        rysuj_wykres(cb_vs1, dane.VS1, 'Drgania', 'mm/s', cykl_start, cykl_koniec);
        rysuj_wykres(cb_eps1, dane.EPS1, 'Moc silnika', 'W', cykl_start, cykl_koniec);
        rysuj_wykres(cb_ce, dane.CE, 'Wydajność chłodzenia', '%', cykl_start, cykl_koniec);
        rysuj_wykres(cb_cp, dane.CP, 'Moc chłodzenia', 'kW', cykl_start, cykl_koniec);
        rysuj_wykres(cb_se, dane.SE, 'Współczynnik sprawności', '%', cykl_start, cykl_koniec);
    end

    function rysuj_wykres(checkbox, macierz, tytul, jednostka, cykl_start, cykl_koniec)
        if checkbox.Value
            ax = nexttile(uklad_wykresow);

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
            czas = (0:length(sygnal_ciagly)-1) * krok_czasu;

            plot(ax, czas, sygnal_ciagly, 'LineWidth', 1.2);
            title(ax, tytul);
            xlabel(ax, 'Czas [s]');
            ylabel(ax, jednostka);
            grid(ax, 'on');
        end
    end
end

%[appendix]{"version":"1.0"}
%---
