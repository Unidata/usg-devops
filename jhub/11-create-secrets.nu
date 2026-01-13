source ./env.nu

# Hub Secrets
touch $env.jupyterhub.secrets
open $env.jupyterhub.secrets
| try {from yaml} catch { {} } # If file empty, initialize empty record
| upsert hub.cookieSecret (random binary 32 | encode hex | str downcase)
| upsert proxy.secretToken (random binary 32 | encode hex | str downcase)
| save -f $env.jupyterhub.secrets

# Add Oauth callback URL in authentication.yaml
let domain = $"($env.jupyterhub.cluster.name).($env.jupyterhub.zone | str trim -r -c ".")"
open $env.jupyterhub.authentication
| upsert hub.config.GitHubOAuthenticator.oauth_callback_url $"https://($domain):443/oauth_callback"
| save -f $env.jupyterhub.authentication
