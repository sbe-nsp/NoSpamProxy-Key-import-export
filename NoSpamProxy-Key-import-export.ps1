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
  Version: 1.0.0
  Build: 20261127.1
  Datum: 2026-11-27
  Patchnotes: Erstversion mit PFX-Export/-Import, optionalen externen
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
