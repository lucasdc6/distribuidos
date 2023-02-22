# Infraestructura

## Requerimientos

- asdf

Todos los requerimientos necesarios para desplegar los servidores en AWS se encuentran cubiertos por `asdf`, por lo que recomendamos usar esta herramienta o respetar las versiones descritas en `.tool-versions`

```bash
asdf install
```

## Terraform

Para iniciar el ambiente de terraform hace falta configurar el perfil a usar, bajar las dependencias y configurar cantidad de instancias, redes, entre otras cosas.

```bash
cd terraform
export AWS_PROFILE=<PERFIL>
terraform init
```

Para conocer las variables necesarias, se puede consultar el archivo `vars.tf`. Por ejemplo

```bash
cat <<TF_VARS > terraform.tfvars2
instance_count = 1
vpc_id         = "vpc-xxxxx"
subnet_id      = "subnet-xxxxxxx"
key_name       = "mi_clave_ssh"
TF_VARS

# Analizar la salida del comando
terraform plan

terraform apply
```

Esto nos va a dejar actualizar el archivo de hosts para ansible en el directorio `ansible/hosts.yaml`

## Ansible

Para este punto recomendamos iniciar un virtualenv para encapsular las dependencias del proyecto. Por ejemplo

```bash
cd ansible
python -m virtualenv venv
. venv/bin/activate
```

Luego, instalar las dependencias

```bash
pip install -r requirements.txt
ansible-galaxy install -r requirements.yaml
```

Ahora debemos configurar las credenciales para acceder a la registry de `ghcr`, para esto, se puede crear un [PERSONAL ACCESS TOKEN](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token), el cual solo require permisos `read:packages` para interactuar con la registry.

```bash
cat <<CREDS > credentials.yaml
registry_username: GITHUB_USERNAME
registry_password: GITHUB_PERSONAL_ACCESS_TOKEN
CREDS
```

_Notar que este archivo se encuentra en el gitignore, por lo que no corremos peligro de subirlo al repositrorio. De todas formas, se recomienda configurar una fecha de expiración_

Finalmente, solo hace falta ejecutar ansible con el playbook `playbooks/install.yaml`

```bash
ansible-playbook -i hosts.yaml playbooks/install.yaml
```