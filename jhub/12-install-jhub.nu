source ./env.nu
let values = $env.jupyterhub.jhub.values_path
let dockerhub = $env.jupyterhub.dockerhub
let secrets = $env.jupyterhub.secrets
let authentication = $env.jupyterhub.authentication

let release = "jhub"
let namespace = "jhub"

(helm upgrade --install $release jupyterhub/jupyterhub
  --namespace $namespace
  --create-namespace
  --version 4.2.0
  --debug
  --wait
  --timeout 10m
  --values $values
  --values $authentication
  --values $dockerhub
  --values $secrets
)
