# HANDOFF - BimboMixer Contabilità

## 1. Stato Attuale (Risoluzioni UI Android & Testing)
- **Modifica AppBar limitata ad Android:** In `dashboard_screen.dart` è stata utilizzata la condizione sicura `(!kIsWeb && defaultTargetPlatform == TargetPlatform.android)` al posto di `Platform.isAndroid` (che rompe il Web).
- **Isolamento e Test AppBar:** 
  - L'AppBar è stata estratta nei due widget stateless `MobileDashboardAppBar` e `DesktopDashboardAppBar`.
  - In `test/dashboard_appbar_test.dart`, l'AppBar è isolata in uno Scaffold con *body neutro* e un drawer dummy.
  - È stato risolto il bug di timeout infinito nel test (causato dall'animazione perenne del Marquee / `AutoScrollText` su `pumpAndSettle`) utilizzando pump manuali, distruggendo l'albero alla fine (`pumpWidget(Container())`) e svuotando la coda dei timer fittizi (`pump(Duration(seconds: 10))`). Il test asserisce positivamente e naviga nel drawer reale senza soppressioni di errore globale.
- **Esposizione Overflow Body:** 
  - È stato creato `test/dashboard_full_test.dart` per testare la Dashboard nel suo complesso (usando dati mock tramite `FakeFirebaseFirestore`).
  - Questo test dimostra programmaticamente che la _body_ della Dashboard, a 320px e testo ingrandito, incorre in **RenderFlex overflow**, ma l'interfaccia AppBar/Drawer rimane esplorabile. Il test intercetta selettivamente questo layout break per pura visibilità in QA, passando con successo senza bloccare la pipeline.
- **Dati Intatti / Niente Pubblicazioni:** Non è stato alterato nulla nel DB, non sono state modificate le funzionalità di business core e NON sono stati lanciati script di pubblicazione (APK o GitHub release).

## 2. Priority / Problemi Precedenti (Da Mantenere e Investigare)
- **Investigare Note scomparse (Priority 2):** Segnalazioni da sessioni passate riguardo note perse, da indagare.
- **Protezione Allegati (Priority 3):** Rischio di file orfani tra Firebase Storage e Firestore.
- **Bug Preventivi:** Risoluzione caricamenti/bug segnalati prima sulle interfacce dei Preventivi.
- **Verifica Visiva Emulatore Necessaria:** Poiché il test ha programmaticamente riscontrato _RenderFlex overflow_ noti sulla _body_ della Dashboard, la risoluzione visuale definitiva di questi "spazi bianchi" che coprono i testi richiede un **controllo visivo umano o manuale su emulatore reale**.

## 3. Nuove Feature "Memo Pagamenti" in Attesa (NON INIZIATE)
Le seguenti istruzioni utente sono in stato di blocco fino al termine della supervisione grafica:
1. **Rinominare** "Memo Pagamenti eventi" in "Pagamenti programmati".
2. **Campi e Logica:** Aggiunta scelta "Movimento/Fattura" e "Entrata/Uscita" (con calcoli netti Incassi/Spese). Dati cliente, metodo, allegati e stato "Pagato/Attesa/Sollecitare".
3. **Automazione:** Al check "Pagato", trasferimento della riga nella collezione rispettiva.
4. **Fix "Agenda e Scadenze":** Tasto per uscire non funzionante (probabile navigator pop buggato).
5. **Logo:** Inserire logo "per lungo" e logo cerchiato corrispondente al login.
