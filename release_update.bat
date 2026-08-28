@echo off
echo Compilazione di Contabile App in corso...
call flutter build windows

echo Compilazione completata. Creazione dell'archivio zip sulla Scrivania...
powershell -Command "Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath $env:USERPROFILE\Desktop\Contabile_Aggiornamento.zip -Force"

echo.
echo Finito! Trovi il file Contabile_Aggiornamento.zip sulla tua Scrivania.
echo Puoi caricarlo su GitHub Releases tramite l'apposita schermata.
pause
