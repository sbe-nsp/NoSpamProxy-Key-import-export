<#
.SYNOPSIS
  Exportiert und importiert S/MIME-Zertifikate fuer eine NoSpamProxy-Migration.
.DESCRIPTION
  Exportiert gueltige interne Schluesselpaare aus dem Speicher My als
  passwortgeschuetzte PFX-Dateien. Optional werden gueltige externe S/MIME-
  Zertifikate aus TrustedPeople und My als CER-Dateien exportiert. Zugeordnete
  interne Zertifikate und Zertifikate mit internen Mailadressen sind davon ausgeschlossen.
  Importiert werden die Dateien aus den entsprechenden Unterordnern Private und
  Public. Bereits vorhandene Zertifikate werden beim Import uebersprungen.

  Voraussetzungen: Windows PowerShell 5.1 oder PowerShell 7 unter Windows,
  installiertes NoSpamProxy-PowerShell-Modul, API-Zugriff und konfigurierte
  eigene Domains. Bei Provider-Modus muss der Zielmandant angegeben werden.
  Die Benutzerkonten, Domains, Vertrauen und sonstige Konfiguration werden nicht
  migriert. Die eigenen Domains muessen vor dem Import konfiguriert sein.
  Das PFX-Passwort wird einmal abgefragt und nicht gespeichert.
  Bereits vorhandene Exportdateien werden nicht ueberschrieben.
  Ein eigenes Log wird bei jedem Start neben diesem Skript erstellt.

  Zertifikate ohne eindeutig ermittelbare Mailadresse koennen nicht sicher als
  externe Zertifikate klassifiziert werden und werden als Fehler gemeldet.
  Nicht exportierbare private Schluessel werden ebenfalls als Fehler gemeldet.
  Gueltigkeit bezieht sich auf den Zeitraum NotBefore bis NotAfter, nicht auf
  den Vertrauensstatus oder eine Sperrlistenpruefung.
  --- Ausfuehrliche Anleitung ---

# NoSpamProxy: S/MIME-Zertifikate exportieren und importieren

## 1. Was macht das Skript?

Das Skript unterstuetzt die Uebertragung von S/MIME-Zertifikaten zwischen zwei
NoSpamProxy-Systemen, zum Beispiel bei einer Migration.

- Es exportiert gueltige interne Zertifikate **mit privatem Schluessel** als
  passwortgeschuetzte PFX-Dateien.
- Auf Wunsch exportiert es zusaetzlich gueltige **externe oeffentliche**
  S/MIME-Zertifikate als CER-Dateien.
- Es importiert diese Dateien wieder in ein anderes NoSpamProxy-System.
- Es erstellt bei jedem Start eine Protokolldatei neben dem Skript.

Oeffentliche Zertifikate mit einer eigenen Domain oder einer Zuordnung zu einem
internen Benutzer werden nicht als externe oeffentliche Zertifikate exportiert
oder importiert.

**Wichtig fuer die Migration:** Das Skript uebertraegt keine Benutzerkonten,
eigenen Domains, Einstellungen, Vertrauensstellungen oder sonstige
Konfigurationen. Richten Sie die eigenen Domains auf dem Zielsystem vor dem
Import ein. Pruefen Sie nach dem Import die Benutzerzuordnungen und Einstellungen
im Zielsystem.

## 2. Voraussetzungen

Sie benoetigen:

1. Zugriff auf das Quell- und das Zielsystem sowie auf deren NoSpamProxy-API.
2. Ein Konto mit den notwendigen NoSpamProxy-Berechtigungen fuer die
   Zertifikatsverwaltung.
3. Windows PowerShell **5.1** oder PowerShell **7** unter Windows.
4. Das installierte NoSpamProxy-PowerShell-Modul auf dem Rechner, auf dem das
   Skript ausgefuehrt wird.
5. Schreibzugriff auf den Ordner des Skripts fuer das Protokoll und auf den
   Exportordner fuer die Zertifikate.
6. Einen sicheren Weg, den Exportordner vom Quell- zum Zielsystem zu uebertragen.

Bei Ausfuehrung direkt auf dem jeweiligen NoSpamProxy-System kann normalerweise
der lokale Standard-Endpunkt verwendet werden. Bei einem entfernten System
koennen Sie eine passende API-Adresse mit `-Url` angeben. Im Provider-Modus
koennen Sie den gewuenschten Mandanten mit `-PrimaryDomain` auswaehlen.

## 3. Skript herunterladen

1. Melden Sie sich bei GitHub mit einem Konto an, das Zugriff auf das private
   Repository hat.
2. Oeffnen Sie
   [NoSpamProxy-Key-import-export](https://github.com/sbe-nsp/NoSpamProxy-Key-import-export).
3. Oeffnen Sie die Datei `NoSpamProxy-Key-import-export.ps1`.
4. Laden Sie die Datei ueber die GitHub-Downloadfunktion fuer die Datei herunter.
5. Speichern Sie sie auf dem Quellsystem zum Beispiel hier:

   ```text
   C:\NSP-Migration\Script\NoSpamProxy-Key-import-export.ps1
   ```

   Falls der Ordner noch nicht existiert, legen Sie ihn im Windows-Explorer an.
   Achten Sie darauf, dass die Datei wirklich auf `.ps1` endet und nicht etwa
   auf `.ps1.txt`.
6. Legen Sie die gleiche Skriptdatei auch auf dem Zielsystem ab.

Die Anleitung ist auch als README.md im Repository enthalten.

## 4. PowerShell oeffnen und vorbereiten

### 4.1 PowerShell starten

1. Oeffnen Sie das Windows-Startmenue.
2. Suchen Sie nach **Windows PowerShell** fuer Version 5.1 oder nach
   **PowerShell 7**, falls diese installiert ist.
3. Starten Sie das Programm. Falls fuer Ihre Umgebung erhoehte Rechte erforderlich
   sind, waehlen Sie im Startmenue **Als Administrator ausfuehren**.

Das Fenster mit der Eingabezeile bleibt waehrend der folgenden Schritte geoeffnet.
Geben Sie einen Befehl jeweils vollstaendig ein und druecken Sie **Enter**.

### 4.2 Version pruefen

Geben Sie ein:

```powershell
$PSVersionTable.PSVersion
```

In der Ausgabe muss eine Version **5.1** oder **7** angezeigt werden. Die
konkreten weiteren Versionsnummern koennen abweichen.

### 4.3 NoSpamProxy-Modul pruefen

```powershell
Get-Module -ListAvailable NoSpamProxy
```

Wird das Modul angezeigt, laden und pruefen Sie es:

```powershell
Import-Module NoSpamProxy
Get-Command Connect-Nsp
```

Wird kein Modul oder kein Befehl gefunden, pruefen Sie die
NoSpamProxy-Installation und das installierte PowerShell-Modul auf diesem
Rechner. Die reine Installation von PowerShell installiert das
NoSpamProxy-Modul nicht automatisch.

### 4.4 In den Skriptordner wechseln

Wenn Sie den Beispielpfad aus Abschnitt 3 verwendet haben:

```powershell
Set-Location -Path "C:\NSP-Migration\Script"
```

Die Anfuehrungszeichen sind auch bei Pfaden mit Leerzeichen hilfreich. Pruefen
Sie anschliessend, ob die Datei sichtbar ist:

```powershell
Get-ChildItem -Name "NoSpamProxy-Key-import-export.ps1"
```

Die Ausgabe muss den Dateinamen zeigen. Das Zeichen `.\` vor einem Skriptnamen
bedeutet spaeter: "Starte die Datei aus dem aktuellen Ordner."

Optional koennen Sie die integrierte Hilfe anzeigen:

```powershell
Get-Help .\NoSpamProxy-Key-import-export.ps1 -Full
```

## 5. Export auf dem Quellsystem

### 5.1 Nur interne Schluesselpaare exportieren

Fuehren Sie auf dem **Quellsystem** nach Abschnitt 4 folgenden Befehl aus:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export"
```

`-Operation Export` waehlt den Export. `-Path` legt fest, wo die exportierten
Dateien gespeichert werden. Das Skript legt das Unterverzeichnis `Private` an,
falls erforderlich.

Danach erscheinen zwei Eingabeaufforderungen:

1. Geben Sie die Zugangsdaten fuer NoSpamProxy ein.
2. Geben Sie ein Passwort fuer die PFX-Dateien ein. Waehrend der Eingabe werden
   keine Zeichen angezeigt. Druecken Sie anschliessend **Enter**.

Das gewaehlte PFX-Passwort wird fuer alle PFX-Dateien dieses Durchlaufs verwendet
und vom Skript nicht gespeichert. Fuer den Import muss exakt dasselbe Passwort
erneut eingegeben werden.

### 5.2 Interne Schluesselpaare und externe oeffentliche Zertifikate exportieren

Soll zusaetzlich Phase 2 ausgefuehrt werden, verwenden Sie `-IncludePublic`:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -IncludePublic
```

Die internen Schluesselpaare liegen anschliessend in `Private`, die externen
oeffentlichen Zertifikate in `Public`:

```text
C:\NSP-Migration\Export\
+-- Private\
|   +-- <Fingerabdruck>.pfx
+-- Public\
    +-- <Fingerabdruck>.cer
```

Die Dateinamen sind Beispiele; tatsaechlich steht dort jeweils der
Zertifikatsfingerabdruck. Wenn keine passenden Zertifikate gefunden werden,
koennen die Ordner leer bleiben.

### 5.3 Option fuer Zertifikatsfehler bei der Verbindung

Wenn fuer Ihr System die Verbindung nur mit der entsprechenden
NoSpamProxy-Option aufgebaut werden soll, ergaenzen Sie
`-IgnoreServerCertificateErrors`:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -IncludePublic -IgnoreServerCertificateErrors
```

Diese Option betrifft die Verbindung zu NoSpamProxy. Sie veraendert nicht die
zeitliche Gueltigkeitspruefung der exportierten S/MIME-Zertifikate.

### 5.4 Ergebnis pruefen

Am Ende zeigt das Skript eine Zusammenfassung, zum Beispiel:

```text
[INFO] Abschluss: verarbeitet=6; uebersprungen=0; Fehler=0
```

Die Zahlen sind nur ein Beispiel. Pruefen Sie:

1. Steht dort `Fehler=0`?
2. Entspricht die Anzahl der verarbeiteten Zertifikate Ihrer Erwartung?
3. Sind die erwarteten Dateien im Exportordner vorhanden?

Ein erfolgreicher Abschluss mit `verarbeitet=0` bedeutet, dass keine passenden
Dateien verarbeitet wurden; pruefen Sie in diesem Fall Ihre Erwartung und die
Zertifikate im Quellsystem. Ein Fehler wird im Fenster und im Log ausgegeben.

Vorhandene Exportdateien werden **nicht ueberschrieben**. Fuer einen erneuten
vollstaendigen Export verwenden Sie am einfachsten einen neuen, leeren
Exportordner, zum Beispiel `C:\NSP-Migration\Export-2`.

## 6. Dateien auf das Zielsystem uebertragen

1. Uebertragen Sie den gesamten Exportordner auf das Zielsystem. Die
   Unterordner `Private` und, falls verwendet, `Public` muessen erhalten bleiben.
2. Legen Sie ihn dort zum Beispiel unter `C:\NSP-Migration\Import` ab.
3. Uebertragen Sie auch das Skript auf das Zielsystem, falls noch nicht geschehen.
4. Stellen Sie sicher, dass die eigenen Domains auf dem Zielsystem eingerichtet
   sind.
5. Oeffnen und pruefen Sie PowerShell auf dem Zielsystem wie in Abschnitt 4.

Beispiel fuer die Ordnerstruktur auf dem Zielsystem:

```text
C:\NSP-Migration\
+-- Script\
|   +-- NoSpamProxy-Key-import-export.ps1
+-- Import\
    +-- Private\
    |   +-- <Fingerabdruck>.pfx
    +-- Public\
        +-- <Fingerabdruck>.cer
```

Wurde ohne `-IncludePublic` exportiert, ist kein `Public`-Ordner erforderlich.

## 7. Import auf dem Zielsystem

### 7.1 Nur interne Schluesselpaare importieren

Wechseln Sie auf dem **Zielsystem** in den Skriptordner und starten Sie:

```powershell
Set-Location -Path "C:\NSP-Migration\Script"
.\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path "C:\NSP-Migration\Import"
```

Geben Sie die NoSpamProxy-Zugangsdaten des **Zielsystems** ein. Bei der
PFX-Passwortabfrage geben Sie das Passwort ein, das Sie beim Export gewaehlt
haben.

### 7.2 Zusaetzlich externe oeffentliche Zertifikate importieren

Wenn Sie beim Export auch `-IncludePublic` verwendet haben und die oeffentlichen
Zertifikate importieren moechten:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path "C:\NSP-Migration\Import" -IncludePublic
```

Bei dieser Variante muessen sowohl `Private` als auch `Public` unter dem
angegebenen Importpfad existieren. Ein leerer `Public`-Ordner ist zulaessig.

Falls fuer die Verbindung erforderlich, koennen Sie auch beim Import
`-IgnoreServerCertificateErrors` ergaenzen:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path "C:\NSP-Migration\Import" -IncludePublic -IgnoreServerCertificateErrors
```

### 7.3 Import kontrollieren

1. Pruefen Sie die Zusammenfassung im PowerShell-Fenster und das Log.
2. Pruefen Sie die Zertifikate und privaten Schluessel im Zielsystem.
3. Vergleichen Sie die Ergebnisse mit dem Quellsystem.
4. Pruefen Sie Benutzerzuordnungen und weitere benoetigte Einstellungen im
   Zielsystem.

Bereits im entsprechenden NoSpamProxy-Speicher vorhandene Zertifikate werden
uebersprungen und im Log als `Bereits vorhanden` aufgefuehrt. Dateien, die beim
Import nicht mehr zeitlich gueltig sind oder kein passendes S/MIME-Zertifikat
darstellen, werden ebenfalls uebersprungen und protokolliert.

## 8. Weitere Beispiele

### 8.1 Pfad mit Leerzeichen

Setzen Sie den ganzen Pfad in Anfuehrungszeichen:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "D:\NoSpamProxy Migration\Export" -IncludePublic
```

### 8.2 Entferntes NoSpamProxy-System

Die folgende Adresse ist **nur ein Beispiel**. Verwenden Sie die tatsaechliche
API-Adresse Ihres Systems:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -Url "https://nospamproxy.example.com:6060"
```

Das NoSpamProxy-PowerShell-Modul muss auch auf dem Rechner installiert sein,
von dem aus Sie diesen Befehl starten. Netzwerkzugriff und Berechtigungen muessen
vorhanden sein.

### 8.3 Mandant im Provider-Modus

Ersetzen Sie `example.com` durch die primaere Domain des gewuenschten Mandanten:

```powershell
.\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path "C:\NSP-Migration\Export" -PrimaryDomain "example.com" -IncludePublic
```

Bei Bedarf lassen sich `-Url`, `-PrimaryDomain` und
`-IgnoreServerCertificateErrors` kombinieren.

## 9. Protokoll finden und lesen

Das Skript erstellt fuer **jeden Start** eine neue Logdatei im selben Ordner
wie die Skriptdatei, nicht im Export- oder Importordner. Der Name beginnt mit
`NoSpamProxy-Key-import-export-` und enthaelt Datum, Uhrzeit und eine eindeutige
Kennung.

Im Beispiel aus dieser Anleitung liegt sie unter:

```text
C:\NSP-Migration\Script\
```

Oeffnen Sie den Ordner im Windows-Explorer und doppelklicken Sie auf die
gewuenschte `.log`-Datei. Sie koennen sie auch mit Editor/Notepad oeffnen.

- `[INFO]`: Information zum Ablauf.
- `[WARN]`: Ein Eintrag wurde beispielsweise uebersprungen.
- `[ERROR]`: Ein Fehler ist aufgetreten. Lesen Sie die Meldung in derselben
  Zeile und pruefen Sie die Abschlusszusammenfassung.

## 10. Haeufige Fragen und Fehler

### "Die Datei oder der Befehl wurde nicht gefunden"

Pruefen Sie mit `Get-Location`, in welchem Ordner Sie sich befinden. Wechseln
Sie mit `Set-Location` in den Skriptordner und pruefen Sie mit
`Get-ChildItem`, ob die Datei dort liegt. Achten Sie auf `.\` vor dem
Skriptnamen und auf die Dateiendung `.ps1`.

### Die Ausfuehrung von Skripten ist deaktiviert

Pruefen Sie die geltenden Einstellungen:

```powershell
Get-ExecutionPolicy -List
```

Ist die Datei als aus dem Internet heruntergeladen markiert, kann sie mit
folgendem Befehl freigegeben werden:

```powershell
Unblock-File -Path ".\NoSpamProxy-Key-import-export.ps1"
```

Falls die Richtlinien Ihrer Umgebung es erlauben, kann fuer das aktuell geoeffnete
PowerShell-Fenster alternativ eine temporaere Einstellung gesetzt werden:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Danach den gewuenschten Skriptbefehl erneut ausfuehren. Eine durch
Gruppenrichtlinien vorgegebene Einstellung kann Vorrang haben; wenden Sie sich
in diesem Fall an die zustaendige Administration.

### NoSpamProxy-Anmeldung oder Verbindung schlaegt fehl

Pruefen Sie das Konto, die Berechtigungen, das laufende System und gegebenenfalls
die API-Adresse. Bei Provider-Modus pruefen Sie zusaetzlich `-PrimaryDomain`.
Wenn Ihre Umgebung diese Verbindungsoption benoetigt, ergaenzen Sie
`-IgnoreServerCertificateErrors`. Details stehen im Log.

### Ein PFX kann nicht importiert werden

Pruefen Sie, ob das beim Export verwendete Passwort exakt eingegeben wurde und
ob die Datei vollstaendig uebertragen wurde. Der Import meldet Dateien ohne
privaten Schluessel oder mit falschem Passwort als Fehler.

### Eine Exportdatei ist bereits vorhanden

Das Skript ueberschreibt sie nicht. Verwenden Sie einen neuen, leeren
Exportordner oder pruefen Sie die bereits vorhandenen Dateien, bevor Sie erneut
exportieren.

### Ein Zertifikat wird nicht exportiert oder importiert

Das Skript beruecksichtigt nur zum Ausfuehrungszeitpunkt gueltige Zertifikate.
Beim Export werden die Speicher `My` und, fuer oeffentliche Zertifikate,
`TrustedPeople` beruecksichtigt. Fuer S/MIME muss entweder die entsprechende
erweiterte Schluesselverwendung erlaubt sein oder keine einschraenkende
Erweiterung vorhanden sein.

Fuer externe oeffentliche Zertifikate muss eine Mailadresse bestimmbar sein.
Interne Adressen beziehungsweise interne Benutzerzuordnungen schliessen sie
vom oeffentlichen Export oder Import aus. Nicht eindeutig zuordenbare
Zertifikate und nicht exportierbare private Schluessel werden als Fehler
gemeldet. Die Pruefung umfasst nicht den Vertrauensstatus oder eine
Sperrlistenpruefung.

## 11. Version und Patchnotes

- **Version:** 1.0.1
- **Build:** 20261127.2
- **Datum:** 27.11.2026
- **Patchnotes 1.0.1:** Ausfuehrliche Einsteigeranleitung mit Beispielen,
  Migrationsablauf, Voraussetzungen und Fehlerbehebung ergaenzt. Die
  Skriptfunktionen bleiben unveraendert.
- **Patchnotes 1.0.0:** Erstversion fuer den Export und Import interner
  Schluesselpaare sowie optionaler externer oeffentlicher S/MIME-Zertifikate.

.PARAMETER Operation
  Export oder Import.
.PARAMETER Path
  Verzeichnis fuer den Export beziehungsweise mit den zu importierenden Dateien.
.PARAMETER IncludePublic
  Zusaetzlich externe oeffentliche S/MIME-Zertifikate verarbeiten.
.PARAMETER Credential
  Optionales PSCredential fuer Connect-Nsp. Ohne Angabe erfolgt eine Abfrage.
.PARAMETER PfxPassword
  Optionales SecureString-Passwort fuer alle PFX-Dateien. Ohne Angabe erfolgt
  eine verdeckte Abfrage.
.PARAMETER Url
  Optionale NoSpamProxy-API-URL.
.PARAMETER PrimaryDomain
  Optionaler Mandant fuer den Provider-Modus.
.PARAMETER IgnoreServerCertificateErrors
  Zertifikatsfehler bei der NoSpamProxy-Verbindung ignorieren.
.EXAMPLE
  .\NoSpamProxy-Key-import-export.ps1 -Operation Export -Path C:\Migration -IncludePublic -IgnoreServerCertificateErrors
.EXAMPLE
  .\NoSpamProxy-Key-import-export.ps1 -Operation Import -Path C:\Migration -IncludePublic -IgnoreServerCertificateErrors
.NOTES
  Version: 1.0.1
  Build: 20261127.2
  Datum: 2026-11-27
  Patchnotes 1.0.1: Ausfuehrliche Einsteigeranleitung mit Beispielen ergaenzt.
  Patchnotes 1.0.0: Erstversion mit PFX-Export/-Import, optionalen externen
  S/MIME-Zertifikaten, Domainfilterung und Protokollierung.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Export', 'Import')]
    [string] $Operation,

    [Parameter(Mandatory = $true)]
    [string] $Path,

    [switch] $IncludePublic,
    [pscredential] $Credential,
    [securestring] $PfxPassword,
    [uri] $Url,
    [string] $PrimaryDomain,
    [switch] $IgnoreServerCertificateErrors
)

$ErrorActionPreference = 'Stop'
$logPath = Join-Path $PSScriptRoot ('NoSpamProxy-Key-import-export-{0}-{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N'))

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-AllCertificates {
    param([string] $Store)
    [uint64] $skip = 0
    do {
        $page = @(Get-NspCertificate -StoreIds $Store -KeyValidity All -First 100 -Skip $skip -ErrorAction Stop)
        $page
        $skip += $page.Count
    } while ($page.Count -eq 100)
}

function Get-AllUsers {
    [uint64] $skip = 0
    do {
        $page = @(Get-NspUser -First 100 -Skip $skip -ErrorAction Stop)
        $page
        $skip += $page.Count
    } while ($page.Count -eq 100)
}

function Test-OwnAddress {
    param([string] $Address)
    $at = $Address.LastIndexOf('@')
    if ($at -lt 1 -or $at -eq ($Address.Length - 1) -or
        $Address.IndexOf('@') -ne $at -or $Address -match '\s') {
        throw "Ungueltige Mailadresse in Zertifikat: $Address"
    }
    $domain = $Address.Substring($at + 1).TrimEnd('.')
    try {
        $domain = ([System.Globalization.IdnMapping]::new()).GetAscii($domain)
    } catch {
        throw "Ungueltige Mail-Domain in Zertifikat: $Address"
    }
    return $ownDomains.Contains($domain)
}

function Read-DerLength {
    param([byte[]] $Bytes, [ref] $Offset)
    if ($Offset.Value -ge $Bytes.Length) { throw 'Ungueltige ASN.1-Laenge.' }
    $length = [int] $Bytes[$Offset.Value]
    $Offset.Value++
    if (($length -band 0x80) -ne 0) {
        $count = $length -band 0x7f
        if ($count -eq 0 -or $count -gt 4 -or ($Offset.Value + $count) -gt $Bytes.Length) {
            throw 'Ungueltige ASN.1-Laenge.'
        }
        [long] $length = 0
        for ($i = 0; $i -lt $count; $i++) {
            $length = ($length * 256) + $Bytes[$Offset.Value]
            $Offset.Value++
        }
    }
    if ($length -gt ($Bytes.Length - $Offset.Value)) { throw 'Unvollstaendige ASN.1-Daten.' }
    return [int] $length
}

function Get-CertificateAddresses {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate)
    $addresses = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $name = $Certificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::EmailName, $false)
    if ($name) { [void] $addresses.Add($name) }
    foreach ($extension in $Certificate.Extensions) {
        if ($extension.Oid.Value -ne '2.5.29.17') { continue }
        $bytes = $extension.RawData
        [int] $offset = 0
        if ($bytes.Length -lt 2 -or $bytes[$offset++] -ne 0x30) { throw 'Ungueltige Subject-Alternative-Name-Erweiterung.' }
        $sequenceLength = Read-DerLength $bytes ([ref] $offset)
        $end = $offset + $sequenceLength
        if ($end -ne $bytes.Length) { throw 'Ungueltige Subject-Alternative-Name-Erweiterung.' }
        while ($offset -lt $end) {
            $tag = $bytes[$offset++]
            $length = Read-DerLength $bytes ([ref] $offset)
            if (($offset + $length) -gt $end) { throw 'Ungueltiger Subject-Alternative-Name-Eintrag.' }
            if ($tag -eq 0x81) {
                $mail = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, $length)
                if ($mail) { [void] $addresses.Add($mail) }
            }
            $offset += $length
        }
    }
    return @($addresses)
}

function Test-SmimeCertificate {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate)
    foreach ($extension in $Certificate.Extensions) {
        if ($extension.Oid.Value -eq '2.5.29.37') {
            $eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new()
            $eku.CopyFrom($extension)
            foreach ($oid in $eku.EnhancedKeyUsages) {
                if ($oid.Value -in @('1.3.6.1.5.5.7.3.4', '2.5.29.37.0')) { return $true }
            }
            return $false
        }
    }
    return $true
}

function Test-CurrentlyValid {
    param([datetime] $From, [datetime] $To)
    $now = [datetime]::UtcNow
    return ($From.ToUniversalTime() -le $now -and $To.ToUniversalTime() -gt $now)
}

function Get-SummaryAddresses {
    param($Summary)
    foreach ($mail in $Summary.MailAddresses) {
        if ($mail -and $mail.Address) { [string] $mail.Address }
    }
}

function Test-Internal {
    param([string] $Thumbprint, [string[]] $Addresses)
    if ($internalThumbprints.Contains($Thumbprint)) { return $true }
    foreach ($address in $Addresses) {
        if (Test-OwnAddress $address) { return $true }
    }
    return $false
}

function Save-NewFile {
    param([string] $FilePath, [byte[]] $Bytes)
    $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}

try {
    Write-Log "Start: $Operation; IncludePublic=$IncludePublic"
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    Import-Module NoSpamProxy -ErrorAction Stop
    if (-not $Credential) { $Credential = Get-Credential -Message 'NoSpamProxy-Anmeldung' }
    if (-not $Credential) { throw 'Keine Zugangsdaten angegeben.' }
    $connect = @{ Credential = $Credential.GetNetworkCredential(); ErrorAction = 'Stop' }
    if ($Url) { $connect.Url = $Url }
    if ($PrimaryDomain) { $connect.PrimaryDomain = $PrimaryDomain }
    if ($IgnoreServerCertificateErrors) { $connect.IgnoreServerCertificateErrors = $true }
    Connect-Nsp @connect | Out-Null

    $ownDomains = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($domain in @(Get-NspOwnedDomain -ErrorAction Stop)) {
        if ($domain.Name) {
            [void] $ownDomains.Add(([System.Globalization.IdnMapping]::new()).GetAscii($domain.Name.TrimEnd('.')))
        }
    }
    if ($ownDomains.Count -eq 0) { throw 'Keine eigenen Domains gefunden; Zuordnung nicht moeglich.' }

    $internalThumbprints = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($user in @(Get-AllUsers)) {
        foreach ($mail in $user.MailAddresses) {
            if ($mail.Address -and (Test-OwnAddress ([string] $mail.Address.Address))) {
                foreach ($certificate in $mail.AssociatedCertificates) {
                    if ($certificate.Thumbprint) { [void] $internalThumbprints.Add($certificate.Thumbprint) }
                }
            }
        }
    }

    if (-not $PfxPassword) { $PfxPassword = Read-Host 'Passwort fuer die PFX-Dateien' -AsSecureString }
    if (-not $PfxPassword -or $PfxPassword.Length -eq 0) { throw 'Das PFX-Passwort darf nicht leer sein.' }
    $privatePath = Join-Path $Path 'Private'
    $publicPath = Join-Path $Path 'Public'
    $failures = 0
    $processed = 0
    $skipped = 0

    if ($Operation -eq 'Export') {
        [void] [System.IO.Directory]::CreateDirectory($privatePath)
        if ($IncludePublic) { [void] [System.IO.Directory]::CreateDirectory($publicPath) }
        $exportedPublic = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $plainPassword = [System.Net.NetworkCredential]::new('', $PfxPassword).Password
        try {
            foreach ($store in @('My', 'TrustedPeople')) {
                if ($store -eq 'TrustedPeople' -and -not $IncludePublic) { continue }
                foreach ($summary in @(Get-AllCertificates $store)) {
                    if (-not (Test-CurrentlyValid $summary.ValidFrom $summary.ValidTo)) { continue }
                    $thumbprint = [string] $summary.Thumbprint
                    try {
                        if ($thumbprint -notmatch '^[0-9A-Fa-f]+$') { throw 'Ungueltiger Fingerabdruck.' }
                        $summaryAddresses = @(Get-SummaryAddresses $summary)
                        if ($store -eq 'TrustedPeople' -and (Test-Internal $thumbprint $summaryAddresses)) { continue }
                        $export = @(Export-NspCertificate -Thumbprint $thumbprint -ErrorAction Stop)
                        if ($export.Count -ne 1 -or -not $export[0].Certificate) { throw 'Oeffentlicher Zertifikatexport lieferte kein eindeutiges Ergebnis.' }
                        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]] $export[0].Certificate)
                        try {
                            if ($cert.Thumbprint -ne $thumbprint) { throw 'Fingerabdruck des exportierten Zertifikats stimmt nicht ueberein.' }
                            if (-not (Test-CurrentlyValid $cert.NotBefore $cert.NotAfter) -or -not (Test-SmimeCertificate $cert)) { continue }
                            $addresses = @($summaryAddresses) + @(Get-CertificateAddresses $cert)
                            $internal = Test-Internal $thumbprint $addresses
                            if ($store -eq 'TrustedPeople' -and $internal) { continue }
                            if ($store -eq 'My' -and -not $internal -and $addresses.Count -eq 0) {
                                throw 'Keine Mailadresse oder Benutzerzuordnung vorhanden; interne Zuordnung nicht moeglich.'
                            }
                            if ($store -eq 'My' -and -not $internal -and -not $IncludePublic) { continue }
                            if ($store -eq 'TrustedPeople' -or -not $internal) {
                                if ($addresses.Count -eq 0) { throw 'Keine Mailadresse ermittelbar; externe Zuordnung nicht moeglich.' }
                                if ($exportedPublic.Contains($thumbprint)) { continue }
                                $file = Join-Path $publicPath ($thumbprint + '.cer')
                                Save-NewFile $file ($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
                                [void] $exportedPublic.Add($thumbprint)
                            } else {
                                $pfx = @(Export-NspCertificate -Thumbprint $thumbprint -PrivateKeyPassword $plainPassword -ErrorAction Stop)
                                if ($pfx.Count -ne 1 -or -not $pfx[0].Certificate) { throw 'Privater Zertifikatexport lieferte kein eindeutiges Ergebnis.' }
                                $check = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]] $pfx[0].Certificate, $PfxPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
                                try {
                                    if (-not $check.HasPrivateKey -or $check.Thumbprint -ne $thumbprint) { throw 'Exportiertes PFX enthaelt nicht den erwarteten privaten Schluessel.' }
                                } finally { $check.Dispose() }
                                $file = Join-Path $privatePath ($thumbprint + '.pfx')
                                Save-NewFile $file ([byte[]] $pfx[0].Certificate)
                            }
                            $processed++
                            Write-Log "Exportiert: $thumbprint ($store)"
                        } finally { $cert.Dispose() }
                    } catch {
                        $failures++
                        Write-Log "Export fehlgeschlagen: $thumbprint ($store): $($_.Exception.Message)" 'ERROR'
                    }
                }
            }
        } finally { $plainPassword = $null }
    } else {
        if (-not (Test-Path -LiteralPath $privatePath -PathType Container)) { throw "Privat-Verzeichnis fehlt: $privatePath" }
        if ($IncludePublic -and -not (Test-Path -LiteralPath $publicPath -PathType Container)) { throw "Public-Verzeichnis fehlt: $publicPath" }
        $existingPrivate = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $existingPublic = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($summary in @(Get-AllCertificates 'My')) { [void] $existingPrivate.Add([string] $summary.Thumbprint) }
        if ($IncludePublic) {
            foreach ($summary in @(Get-AllCertificates 'TrustedPeople')) { [void] $existingPublic.Add([string] $summary.Thumbprint) }
        }
        $groups = @(@{ Directory = $privatePath; Extension = '*.pfx'; Private = $true; Existing = $existingPrivate })
        if ($IncludePublic) { $groups += @{ Directory = $publicPath; Extension = '*.cer'; Private = $false; Existing = $existingPublic } }
        foreach ($group in $groups) {
            foreach ($file in @(Get-ChildItem -LiteralPath $group.Directory -Filter $group.Extension -File)) {
                try {
                    if ($group.Private) {
                        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($file.FullName, $PfxPassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
                    } else {
                        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($file.FullName)
                    }
                    try {
                        if ($group.Private -and -not $cert.HasPrivateKey) { throw 'PFX enthaelt keinen privaten Schluessel.' }
                        if (-not $group.Private -and $cert.HasPrivateKey) { throw 'CER enthaelt unerwartet einen privaten Schluessel.' }
                        if (-not (Test-CurrentlyValid $cert.NotBefore $cert.NotAfter) -or -not (Test-SmimeCertificate $cert)) {
                            $skipped++
                            Write-Log "Nicht gueltig oder kein S/MIME: $($file.Name)" 'WARN'
                            continue
                        }
                        $addresses = @(Get-CertificateAddresses $cert)
                        if (-not $group.Private) {
                            if (Test-Internal $cert.Thumbprint $addresses) {
                                $skipped++
                                Write-Log "Internes Zertifikat nicht als Public importiert: $($file.Name)" 'WARN'
                                continue
                            }
                            if ($addresses.Count -eq 0) { throw 'Keine Mailadresse ermittelbar; externe Zuordnung nicht moeglich.' }
                        }
                        if ($group.Existing.Contains($cert.Thumbprint)) {
                            $skipped++
                            Write-Log "Bereits vorhanden: $($cert.Thumbprint)"
                            continue
                        }
                        Import-NspCertificate -Certificate $cert -ErrorAction Stop | Out-Null
                        [void] $group.Existing.Add($cert.Thumbprint)
                        $processed++
                        Write-Log "Importiert: $($cert.Thumbprint)"
                    } finally { $cert.Dispose() }
                } catch {
                    $failures++
                    Write-Log "Import fehlgeschlagen: $($file.Name): $($_.Exception.Message)" 'ERROR'
                }
            }
        }
    }
    Write-Log "Abschluss: verarbeitet=$processed; uebersprungen=$skipped; Fehler=$failures"
    if ($failures -gt 0) { throw "Es sind $failures Fehler aufgetreten. Details siehe Log." }
} catch {
    Write-Log $_.Exception.Message 'ERROR'
    throw
}
