# NoSpamProxy: S/MIME-Zertifikate exportieren und importieren

## 1. Was macht das Skript?

Das Skript unterstützt die Übertragung von S/MIME-Zertifikaten zwischen zwei
NoSpamProxy-Systemen, zum Beispiel bei einer Migration.

- Es exportiert gültige interne Zertifikate **mit privatem Schlüssel** als
  passwortgeschützte PFX-Dateien.
- Auf Wunsch exportiert es zusätzlich gültige **externe öffentliche**
  S/MIME-Zertifikate als CER-Dateien.
- Es importiert diese Dateien wieder in ein anderes NoSpamProxy-System.
- Es erstellt bei jedem Start eine Protokolldatei neben dem Skript.

Öffentliche Zertifikate mit einer eigenen Domain oder einer Zuordnung zu einem
internen Benutzer werden nicht als externe öffentliche Zertifikate exportiert
oder importiert.

**Wichtig für die Migration:** Das Skript überträgt keine Benutzerkonten,
eigenen Domains, Einstellungen, Vertrauensstellungen oder sonstige
Konfigurationen. Richten Sie die eigenen Domains auf dem Zielsystem vor dem
Import ein. Prüfen Sie nach dem Import die Benutzerzuordnungen und Einstellungen
im Zielsystem.

## 2. Voraussetzungen

Sie benötigen:

1. Zugriff auf das Quell- und das Zielsystem sowie auf deren NoSpamProxy-API.
2. Ein Konto mit den notwendigen NoSpamProxy-Berechtigungen für die
   Zertifikatsverwaltung.
3. Windows PowerShell **5.1** oder PowerShell **7** unter Windows.
4. Das installierte NoSpamProxy-PowerShell-Modul auf dem Rechner, auf dem das
   Skript ausgeführt wird.
5. Schreibzugriff auf den Ordner des Skripts für das Protokoll und auf den
   Exportordner für die Zertifikate.
6. Einen sicheren Weg, den Exportordner vom Quell- zum Zielsystem zu übertragen.

Bei Ausführung direkt auf dem jeweiligen NoSpamProxy-System kann normalerweise
der lokale Standard-Endpunkt verwendet werden. Bei einem entfernten System
können Sie eine passende API-Adresse mit `-Url` angeben. Im Provider-Modus
können Sie den gewünschten Mandanten mit `-PrimaryDomain` auswählen.

## 3. Skript herunterladen

1. Melden Sie sich bei GitHub mit einem Konto an, das Zugriff auf das private
   Repository hat.
2. Öffnen Sie
   [NoSpamProxy-Key-import-export](https://github.com/sbe-nsp/NoSpamProxy-Key-import-export).
3. Öffnen Sie die Datei `NoSpamProxy-Key-import-export.ps1`.
4. Laden Sie die Datei über die GitHub-Downloadfunktion für die Datei herunter.
5. Speichern Sie sie auf dem Quellsystem zum Beispiel hier:

   ```text
   C:\NSP-Migration\Script\NoSpamProxy-Key-import-export.ps1
   ```

   Falls der Ordner noch nicht existiert, legen Sie ihn im Windows-Explorer an.
   Achten Sie darauf, dass die Datei wirklich auf `.ps1` endet und nicht etwa
   auf `.ps1.txt`.
6. Legen Sie die gleiche Skriptdatei auch auf dem Zielsystem ab.

Die Anleitung ist zusätzlich in der Skripthilfe enthalten.

## 4. PowerShell öffnen und vorbereiten

### 4.1 PowerShell starten

1. Öffnen Sie das Windows-Startmenü.
2. Suchen Sie nach **Windows PowerShell** für Version 5.1 oder nach
   **PowerShell 7**, falls diese installiert ist.
3. Starten Sie das Programm. Falls für Ihre Umgebung erhöhte Rechte erforderlich
   sind, wählen Sie im Startmenü **Als Administrator ausführen**.

Das Fenster mit der Eingabezeile bleibt während der folgenden Schritte geöffnet.
Geben Sie einen Befehl jeweils vollständig ein und drücken Sie **Enter**.

### 4.2 Version prüfen

Geben Sie ein:

```powershell
$PSVersionTable.PSVersion
```

In der Ausgabe muss eine Version **5.1** oder **7** angezeigt werden. Die
konkreten weiteren Versionsnummern können abweichen.

### 4.3 NoSpamProxy-Modul prüfen

```powershell
Get-Module -ListAvailable NoSpamProxy
```

Wird das Modul angezeigt, laden und prüfen Sie es:

```powershell
Import-Module NoSpamProxy
Get-Command Connect-Nsp
```

Wird kein Modul oder kein Befehl gefunden, prüfen Sie die
NoSpamProxy-Installation und das installierte PowerShell-Modul auf diesem
Rechner. Die reine Installation von PowerShell installiert das
NoSpamProxy-Modul nicht automatisch.

### 4.4 In den Skriptordner wechseln

Wenn Sie den Beispielpfad aus Abschnitt 3 verwendet haben:

```powershell
Set-Location -Path "C:\NSP-Migration\Script"
```

Die Anführungszeichen sind auch bei Pfaden mit Leerzeichen hilfreich. Prüfen
Sie anschließend, ob die Datei sichtbar ist:

```powershell
Get-ChildItem -Name "NoSpamProxy-Key-import-export.ps1"
```

Die Ausgabe muss den Dateinamen zeigen. Das Zeichen `.\` vor einem Skriptnamen
bedeutet später: „Starte die Datei aus dem aktuellen Ordner.“

Optional können Sie die integrierte Hilfe anzeigen:

```powershell
Get-Help .\NoSpamProxy-Key-import-export.ps1 -Full
```

## 5. Export auf dem Quellsystem

Stellen Sie zuerst in der geöffneten PowerShell eine Verbindung zu NoSpamProxy
her:

```powershell
Connect-Nsp -IgnoreServerCertificateErrors -Credential (Get-Credential)
```

Geben Sie im Anmeldefenster Ihre NoSpamProxy-Zugangsdaten ein. Verwenden Sie
diesen Befehl auch auf dem Zielsystem, wenn Sie dort eine neue PowerShell für
den Import öffnen.

Das Skript stellt beim Start selbst eine neue Verbindung her und fragt deshalb
erneut nach den Zugangsdaten. Die Option `-IgnoreServerCertificateErrors` des
obigen Befehls gilt nicht automatisch für diese neue Verbindung: Falls nötig,
geben Sie die Option auch beim Skriptaufruf an, wie in Abschnitt 5.3 gezeigt.
Bei einem entfernten System oder im Provider-Modus beachten Sie zusätzlich
`-Url` beziehungsweise `-PrimaryDomain` in Abschnitt 8.

### 5.1 Nur interne Schlüsselpaare exportieren

Führen Sie auf dem **Quellsystem** nach Abschnitt 4 folgenden Befehl aus:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export"
```

`-Operation Export` wählt den Export. `-Path` legt fest, wo die exportierten
Dateien gespeichert werden. Das Skript legt das Unterverzeichnis `Private` an,
falls erforderlich.

Danach erscheinen zwei Eingabeaufforderungen:

1. Geben Sie die Zugangsdaten für NoSpamProxy ein.
2. Geben Sie ein Passwort für die PFX-Dateien ein. Während der Eingabe werden
   keine Zeichen angezeigt. Drücken Sie anschließend **Enter**.

Das gewählte PFX-Passwort wird für alle PFX-Dateien dieses Durchlaufs verwendet
und vom Skript nicht gespeichert. Für den Import muss exakt dasselbe Passwort
erneut eingegeben werden.

### 5.2 Interne Schlüsselpaare und externe öffentliche Zertifikate exportieren

Soll zusätzlich Phase 2 ausgeführt werden, verwenden Sie `-IncludePublic`:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -IncludePublic
```

Die internen Schlüsselpaare liegen anschließend in `Private`, die externen
öffentlichen Zertifikate in `Public`:

```text
C:\NSP-Migration\Export\
├── Private\
│   └── <Fingerabdruck>.pfx
└── Public\
    └── <Fingerabdruck>.cer
```

Die Dateinamen sind Beispiele; tatsächlich steht dort jeweils der
Zertifikatsfingerabdruck. Wenn keine passenden Zertifikate gefunden werden,
können die Ordner leer bleiben.

### 5.3 Option für Zertifikatsfehler bei der Verbindung

Wenn für Ihr System die Verbindung nur mit der entsprechenden
NoSpamProxy-Option aufgebaut werden soll, ergänzen Sie
`-IgnoreServerCertificateErrors`:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -IncludePublic -IgnoreServerCertificateErrors
```

Diese Option betrifft die Verbindung zu NoSpamProxy. Sie verändert nicht die
zeitliche Gültigkeitsprüfung der exportierten S/MIME-Zertifikate.

### 5.4 Ergebnis prüfen

Am Ende zeigt das Skript eine Zusammenfassung, zum Beispiel:

```text
[INFO] Abschluss: verarbeitet=6; uebersprungen=0; Fehler=0
```

Die Zahlen sind nur ein Beispiel. Prüfen Sie:

1. Steht dort `Fehler=0`?
2. Entspricht die Anzahl der verarbeiteten Zertifikate Ihrer Erwartung?
3. Sind die erwarteten Dateien im Exportordner vorhanden?

Ein erfolgreicher Abschluss mit `verarbeitet=0` bedeutet, dass keine passenden
Dateien verarbeitet wurden; prüfen Sie in diesem Fall Ihre Erwartung und die
Zertifikate im Quellsystem. Ein Fehler wird im Fenster und im Log ausgegeben.

Vorhandene Exportdateien werden **nicht überschrieben**. Für einen erneuten
vollständigen Export verwenden Sie am einfachsten einen neuen, leeren
Exportordner, zum Beispiel `C:\NSP-Migration\Export-2`.

## 6. Dateien auf das Zielsystem übertragen

1. Übertragen Sie den gesamten Exportordner auf das Zielsystem. Die
   Unterordner `Private` und, falls verwendet, `Public` müssen erhalten bleiben.
2. Legen Sie ihn dort zum Beispiel unter `C:\NSP-Migration\Import` ab.
3. Übertragen Sie auch das Skript auf das Zielsystem, falls noch nicht geschehen.
4. Stellen Sie sicher, dass die eigenen Domains auf dem Zielsystem eingerichtet
   sind.
5. Öffnen und prüfen Sie PowerShell auf dem Zielsystem wie in Abschnitt 4.

Beispiel für die Ordnerstruktur auf dem Zielsystem:

```text
C:\NSP-Migration\
├── Script\
│   └── NoSpamProxy-Key-import-export.ps1
└── Import\
    ├── Private\
    │   └── <Fingerabdruck>.pfx
    └── Public\
        └── <Fingerabdruck>.cer
```

Wurde ohne `-IncludePublic` exportiert, ist kein `Public`-Ordner erforderlich.

## 7. Import auf dem Zielsystem

### 7.1 Nur interne Schlüsselpaare importieren

Wechseln Sie auf dem **Zielsystem** in den Skriptordner und starten Sie:

```powershell
Set-Location -Path "C:\NSP-Migration\Script"
.\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path "C:\NSP-Migration\Import"
```

Geben Sie die NoSpamProxy-Zugangsdaten des **Zielsystems** ein. Bei der
PFX-Passwortabfrage geben Sie das Passwort ein, das Sie beim Export gewählt
haben.

### 7.2 Zusätzlich externe öffentliche Zertifikate importieren

Wenn Sie beim Export auch `-IncludePublic` verwendet haben und die öffentlichen
Zertifikate importieren möchten:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path "C:\NSP-Migration\Import" -IncludePublic
```

Bei dieser Variante müssen sowohl `Private` als auch `Public` unter dem
angegebenen Importpfad existieren. Ein leerer `Public`-Ordner ist zulässig.

Falls für die Verbindung erforderlich, können Sie auch beim Import
`-IgnoreServerCertificateErrors` ergänzen:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path "C:\NSP-Migration\Import" -IncludePublic -IgnoreServerCertificateErrors
```

### 7.3 Import kontrollieren

1. Prüfen Sie die Zusammenfassung im PowerShell-Fenster und das Log.
2. Prüfen Sie die Zertifikate und privaten Schlüssel im Zielsystem.
3. Vergleichen Sie die Ergebnisse mit dem Quellsystem.
4. Prüfen Sie Benutzerzuordnungen und weitere benötigte Einstellungen im
   Zielsystem.

Bereits im entsprechenden NoSpamProxy-Speicher vorhandene Zertifikate werden
übersprungen und im Log als `Bereits vorhanden` aufgeführt. Dateien, die beim
Import nicht mehr zeitlich gültig sind oder kein passendes S/MIME-Zertifikat
darstellen, werden ebenfalls übersprungen und protokolliert.

## 8. Weitere Beispiele

### 8.1 Pfad mit Leerzeichen

Setzen Sie den ganzen Pfad in Anführungszeichen:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "D:\NoSpamProxy Migration\Export" -IncludePublic
```

### 8.2 Entferntes NoSpamProxy-System

Die folgende Adresse ist **nur ein Beispiel**. Verwenden Sie die tatsächliche
API-Adresse Ihres Systems:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -Url "https://nospamproxy.example.com:6060"
```

Das NoSpamProxy-PowerShell-Modul muss auch auf dem Rechner installiert sein,
von dem aus Sie diesen Befehl starten. Netzwerkzugriff und Berechtigungen müssen
vorhanden sein.

### 8.3 Mandant im Provider-Modus

Ersetzen Sie `example.com` durch die primäre Domain des gewünschten Mandanten:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -PrimaryDomain "example.com" -IncludePublic
```

Bei Bedarf lassen sich `-Url`, `-PrimaryDomain` und
`-IgnoreServerCertificateErrors` kombinieren.

## 9. Protokoll finden und lesen

Das Skript erstellt für **jeden Start** eine neue Logdatei im selben Ordner
wie die Skriptdatei, nicht im Export- oder Importordner. Der Name beginnt mit
`NoSpamProxy-Key-import-export-` und enthält Datum, Uhrzeit und eine eindeutige
Kennung.

Im Beispiel aus dieser Anleitung liegt sie unter:

```text
C:\NSP-Migration\Script\
```

Öffnen Sie den Ordner im Windows-Explorer und doppelklicken Sie auf die
gewünschte `.log`-Datei. Sie können sie auch mit Editor/Notepad öffnen.

- `[INFO]`: Information zum Ablauf.
- `[WARN]`: Ein Eintrag wurde beispielsweise übersprungen.
- `[ERROR]`: Ein Fehler ist aufgetreten. Lesen Sie die Meldung in derselben
  Zeile und prüfen Sie die Abschlusszusammenfassung.

## 10. Häufige Fragen und Fehler

### „Die Datei oder der Befehl wurde nicht gefunden“

Prüfen Sie mit `Get-Location`, in welchem Ordner Sie sich befinden. Wechseln
Sie mit `Set-Location` in den Skriptordner und prüfen Sie mit
`Get-ChildItem`, ob die Datei dort liegt. Achten Sie auf `.\` vor dem
Skriptnamen und auf die Dateiendung `.ps1`.

### Die Ausführung von Skripten ist deaktiviert

Prüfen Sie die geltenden Einstellungen:

```powershell
Get-ExecutionPolicy -List
```

Ist die Datei als aus dem Internet heruntergeladen markiert, kann sie mit
folgendem Befehl freigegeben werden:

```powershell
Unblock-File -Path ".\NoSpamProxy-Key-import-export.ps1"
```

Falls die Richtlinien Ihrer Umgebung es erlauben, kann für das aktuell geöffnete
PowerShell-Fenster alternativ eine temporäre Einstellung gesetzt werden:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Danach den gewünschten Skriptbefehl erneut ausführen. Eine durch
Gruppenrichtlinien vorgegebene Einstellung kann Vorrang haben; wenden Sie sich
in diesem Fall an die zuständige Administration.

### NoSpamProxy-Anmeldung oder Verbindung schlägt fehl

Prüfen Sie das Konto, die Berechtigungen, das laufende System und gegebenenfalls
die API-Adresse. Bei Provider-Modus prüfen Sie zusätzlich `-PrimaryDomain`.
Wenn Ihre Umgebung diese Verbindungsoption benötigt, ergänzen Sie
`-IgnoreServerCertificateErrors`. Details stehen im Log.

### Ein PFX kann nicht importiert werden

Prüfen Sie, ob das beim Export verwendete Passwort exakt eingegeben wurde und
ob die Datei vollständig übertragen wurde. Der Import meldet Dateien ohne
privaten Schlüssel oder mit falschem Passwort als Fehler.

### Eine Exportdatei ist bereits vorhanden

Das Skript überschreibt sie nicht. Verwenden Sie einen neuen, leeren
Exportordner oder prüfen Sie die bereits vorhandenen Dateien, bevor Sie erneut
exportieren.

### Ein Zertifikat wird nicht exportiert oder importiert

Das Skript berücksichtigt nur zum Ausführungszeitpunkt gültige Zertifikate.
Beim Export werden die Speicher `My` und, für öffentliche Zertifikate,
`TrustedPeople` berücksichtigt. Für S/MIME muss entweder die entsprechende
erweiterte Schlüsselverwendung erlaubt sein oder keine einschränkende
Erweiterung vorhanden sein.

Für externe öffentliche Zertifikate muss eine Mailadresse bestimmbar sein.
Interne Adressen beziehungsweise interne Benutzerzuordnungen schließen sie
vom öffentlichen Export oder Import aus. Nicht eindeutig zuordenbare
Zertifikate und nicht exportierbare private Schlüssel werden als Fehler
gemeldet. Die Prüfung umfasst nicht den Vertrauensstatus oder eine
Sperrlistenprüfung.

## 11. Version und Patchnotes

- **Version:** 1.0.1
- **Build:** 20261127.2
- **Datum:** 27.11.2026
- **Patchnotes 1.0.1:** Ausführliche Einsteigeranleitung mit Beispielen,
  Migrationsablauf, Voraussetzungen und Fehlerbehebung ergänzt. Die
  Skriptfunktionen bleiben unverändert.
- **Patchnotes 1.0.0:** Erstversion für den Export und Import interner
  Schlüsselpaare sowie optionaler externer öffentlicher S/MIME-Zertifikate.
