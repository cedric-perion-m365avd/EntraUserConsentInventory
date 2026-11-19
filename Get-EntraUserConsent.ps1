#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Applications

<#
.SYNOPSIS
    Inventaire en lecture seule des consentements utilisateur individuels dans Microsoft Entra.

.DESCRIPTION
    Le script se connecte a Microsoft Graph avec des permissions deleguees en lecture,
    lit la politique d'autorisation du locataire pour indiquer quelles politiques de
    consentement sont assignees au role Utilisateur par defaut, puis liste les octrois
    de permissions deleguees de type consentement individuel (consentType Principal).

    Chaque octroi est retourne sous forme d'objet avec le nom de l'application, son AppId,
    l'editeur declare, les portees accordees, les portees qui depassent la simple
    connexion (openid, profile, email, User.Read) et l'identifiant objet de l'usager.

    Aucune ecriture n'est effectuee sur l'annuaire. L'etat de la politique de consentement
    est publie dans le flux d'information (utiliser -InformationAction Continue pour l'afficher).

    Permissions deleguees minimales : Policy.Read.All, Directory.Read.All.

.PARAMETER ExportCsv
    Chemin d'un fichier CSV local dans lequel exporter les resultats (encodage UTF8).
    Facultatif. Sans ce parametre, rien n'est ecrit sur le disque.

.PARAMETER KeepConnection
    Conserve la session Microsoft Graph ouverte a la fin de l'execution.
    Par defaut, le script se deconnecte de Microsoft Graph.

.EXAMPLE
    .\Get-EntraUserConsent.ps1 -InformationAction Continue

    Affiche l'etat de la politique de consentement et retourne un objet par octroi individuel.

.EXAMPLE
    .\Get-EntraUserConsent.ps1 -ExportCsv .\consentements.csv

    Retourne les octrois et les exporte dans le fichier consentements.csv.

.EXAMPLE
    .\Get-EntraUserConsent.ps1 | Where-Object { $_.PorteesHorsConnexion }

    Ne conserve que les octrois dont les portees depassent la simple connexion.

.EXAMPLE
    .\Get-EntraUserConsent.ps1 -KeepConnection -Verbose

    Execute l'inventaire avec des messages detailles et laisse la session Microsoft Graph ouverte.

.OUTPUTS
    System.Management.Automation.PSCustomObject

.NOTES
    Limites : seul le consentement individuel (Principal) est couvert. Les octrois
    AllPrincipals (consentement administrateur) et les attributions de roles applicatifs
    (permissions applicatives) ne sont pas listes.

.LINK
    https://trivium365.com/blog/azure-daily-connexion-microsoft-consentement-entra/
#>

[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ExportCsv,

    [Parameter()]
    [switch]$KeepConnection
)

$signInScopes = @('openid', 'profile', 'email', 'User.Read')
$scopes = @('Policy.Read.All', 'Directory.Read.All')

Write-Verbose -Message "Connexion a Microsoft Graph avec les portees : $($scopes -join ', ')"
Connect-MgGraph -Scopes $scopes -NoWelcome

try {
    # 1. Reglage de consentement utilisateur du locataire
    $policy = Get-MgPolicyAuthorizationPolicy
    $assigned = @($policy.DefaultUserRolePermissions.PermissionGrantPoliciesAssigned | Where-Object { $_ })

    if ($assigned.Count -gt 0) {
        Write-Information -MessageData "Politiques de consentement assignees au role Utilisateur : $($assigned -join ', ')"
    }
    else {
        Write-Information -MessageData 'Aucune politique retournee. Confirmez le reglage de consentement dans le centre Entra.'
    }

    # 2. Consentements accordes par des usagers (consentType = Principal)
    $grants = @(Get-MgOauth2PermissionGrant -All | Where-Object { $_.ConsentType -eq 'Principal' })
    Write-Information -MessageData "Consentements utilisateur individuels trouves : $($grants.Count)"

    # 3. Resolution du principal de service pour chaque octroi (avec cache)
    $spCache = @{}
    $results = foreach ($grant in $grants) {
        if (-not $spCache.ContainsKey($grant.ClientId)) {
            Write-Verbose -Message "Resolution du principal de service $($grant.ClientId)"
            try {
                $spCache[$grant.ClientId] = Get-MgServicePrincipal -ServicePrincipalId $grant.ClientId -ErrorAction Stop
            }
            catch {
                Write-Warning -Message "Principal de service introuvable pour ClientId $($grant.ClientId) : $($_.Exception.Message)"
                $spCache[$grant.ClientId] = $null
            }
        }
        $client = $spCache[$grant.ClientId]

        $scopeList = @("$($grant.Scope)".Trim() -split '\s+' | Where-Object { $_ })
        $beyondSignIn = @($scopeList | Where-Object { $signInScopes -notcontains $_ })

        $applicationName = $null
        $applicationId = $null
        $publisher = $null
        if ($client) {
            $applicationName = $client.DisplayName
            $applicationId = $client.AppId
            $publisher = $client.PublisherName
        }

        [pscustomobject]@{
            Application          = $applicationName
            AppId                = $applicationId
            Editeur              = $publisher
            Portees              = $scopeList -join ' '
            PorteesHorsConnexion = $beyondSignIn -join ' '
            UsagerObjetId        = $grant.PrincipalId
            ClientId             = $grant.ClientId
        }
    }

    $results = @($results | Sort-Object -Property Application)

    if ($ExportCsv) {
        $results | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
        Write-Information -MessageData "Export ecrit dans $ExportCsv"
    }

    Write-Output -InputObject $results
}
finally {
    if (-not $KeepConnection) {
        Write-Verbose -Message 'Deconnexion de Microsoft Graph.'
        $null = Disconnect-MgGraph
    }
}
