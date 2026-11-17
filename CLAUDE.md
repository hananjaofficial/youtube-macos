# macOS App Development Guidelines

## Tech Stack & Architektur
- Nutze natives Swift und SwiftUI (aktuelles macOS SDK, kein veraltetes macOS-12-Boilerplate).
- Verwende das moderne `@Observable`-Makro statt `ObservableObject` / `@Published`.
- Trenne UI-Views sauber von Business-Logik (Services / Models).

## macOS UI & UX Standards
- Nutze native macOS-Komponenten (`NavigationSplitView`, `Settings`-Scene, `MenuBarExtra`, `.toolbar`).
- Achte auf korrekte Tastaturkürzel (`keyboardShortcut`), Fenstergrößen und Dark-Mode-Unterstützung.
- Vermeide iOS-spezifische APIs (`UIKit`, `NavigationView`, `.navigationBarTitle`).

## Workflow
- Lies vor Änderungen immer zuerst die bestehende Projektstruktur über das Filesystem-Tool.
- Prüfe nach Code-Änderungen den Build über `XcodeBuildMCP` und behebe Compiler-Fehler selbstständig, bevor du antwortest.

