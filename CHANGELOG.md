# Changelog

Toutes les modifications notables de ce projet sont consignées dans ce fichier.

## [1.0.0] 2026-11-03

### Ajouté

- Script Get-EntraUserConsent.ps1 en lecture seule.
- Lecture des politiques de consentement assignées au rôle Utilisateur par défaut.
- Inventaire des octrois de permissions déléguées de type consentement individuel (consentType Principal).
- Résolution des principaux de service avec cache et avertissement en cas d'échec.
- Propriété PorteesHorsConnexion pour isoler les portées autres que openid, profile, email et User.Read.
- Export CSV facultatif avec le paramètre ExportCsv.
- Paramètre KeepConnection pour conserver la session Microsoft Graph.
