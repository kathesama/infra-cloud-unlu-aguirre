# Lab 3 en AWS: EC2 stateful con EBS y Session Manager

Esta guía adapta el ejercicio de cargas *stateful* a AWS sin reemplazar los
ejemplos originales de GCP. El 13 de octubre de 2026 se desplegó y verificó el
entorno en `us-east-1`, con Terraform `1.16.5` y el proveedor AWS `6.68.0`.
AWS rechazó inicialmente la EC2 `t3.medium` porque el plan Free de la cuenta
admite solamente tipos elegibles; por eso el valor predeterminado se cambió a
`c7i-flex.large`, con 2 vCPU y 4 GiB. El despliegue final quedó operativo con
EC2, EBS, IAM, Session Manager, Docker, el servicio patrón y Ollama.

La actividad concluyó con la destrucción verificada de los nueve recursos
administrados por Terraform. La entrega final está disponible en
[`entrega/Lab-3-AWS-Katherine-Aguirre-ajustado-guia.pdf`](entrega/Lab-3-AWS-Katherine-Aguirre-ajustado-guia.pdf)
y en su versión editable
[`entrega/Lab-3-AWS-Katherine-Aguirre-ajustado-guia.docx`](entrega/Lab-3-AWS-Katherine-Aguirre-ajustado-guia.docx).

## Equivalencias de ejecución por sección

La adaptación conserva el objetivo de cada paso de la guía, pero sustituye los
comandos específicos de GCP por recursos declarados en Terraform y operaciones
de AWS. Los comandos Linux, Docker y `curl` se mantienen cuando no dependen del
proveedor.

| Sección original | GCP | Equivalencia aplicada en AWS |
| --- | --- | --- |
| 1.1 Crear la VM | `gcloud compute instances create` y startup-script | `aws_instance` y `user_data`, creados mediante un plan guardado de Terraform |
| 1.2 Crear y adjuntar el disco | `disks create` y `instances attach-disk` | `aws_ebs_volume` y `aws_volume_attachment` |
| 1.3 Formatear y montar | SSH, `mkfs.ext4`, `blkid`, `mount` y `fstab` | Las mismas operaciones Linux automatizadas en `user-data.sh.tftpl`, con controles para no formatear un disco con datos |
| 2.1 Crear el servicio | Servidor mínimo escrito en la VM | Servicio `app/` del template, clonado y construido por el bootstrap |
| 2.2 Build y run | `docker build` y `docker run -v <disco>:/data` | Los mismos comandos con `/mnt/lab3-data/app:/data` |
| 2.3 Abrir el puerto | `gcloud compute firewall-rules create` | Regla de ingreso del security group para TCP 8080 y una IPv4 `/32` |
| 2.4 Recrear el contenedor | `curl`, `docker rm`, `docker run`, `curl` | Los mismos comandos ejecutados mediante Systems Manager |
| 2.5 Recrear la VM | Borrar Compute Engine y crear otra con el disco existente | `terraform apply -replace=module.lab3.aws_instance.this`; el EBS conservó su identificador |
| 3.1 Elegir inferencia | Ollama o servidor propio con Transformers | Ollama `0.40.3` y `llama3.2:1b` fijados en variables |
| 3.2 Persistir pesos | Bind mount hacia `/root/.ollama` | `/mnt/lab3-data/ollama:/root/.ollama` sobre EBS |
| 3.3 Medir latencia | Diez `curl` a `/api/generate` | El mismo benchmark dentro de EC2, iniciado mediante Systems Manager |
| 3.4 CPU frente a GPU | Analizar modelo, latencia y carga | Análisis sobre `c7i-flex.large`, 2 vCPU, 4 GiB y las mediciones reales |
| 4.1 Limpiar | Borrar VM, disco y firewall con `gcloud` | Plan de destrucción guardado, `terraform apply destroy.plan` y verificación con Terraform y AWS CLI |

## Correspondencia con los ocho entregables

La guía contiene trece secciones de trabajo, pero solicita un único PDF con
ocho entregables numerados. La entrega conserva ese orden.

| Entregable | Secciones de la guía | Evidencia AWS incluida | Correspondencia formal |
| --- | --- | --- | --- |
| 1.1 | 1.1 a 1.3 | EC2, EBS, UUID, punto de montaje y línea de `fstab` | Captura real incluida |
| 2.1 | 2.1 a 2.3 | Respuestas de `/` y `/metrics` desde CloudShell | Captura real incluida |
| 2.2 | 2.4 | Contador 3 antes y 4 después de recrear el contenedor | Captura real incluida |
| 2.3 | 2.5 | Mismo EBS, contador 4 heredado y 5 tras consultar | Captura real incluida |
| 3.1 | 3.1 y 3.2 | Ollama 0.40.3, `llama3.2:1b` y 1.3 GiB en EBS | Captura real incluida |
| 3.2 | 3.3 | Diez latencias, mínimo, máximo, promedio y tipo de instancia | Captura y tabla incluidas |
| 3.3 | 3.4 | Tabla de decisión, latencia medida y conclusión CPU/GPU | Completo |
| 4.1 | 4.1 | Estado Terraform vacío y recursos AWS inexistentes | Captura real incluida |

### Desviaciones documentadas

- Las capturas solicitadas se obtuvieron durante una nueva ejecución real del
  laboratorio y se incorporaron al PDF junto a cada entregable.
- La guía recomienda `discard,defaults,nofail` en `fstab`. La implementación de
  AWS usa `defaults,x-systemd.device-timeout=10min` y el servicio depende de
  `RequiresMountsFor=/mnt/lab3-data`. Esta variante espera el EBS e impide que
  la aplicación arranque sin el volumen, para no escribir estado en el disco
  raíz por error.
- La guía guarda el código en el disco persistente. En AWS, cada EC2 recupera el
  código desde un commit fijado del repositorio; los datos del servicio y los
  pesos del modelo sí permanecen en EBS.
- El puerto 8080 se restringió a la IPv4 `/32` de CloudShell y el acceso
  administrativo se realizó con Session Manager. Estas medidas reemplazan la
  apertura `0.0.0.0/0` y el acceso por SSH del procedimiento original.

La verificación final confirmó `Status: Success` en Session Manager, ambos
chequeos de EC2 en `ok`, `/healthz` accesible desde fuera de la instancia y
`terraform plan -detailed-exitcode` sin cambios. El volumen EBS continuó siendo
el mismo durante el reemplazo controlado de EC2. No se publican credenciales ni
identificadores de cuenta. Los IDs operativos visibles en las capturas del
informe documentan la ejecución y no otorgan acceso a los recursos.

## Alcance y recursos

El entorno `terraform/aws/envs/lab3` reutiliza recursos que ya existen en la
cuenta:

- la VPC predeterminada;
- la subred predeterminada de `us-east-1a` (o de la zona configurada);
- la AMI vigente de Amazon Linux 2023 publicada en Parameter Store.

Terraform crea recursos propios del laboratorio:

- una instancia EC2 `c7i-flex.large`, elegible para el plan Free actual, con
  2 vCPU, 4 GiB de memoria, disco raíz cifrado de 16 GiB y eliminación
  al terminar la instancia;
- un volumen EBS `gp3` cifrado e independiente, de 10 GiB, más su asociación a
  EC2;
- un security group dedicado que publica solamente TCP `8080` para una IPv4
  `/32`;
- un rol y un perfil de instancia con
  `AmazonSSMManagedInstanceCore`, para entrar por Session Manager sin abrir
  SSH.

El arranque monta EBS en `/mnt/lab3-data`, construye `app:lab3`, inicia el
contenedor `servicio-patron` con `/mnt/lab3-data/app:/data` y ejecuta
`ollama/ollama:0.40.3` con el modelo `llama3.2:1b`. Ollama escucha solamente
en `127.0.0.1:11434` dentro de EC2.

> El laboratorio no crea una VPC nueva ni modifica el security group
> predeterminado. Sí crea su propio security group dentro de la VPC
> predeterminada.

## Prerrequisitos

- una cuenta AWS con permisos para consultar la VPC/subred/AMI y administrar
  EC2, EBS, IAM, security groups y Session Manager;
- AWS CLI autenticada (`aws sts get-caller-identity`);
- el plugin de Session Manager (`session-manager-plugin`);
- Bash, `curl`, `jq`, `make` y Terraform compatible con
  `>= 1.7, < 2.0`;
- acceso HTTPS a GitHub, al Registry de Docker y a los endpoints de AWS.

Para la validación real se instaló Terraform `1.16.5` de forma verificada en
`~/bin` de AWS CloudShell. Como CloudShell dispone de una cuota de 1 GiB, los
plugins y archivos temporales de inicialización se ubicaron fuera del espacio
persistente con:

```bash
export PATH="$HOME/bin:$PATH"
export TF_DATA_DIR=/tmp/lab3-tfdata-20261013-01
mkdir -p "$TF_DATA_DIR"
```

`TF_DATA_DIR` puede borrarse al terminar la sesión; el archivo de estado no
debe guardarse allí. El directorio de trabajo y `terraform.tfstate` deben
permanecer en el espacio persistente de CloudShell hasta finalizar y respaldar
el laboratorio.

Todos los comandos siguientes parten de la raíz del repositorio, salvo los
bloques que indican explícitamente que se ejecutan dentro de EC2.

## 1. Chequeos offline, sin crear recursos

Estos chequeos no necesitan credenciales ni consultan una cuenta AWS. El
primer `init` desactiva el backend; si el proveedor no está en caché, todavía
necesita acceso a Internet para descargarlo.

```bash
terraform fmt -recursive -check terraform/aws
terraform -chdir=terraform/aws/envs/lab3 init -backend=false -input=false
terraform -chdir=terraform/aws/envs/lab3 validate
terraform -chdir=terraform/aws/envs/lab3 test
```

El último comando usa el proveedor simulado definido en
`tests/lab3.tftest.hcl`: prueba defaults y rechaza CIDR abiertos, IPv6, redes
más amplias que `/32`, tamaños fraccionarios y puertos inválidos. El atajo
equivalente del repositorio es:

```bash
make tf-test-aws TF=terraform
```

## 2. Preparar un plan real

Primero confirmá la identidad y la región. Los valores predeterminados del
laboratorio son `us-east-1` y `us-east-1a`.

```bash
aws sts get-caller-identity
aws configure get region
```

Desde la raíz, entrá al entorno y derivá dos valores que no deben quedar
hardcodeados: la IPv4 pública de la máquina que ejecuta Terraform y el SHA
inmutable de `main` del repositorio que EC2 clonará.

```bash
cd terraform/aws/envs/lab3

PUBLIC_IPV4_RAW="$(curl -fsS --connect-timeout 5 --max-time 15 \
  https://checkip.amazonaws.com)" || {
  echo 'No se pudo obtener la IPv4 pública desde checkip.amazonaws.com.' >&2
  exit 1
}
PUBLIC_IPV4="$(printf '%s' "$PUBLIC_IPV4_RAW" | tr -d '[:space:]')"

if [[ ! "$PUBLIC_IPV4" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  printf 'checkip devolvió una IPv4 con formato inválido: %s\n' "$PUBLIC_IPV4" >&2
  exit 1
fi
IFS=. read -r OCTET_1 OCTET_2 OCTET_3 OCTET_4 <<< "$PUBLIC_IPV4"
for OCTET in "$OCTET_1" "$OCTET_2" "$OCTET_3" "$OCTET_4"; do
  if (( 10#$OCTET > 255 )); then
    printf 'checkip devolvió una IPv4 fuera de rango: %s\n' "$PUBLIC_IPV4" >&2
    exit 1
  fi
done

GITHUB_COMMIT_JSON="$(curl -fsSL --connect-timeout 5 --max-time 20 \
  https://api.github.com/repos/kathesama/infra-cloud-unlu-aguirre/commits/main)" || {
  echo 'No se pudo consultar el commit de main en la API de GitHub.' >&2
  exit 1
}
REPOSITORY_SHA="$(printf '%s' "$GITHUB_COMMIT_JSON" | jq -er '
  .sha | select(type == "string" and test("^[0-9a-f]{40}$"))
')" || {
  echo 'La API de GitHub no devolvió un SHA válido de 40 caracteres hexadecimales.' >&2
  exit 1
}

TF_VAR_allowed_cidr="${PUBLIC_IPV4}/32"
TF_VAR_repository_ref="$REPOSITORY_SHA"
export TF_VAR_allowed_cidr TF_VAR_repository_ref

printf 'allowed_cidr=%s\nrepository_ref=%s\n' \
  "$TF_VAR_allowed_cidr" "$TF_VAR_repository_ref"

terraform init -input=false
terraform plan -out=tfplan
terraform show -no-color tfplan | tee /tmp/lab3-plan.txt
```

El plan inicial del 13 de octubre de 2026 produjo `9 to add, 0 to change, 0 to
destroy` con Terraform `1.16.5` y el proveedor AWS `6.68.0`. Su `apply` creó
IAM, el security group y el EBS, pero la EC2 `t3.medium` fue rechazada por la
restricción del plan Free. Después de cambiar el valor predeterminado a
`c7i-flex.large`, el plan de continuación auditado produjo `2 to add, 1 to
change, 0 to destroy`: crea la EC2 y la asociación EBS, y actualiza sólo el
CIDR `/32` de ingreso a la IPv4 vigente de CloudShell. Ese plan se aplicó y
creó ambos recursos. Después se corrigió el montaje idempotente del volumen
(`wipefs -O TYPE`, con `O` mayúscula) y se aplicó un plan guardado que reemplazó
solamente EC2 y su asociación: `2 added, 0 changed, 2 destroyed`; el EBS
conservó el mismo identificador y contenido.

Revisá en `/tmp/lab3-plan.txt` la cuenta, región, zona, CIDR, SHA y cada alta. La
dirección `203.0.113.10/32` de `lab3.tfvars.example` pertenece al rango de
documentación RFC 5737: sirve para pruebas simuladas y **nunca** debe usarse
como valor vivo.

Si ejecutás `checkip.amazonaws.com` desde CloudShell, el `/32` obtenido permite
solamente el egreso de esa sesión de CloudShell. No habilita el navegador de tu
laptop y puede cambiar cuando abras otra sesión. Para probar `:8080` desde tu
equipo, generá el plan desde esa red o actualizá `TF_VAR_allowed_cidr` con la
IPv4 pública actual de tu equipo y volvé a planificar.

> `terraform plan` sólo calcula y guarda una propuesta: no crea recursos. El
> `apply` queda bloqueado hasta revisar `/tmp/lab3-plan.txt`, costos y permisos, y
> obtener la aprobación correspondiente. Recién entonces se ejecuta
> `terraform apply tfplan`; no lo ejecutes de forma automática.

### Estrategia obligatoria para el estado local

Este laboratorio usa estado local. `terraform.tfstate`, sus copias y sus
checksums **nunca se deben agregar al repositorio ni publicar**. El estado puede
contener identificadores, metadatos y otros datos sensibles, por lo que su
respaldo debe quedar en almacenamiento privado.

Antes del primer `apply`, verificá que trabajás en el directorio persistente de
CloudShell y que no estás guardando el estado bajo `/tmp`. Después de un
`apply` aprobado, y obligatoriamente antes de cualquier reemplazo o
destrucción, generá un snapshot actualizado:

```bash
terraform state pull > terraform.tfstate.backup
test -s terraform.tfstate.backup
jq -e '
  type == "object"
  and (.version | type == "number")
  and (.serial | type == "number")
' terraform.tfstate.backup >/dev/null
sha256sum terraform.tfstate.backup > terraform.tfstate.backup.sha256
sha256sum -c terraform.tfstate.backup.sha256
```

Descargá `terraform.tfstate.backup` y
`terraform.tfstate.backup.sha256` desde CloudShell a almacenamiento privado o
local, y verificá allí nuevamente el checksum. Después del primer `apply`, si
el snapshot no existe, no es JSON válido, no coincide con su checksum o no fue
descargado, **no continúes con un nuevo `apply`, reemplazo ni destrucción**. No
se propone un backend S3 porque crearía recursos adicionales fuera del alcance
autorizado.

## 3. Verificaciones posteriores a un apply aprobado

Después de un `apply` autorizado, guardá los outputs y esperá a que termine el
bootstrap. El 13 de octubre de 2026 estos comandos se ejecutaron correctamente;
se mantienen aquí como procedimiento reproducible.

```bash
export INSTANCE_ID="$(terraform output -raw instance_id)"
export PUBLIC_IP="$(terraform output -raw public_ip)"
export APP_URL="$(terraform output -raw app_url)"
export DATA_VOLUME_ID="$(terraform output -raw data_volume_id)"

terraform output
printf 'instance=%s\nip=%s\napp=%s\nebs=%s\n' \
  "$INSTANCE_ID" "$PUBLIC_IP" "$APP_URL" "$DATA_VOLUME_ID"

curl --retry 30 --retry-delay 5 --retry-all-errors -fsS "$APP_URL/healthz"
curl -fsS "$APP_URL/"
curl -fsS "$APP_URL/metrics" | grep '^servicio_patron_'
```

El endpoint raíz incrementa un contador persistente, por lo que su número
cambia en cada consulta.

### Session Manager y log de arranque

Terraform expone los comandos listos para copiar:

```bash
terraform output -raw ssm_start_session
printf '\n'
terraform output -raw bootstrap_log_command
printf '\n'
```

El primero abre una terminal sin SSH. Dentro de esa sesión EC2, inspeccioná el
log, el marcador final y el montaje:

```bash
sudo tail -n 200 /var/log/lab3-bootstrap.log
sudo cat /mnt/lab3-data/bootstrap-complete
findmnt /mnt/lab3-data
sudo docker ps
```

No des por terminado el bootstrap hasta ver `Lab 3 bootstrap completed` en el
log y el archivo `bootstrap-complete` con el SHA esperado.

### Resultado verificado del despliegue

- el marcador de bootstrap existe y el servicio Docker está `active`;
- los contenedores `servicio-patron` y `ollama` están en estado `running`;
- `/healthz` devolvió `{"status":"ok"}` tanto dentro como fuera de EC2;
- `/` incrementó el contador persistido y `/metrics` expuso
  `servicio_patron_hits_total`;
- `llama3.2:1b` figura en Ollama con aproximadamente 1,3 GB;
- el volumen de datos está montado como `ext4` en `/mnt/lab3-data` mediante
  UUID;
- los chequeos de sistema e instancia de EC2 devolvieron `ok`;
- el plan final de Terraform devolvió `NO_CHANGES`.

El respaldo privado final del estado es
`lab3-state-backup-20261013-final.tar.gz`, con SHA-256
`1CF44CE467A2AF82007E88F8F68E0A39FF942B51BAD05D7D499E6240A118BE53`.

## 4. Evidencia de persistencia del contenedor

Ejecutá este bloque dentro de EC2 por Session Manager. Primero generá estado y
registrá la evidencia previa:

```bash
APP_PORT_MAPPING="$(sudo docker port servicio-patron 8080/tcp)" || {
  echo 'No se pudo leer el puerto publicado de servicio-patron.' >&2
  exit 1
}
APP_PORT="$(printf '%s\n' "$APP_PORT_MAPPING" | awk -F: 'NR == 1 { print $NF }')"
if [[ ! "$APP_PORT" =~ ^[0-9]+$ ]] || (( APP_PORT < 1 || APP_PORT > 65535 )); then
  printf 'Mapeo de puerto inválido para servicio-patron: %s\n' \
    "$APP_PORT_MAPPING" >&2
  exit 1
fi

printf 'Puerto publicado detectado: %s\n' "$APP_PORT"
curl -fsS "http://127.0.0.1:${APP_PORT}/"
curl -fsS -X POST "http://127.0.0.1:${APP_PORT}/items" \
  -H 'content-type: application/json' \
  -d '{"name":"evidencia-lab3","value":"persistente-en-ebs"}'
curl -fsS "http://127.0.0.1:${APP_PORT}/items"
sudo docker exec ollama ollama list
sudo docker inspect servicio-patron \
  --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

Sin cerrar esa sesión (para conservar `APP_PORT`), eliminá **sólo** el
contenedor y recrealo con el mismo bind mount de EBS que usa el bootstrap:

```bash
sudo docker rm -f servicio-patron
sudo docker run -d \
  --name servicio-patron \
  --restart unless-stopped \
  -p "${APP_PORT}:8080" \
  -e DATA_DIR=/data \
  -v /mnt/lab3-data/app:/data \
  app:lab3

READY=0
for ATTEMPT in $(seq 1 60); do
  if curl --connect-timeout 2 --max-time 5 -fsS \
    "http://127.0.0.1:${APP_PORT}/healthz" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 2
done
if (( READY != 1 )); then
  printf 'servicio-patron no quedó listo después de 60 intentos.\n' >&2
  sudo docker logs --tail 200 servicio-patron >&2
  exit 1
fi

curl -fsS "http://127.0.0.1:${APP_PORT}/"
curl -fsS "http://127.0.0.1:${APP_PORT}/items"
sudo docker exec ollama ollama list
curl -fsS http://127.0.0.1:11434/api/tags
```

La evidencia válida muestra que el contador continúa, el item sigue en la
lista y `llama3.2:1b` permanece en la lista de modelos. Reiniciar sólo
`servicio-patron` no prueba por sí mismo la persistencia de Ollama; la lista se
registra para completar la evidencia del contenido almacenado en el mismo EBS.

## 5. Plan de reemplazo de EC2 sin reemplazar EBS

Volvé a la terminal donde está el directorio
`terraform/aws/envs/lab3`. Antes de generar el plan, repetí el snapshot de
estado, su validación JSON, el checksum y su descarga privada según la sección
anterior. Guardá luego el ID del volumen como evidencia:

```bash
export DATA_VOLUME_ID_BEFORE="$(terraform output -raw data_volume_id)"
printf '%s\n' "$DATA_VOLUME_ID_BEFORE" | tee /tmp/lab3-data-volume-id.txt

terraform plan \
  -replace='module.lab3.aws_instance.this' \
  -out=replace-ec2.plan
terraform show -no-color replace-ec2.plan | tee /tmp/lab3-replace.txt
terraform show -json replace-ec2.plan > /tmp/lab3-replace.json

jq -r '.resource_changes[]
  | select(.address == "module.lab3.aws_instance.this"
        or .address == "module.lab3.aws_ebs_volume.data")
  | [.address, (.change.actions | join(",")),
     (.change.before.id // "-"), (.change.after.id // "-")]
  | @tsv' /tmp/lab3-replace.json

jq -e --arg volume_id "$DATA_VOLUME_ID_BEFORE" '
  .resource_changes[]
  | select(.address == "module.lab3.aws_ebs_volume.data")
  | ((.change.actions == ["no-op"])
     and (.change.before.id == $volume_id)
     and (.change.after.id == $volume_id))
' /tmp/lab3-replace.json
```

El plan debe reemplazar `module.lab3.aws_instance.this` y su asociación, pero
debe mostrar el EBS `module.lab3.aws_ebs_volume.data` como `no-op`, con el mismo
ID antes y después. **No apliques `replace-ec2.plan` antes de conservar esta
evidencia y someterla a revisión.** El reemplazo cambia la IP pública y provoca
indisponibilidad mientras arranca la nueva EC2.

### Resultados verificados de persistencia

El 13 de octubre de 2026 se completaron las dos pruebas destructivas previstas:

- Antes de eliminar `servicio-patron`, el archivo contenía **2** y la consulta
  previa produjo **3**. Tras recrear el contenedor con el mismo bind mount, la
  primera consulta continuó la secuencia en **4**.
- Se ejecutó `terraform apply -replace=module.lab3.aws_instance.this`: **2
  recursos agregados, 0 modificados y 2 destruidos**. El volumen EBS conservó
  el mismo identificador.
- En la EC2 nueva, antes de consultar el servicio, el contador seguía en **4**;
  la primera consulta devolvió **5**. El modelo `llama3.2:1b` también continuó
  disponible en `/mnt/lab3-data/ollama`.
- La verificación posterior de Terraform informó **sin cambios**, confirmando
  que la infraestructura quedó nuevamente alineada con la configuración.

## 6. Medición de Ollama sobre CPU

El tipo `c7i-flex.large` de este laboratorio no aporta GPU. Dentro de EC2, instalá
la utilidad GNU `time` si `/usr/bin/time` no existe:

```bash
sudo test -x /usr/bin/time || sudo dnf install -y time
```

Abrí dos sesiones de Session Manager. En la primera observá CPU y memoria del
contenedor durante la generación:

```bash
sudo docker stats ollama
```

En la segunda medí tiempo transcurrido y recursos del comando cliente:

```bash
/usr/bin/time -v sudo docker exec ollama \
  ollama run llama3.2:1b \
  'Explicá en tres oraciones qué demuestra separar EC2 de un volumen EBS.'
sudo docker stats --no-stream ollama
```

Detené el muestreo continuo con `Ctrl+C` y guardá ambas salidas. `/usr/bin/time`
mide el proceso que invoca `docker exec`; el consumo real del contenedor se
observa con `docker stats`. No presentes una medición como benchmark de GPU ni
como comparación de modelos.

### Resultado medido

El 13 de octubre de 2026 se ejecutaron diez solicitudes secuenciales contra
`/api/generate`, con `llama3.2:1b`, el mismo prompt y `stream=false`. El EBS
contenía 1,3 GiB bajo `/mnt/lab3-data/ollama`. Las latencias totales fueron:

```text
8.442191  0.232012  0.218148  0.217723  0.221695
0.218382  0.219124  0.219240  0.222190  0.244189
```

El mínimo fue **0,218 s**, el máximo **8,442 s** y el promedio global **1,045 s**.
Las nueve solicitudes calientes promediaron **0,224 s**; la primera fue unas
37,8 veces más lenta por el calentamiento inicial. Para el
modelo 1B y el uso esporádico de este laboratorio, CPU es suficiente; una GPU
se evaluaría para modelos mayores, concurrencia sostenida, streaming fluido o
un SLA de latencia más exigente.

## 7. Limpieza controlada

Conservá antes los logs, respuestas HTTP, IDs, planes y mediciones. Repetí
también `terraform state pull > terraform.tfstate.backup`, validá el JSON y el
checksum, y descargá ambos archivos a almacenamiento privado. Sin ese respaldo
actualizado no continúes. Después generá y revisá un plan de destrucción
separado:

```bash
terraform plan -destroy -out=destroy.plan
terraform show -no-color destroy.plan | tee /tmp/lab3-destroy.txt
```

> **Advertencia:** `terraform destroy` también elimina el volumen EBS
> independiente y, con él, el contador, los items y los modelos descargados.
> Que el volumen sobreviva al reemplazo de EC2 no significa que sobreviva a la
> destrucción del stack. No continúes hasta haber respaldado toda la evidencia
> necesaria y revisar `/tmp/lab3-destroy.txt`.

Sólo después de esa revisión y de una aprobación explícita, aplicá exactamente
el plan guardado:

```bash
terraform apply destroy.plan
```

No reutilices `replace-ec2.plan` ni generes un `apply` sin archivo de plan durante
la limpieza.

### Resultado de la limpieza

La limpieza se completó el 13 de octubre de 2026 aplicando el plan guardado que
había sido revisado. Terraform informó **0 recursos agregados, 0
modificados y 9 destruidos**. La comprobación posterior confirmó:

- estado de Terraform con **0 recursos**;
- plan de destrucción sin cambios (`detailed-exitcode = 0`);
- instancia EC2 en estado `terminated`;
- volumen EBS inexistente (`InvalidVolume.NotFound`);
- grupo de seguridad inexistente (`InvalidGroup.NotFound`);
- rol y perfil IAM inexistentes (`NoSuchEntity`).

Las evidencias funcionales y las capturas requeridas se conservaron antes de
la destrucción. Los archivos de estado de Terraform no forman parte de la
entrega y no deben publicarse porque pueden contener información sensible.
