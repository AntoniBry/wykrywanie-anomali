dane.PS1 = load('PS1.mat').dane_PS1;
dane.TS1 = load('TS1.mat').dane_TS1;
dane.FS1 = load('FS1.mat').dane_FS1;
dane.VS1 = load('VS1.mat').dane_VS1;
dane.EPS1 = load('EPS1.mat').dane_EPS1;
dane.CE = load('CE.mat').dane_CE;
dane.CP = load('CP.mat').dane_CP;
dane.SE = load('SE.mat').dane_SE;

try
    profil = load('profile.txt');
    zdrowe = find(profil(:,1) == 100 & profil(:,2) == 100 & profil(:,3) == 0 & profil(:,4) == 130 & profil(:,5) == 0);
catch
    zdrowe = 1:50;
end

if length(zdrowe) < 10
    zdrowe = 1:50;
end

nazwy = fieldnames(dane);

for i = 1:length(nazwy) %[output:group:60d4be2c]
    nazwa = nazwy{i};
    fprintf('Trenowanie sieci dla czujnika: %s...\n', nazwa); %[output:00a61b92]

    macierz = dane.(nazwa);
    dane_uczace = macierz(zdrowe, :)';

    siec = trainAutoencoder(dane_uczace, 10, 'MaxEpochs', 60, 'ShowProgressWindow', false);

    odtworzone = predict(siec, dane_uczace);
    bledy = abs(dane_uczace - odtworzone);
    prog = mean(bledy(:)) + 4 * std(bledy(:));

    modele.(nazwa) = siec;
    progi.(nazwa) = prog;
end %[output:group:60d4be2c]

save('modele_ae.mat', 'modele', 'progi');
disp('Gotowe. Zapisano plik modele_ae.mat.'); %[output:4381cb6f]

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright"}
%---
%[output:00a61b92]
%   data: {"dataType":"text","outputData":{"text":"Trenowanie sieci dla czujnika: PS1...\nTrenowanie sieci dla czujnika: TS1...\nTrenowanie sieci dla czujnika: FS1...\nTrenowanie sieci dla czujnika: VS1...\nTrenowanie sieci dla czujnika: EPS1...\nTrenowanie sieci dla czujnika: CE...\nTrenowanie sieci dla czujnika: CP...\nTrenowanie sieci dla czujnika: SE...\n","truncated":false}}
%---
%[output:4381cb6f]
%   data: {"dataType":"text","outputData":{"text":"Gotowe. Zapisano plik modele_ae.mat.\n","truncated":false}}
%---
