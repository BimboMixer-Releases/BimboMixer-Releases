# HANDOFF - BimboMixer Contabilità (Supervisione completata 2026-10-01)

## 1. Stato Attuale (Risoluzioni UI Android)
- **Modifica AppBar limitata ad Android:** In `dashboard_screen.dart` è stata mantenuta la condizione sicura `(!kIsWeb && defaultTargetPlatform == TargetPlatform.android)` al posto della chiamata diretta a `Platform.isAndroid`. In questo modo si evitano crash su Flutter Web.
- **Isolamento AppBar:** Le Appbar sono state estratte in due widget dedicati (`MobileDashboardAppBar` e `DesktopDashboardAppBar`) separandole dal body della `DashboardScreen`.
- **Prevenzione Layout Overflow:** Per evitare errori di layout con schermo molto stretto (320px) e testo ingrandito (font scale 1.5x) la row contenente i bottoni "Nuova operazione" e le notifiche è racchiusa in un `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
- **Test Widget aggiunto e superato:** È stato creato e validato `test/dashboard_appbar_test.dart` che istanzia `MobileDashboardAppBar` in uno Scaffold isolato con un "body neutro" (come richiesto in supervisione), forzando le constraint estreme (320px, 1.5x font scale). 
  - Il test verifica correttamente l'apertura del *Drawer* tramite il tasto menu e l'assenza di eccezioni tramite `tester.takeException()`. 
  - `addTearDown` assicura la pulizia del *Platform Override* a fine run.
  - *Attenzione:* Esiste un debito tecnico separato noto (non legato all'AppBar) per cui il *resto del body* della Dashboard va in RenderFlex overflow sotto quelle medesime constraint estreme, testabile mantenendo separato il testing globale.
- **Nessuna alterazione ai dati:** Il database, gli account e le password non sono stati toccati, rispettando le disposizioni di QA.
- **Pubblicazioni Sospese:** Nessun rilascio GitHub o APK è stato generato o sostituito (nessun lancio di script).

## 2. Priority / Problemi Precedenti (Da Mantenere)
Questi problemi erano stati identificati nei turni precedenti e non devono essere sovrascritti:
- **Investigare Note scomparse (Priority 2):** Indagare sulla scomparsa di alcune "Note" segnalata nelle sessioni precedenti. Nessuna sovrascrittura permessa.
- **Protezione Allegati (Priority 3):** Risolvere il rischio di perdita file/dati tra Firebase Storage e Firestore.
- **Bug Preventivi:** Risolvere bug upload/gestione su preventivi sollevati precedentemente.
- **Login / Calcoli:** Eventuali refactoring per disconnessioni anomale o disallineamenti contabili.

## 3. Prossimi Passi Nuovi (Richieste Utente "Memo Pagamenti")
L'utente ha lasciato istruzioni in sospeso per implementare una nuova variante di funzionalità:
1. **Rinominare** "Memo Pagamenti eventi" in "Pagamenti programmati".
2. **Scelta Memo:** Modificare la creazione dei memo permettendo di scegliere "Movimento o Fattura" e "Entrata o Uscita" (integrando i calcoli con "Incassi" e "Spese" nel patrimonio netto).
3. **Nuovi campi Memo:** Titolo, Data (singola o range "da/a"), Se Fattura mostrare "Numero Fattura" e "Data compilazione", Dati cliente (cell, email), Metodo di Pagamento, Categoria, Tipo servizio, Importo, Note, Allegati, e Stato (In Attesa, Pagato, Da sollecitare).
4. **Logica di Pagamento:** Quando un memo viene marcato "Pagato", dev'essere trasferito automaticamente nella sezione corrispondente ("Movimenti" o "Fatture") e sommato/sottratto.
5. **UI / Fix Grafici:** Risolvere spazi bianchi che nascondono il testo segnalati dall'utente.
6. **Agenda/Scadenze:** Tasto per uscire dalla sezione non funzionante.
7. **Logo/Intestazioni App:** Logo della dashboard uguale a quello del login ("cerchiato in verde").

L'Agente successivo può riprendere da queste feature richieste.
