# EntraUserConsentInventory

Script PowerShell en lecture seule qui affiche le réglage de consentement utilisateur d'un locataire Microsoft Entra et inventorie les octrois de permissions déléguées que des usagers ont accordés eux-mêmes à des applications (consentType Principal).

Ce dépôt accompagne l'article [« Se connecter avec Microsoft » : relire le consentement utilisateur dans Entra](https://trivium365.com/blog/azure-daily-connexion-microsoft-consentement-entra/) de Cédric Périon.

## À quoi sert l'outil

Quand un usager clique sur « Se connecter avec Microsoft » avec son compte professionnel sur un site tiers, l'application externe peut demander un consentement. Si la politique du locataire le permet, l'usager accorde lui-même ce consentement. Entra enregistre alors un principal de service pour l'application dans le locataire ainsi qu'un octroi de permission déléguée (oauth2PermissionGrant) rattaché à cet usager.

L'outil répond à deux questions avant tout changement de réglage :

- Quelles politiques de consentement sont assignées au rôle Utilisateur par défaut ? Confirmez la portée des politiques dans le centre Entra avant de conclure sur le consentement autorisé.
- À quelles applications des usagers ont-ils déjà consenti individuellement et avec quelles portées ?

Chaque octroi est retourné sous forme d'objet PowerShell. La propriété PorteesHorsConnexion isole les portées qui dépassent la simple connexion (openid, profile, email et User.Read) afin de repérer en premier les applications qui demandent par exemple Mail.Read ou Files.ReadWrite.All.

L'outil n'écrit rien dans l'annuaire. Il ne contient aucune action qui modifie le locataire. La seule écriture possible est un fichier CSV local lorsque le paramètre ExportCsv est fourni.

## Pourquoi maintenant

Aidan Finn a lancé The Azure Daily le 12 octobre 2026. Ce site agrège des actualités Azure et propose une connexion facultative basée sur l'authentification Microsoft pour recevoir une infolettre hebdomadaire. La source ne précise pas si le site accepte les comptes Microsoft personnels ou les comptes professionnels Entra. Ce lancement n'est donc qu'un prétexte : la logique de consentement s'applique à tous les services tiers qui affichent ce bouton. Avant de durcir la politique de consentement, il vaut mieux savoir ce que vos usagers ont déjà approuvé.

## Prérequis

- PowerShell avec le module Microsoft Graph PowerShell (Microsoft.Graph). Le script déclare les sous-modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns et Microsoft.Graph.Applications.
- Permissions déléguées Microsoft Graph minimales : Policy.Read.All et Directory.Read.All.
- Un compte autorisé à obtenir ces permissions déléguées dans le locataire. L'article ne précise pas de rôle Entra minimal ; validez ce point selon votre propre modèle d'administration.

## Installation

1. Installez le module Microsoft Graph PowerShell (Microsoft.Graph) depuis PowerShell Gallery si ce n'est pas déjà fait.
2. Clonez ce dépôt ou téléchargez le fichier Get-EntraUserConsent.ps1.
3. Ouvrez une session PowerShell dans le dossier du script.

```powershell
git clone https://github.com/cedric-perion-m365avd/EntraUserConsentInventory.git
Set-Location .\EntraUserConsentInventory
```

## Exemples d'utilisation

Afficher l'aide complète :

```powershell
Get-Help .\Get-EntraUserConsent.ps1 -Full
```

Inventaire simple avec l'état de la politique de consentement affiché :

```powershell
.\Get-EntraUserConsent.ps1 -InformationAction Continue
```

Export CSV, comme dans l'article :

```powershell
.\Get-EntraUserConsent.ps1 -ExportCsv .\consentements.csv
```

Ne garder que les octrois qui dépassent la simple connexion :

```powershell
.\Get-EntraUserConsent.ps1 | Where-Object { $_.PorteesHorsConnexion } | Format-Table Application, Editeur, PorteesHorsConnexion
```

Conserver la session Microsoft Graph ouverte après l'exécution :

```powershell
.\Get-EntraUserConsent.ps1 -KeepConnection
```

## Exemple de sortie

L'exemple suivant est entièrement fictif. Les noms, AppId et identifiants sont inventés pour illustrer le format.

```text
Politiques de consentement assignees au role Utilisateur : exemple-politique-faible-impact
Consentements utilisateur individuels trouves : 2

Application          : Exemple Infolettre
AppId                : 00000000-0000-0000-0000-000000000001
Editeur              : Exemple Editeur
Portees              : openid profile email
PorteesHorsConnexion :
UsagerObjetId        : 00000000-0000-0000-0000-0000000000aa
ClientId             : 00000000-0000-0000-0000-000000000011

Application          : Exemple Outil Fichiers
AppId                : 00000000-0000-0000-0000-000000000002
Editeur              :
Portees              : openid User.Read Files.ReadWrite.All
PorteesHorsConnexion : Files.ReadWrite.All
UsagerObjetId        : 00000000-0000-0000-0000-0000000000bb
ClientId             : 00000000-0000-0000-0000-000000000022
```

Relisez d'abord les applications sans éditeur déclaré et celles dont la propriété PorteesHorsConnexion n'est pas vide.

## Limites connues

- Seul le consentement individuel (consentType Principal) est couvert. Les octrois de type AllPrincipals (consentement administrateur) ne sont pas listés.
- Les attributions de rôles applicatifs (permissions applicatives) ne sont pas listées.
- La propriété Editeur reprend le nom d'éditeur déclaré (PublisherName). Elle ne confirme pas qu'il s'agit d'un éditeur vérifié.
- La liste des portées de connexion utilisée pour PorteesHorsConnexion se limite à openid, profile, email et User.Read. Toute autre portée y apparaît, sans évaluation plus fine du risque.
- L'outil ne modifie pas la politique de consentement et ne configure pas le flux d'approbation administrateur (admin consent workflow). Ces réglages se font dans le centre d'administration Entra sous Applications d'entreprise puis Consentement et autorisations.
- Si un principal de service ne peut pas être résolu, un avertissement est émis et les propriétés de l'application restent vides pour cet octroi.
- Si The Azure Daily n'accepte que des comptes Microsoft personnels, aucun principal de service lié à ce site n'apparaîtra dans votre locataire professionnel.

## Liens

- Article : [« Se connecter avec Microsoft » : relire le consentement utilisateur dans Entra](https://trivium365.com/blog/azure-daily-connexion-microsoft-consentement-entra/)
- Source citée dans l'article : [The Azure Daily: Launching My Azure News Aggregator](https://aidanfinn.com/?p=25036) (Aidan Finn, 12 octobre 2026)

- [Configurer le consentement utilisateur](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/configure-user-consent)
- [Lister les octrois de permissions déléguées](https://learn.microsoft.com/en-us/graph/api/oauth2permissiongrant-list?view=graph-rest-1.0)
- [Lire la politique d'autorisation](https://learn.microsoft.com/en-us/graph/api/authorizationpolicy-get?view=graph-rest-1.0)
- [Lire un principal de service](https://learn.microsoft.com/en-us/graph/api/serviceprincipal-get?view=graph-rest-1.0)

Directory.Read.All couvre aussi la lecture des principaux de service. Le script ne demande donc pas Application.Read.All en supplément.

## Licence

MIT. Voir le fichier LICENSE.


## Démonstration en vidéo

https://www.youtube.com/watch?v=6fC5PkY2o74
