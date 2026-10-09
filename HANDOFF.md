# HANDOFF — BimboMixer Contabilità (aggiornato 06/10/2026)

## Stato
- Versione corrente: vedi `pubspec.yaml` (release ≥ 1.8.98 su GitHub BimboMixer-Releases).
- Progetto attivo: SOLO `contabile_app`. Non usare `contabile_app_mixed_backup` (contiene TaxFlow).

## Ultime modifiche
- Dashboard: "Nuovo Pag. Programmato" apre `MemoFormScreen` (schermata "Nuova Programmazione").
- Importi in formato italiano `000.000,00` nei form (memo/payment) in caricamento.
- Movimenti (`payments_screen.dart`): titolo "Movimenti", intestazioni in italiano, ordinamento (Data più recente di default, Data meno recente, Importo) tramite icona ordina accanto ai chip; colonna ID mostra solo ID formato `A001` (record legacy con ID Firestore casuale mostrano "—": NON migrati per regola di protezione dati).
- PDF Movimenti/report (`pdf_report_service.dart`): font Google con fallback offline; su Windows/Linux/macOS salva in `Downloads` e apre il file; su mobile usa share.
- Preventivi: IVA di default 0% (nessun 22% automatico); etichetta IVA calcolata dai dati.
- `insertPayment`: ID progressivo allocato con transazione su `metadata/payment_counter`, senza sovrascritture.

## Da fare / aperti
- `invoices_screen.dart`: restyling tabellare come Movimenti NON eseguito (subagente fermato per quota). Ordinamento per numero fattura/data già presente.
- Test manuali: rotazione schermata Movimenti anche in landscape; PDF Movimenti su Android e Windows; creazione nuovo movimento (ID A00x progressivo); preventivo senza IVA.
- Non rinominare/migrare record o credenziali esistenti.

## Regole di rilascio
Bump versione in `pubspec.yaml` → `flutter test` → `taskkill java/dart`, `flutter clean` → `github_release.ps1`.