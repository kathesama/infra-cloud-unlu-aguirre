# Lab Clase 2 en GCP: diseño de Terraform e inferencia Iris

Fecha: 2026-10-19  
Estado: aprobado

## Objetivo

Completar el Lab 1 de la Clase 2 sobre GCP con la infraestructura declarada en
Terraform, estado remoto en GCS, detección de drift y un segundo entorno para
el servidor de inferencia Iris ejecutado en CPU. La entrega debe incluir los
cinco entregables solicitados, evidencias reales con el comando completo y su
salida, el código del entorno `ia-artefacto` y una limpieza verificable.

## Contexto confirmado

- Proyecto GCP: `project-d9126d04-1cca-424d-8dc`.
- Nombre visible aprobado: `unlu-ia-aguirre`. El ID técnico del proyecto es
  inmutable y seguirá siendo el valor usado por `gcloud` y Terraform.
- Región del curso: `us-central1`.
- Zona del curso: `us-central1-a`.
- La cuenta muestra la prueba gratuita activa, USD 0 de 300 consumidos al
  inicio del trabajo y vencimiento el 18 de enero de 2027.
- Repositorio de trabajo:
  `D:\projects\diplomado\infra-cloud-unlu-aguirre`.
- El repositorio ya contiene los módulos GCP oficiales, el servicio patrón,
  el servidor Iris y la implementación anterior del Lab 3 en AWS.
- Windows no tiene instalados `gcloud`, Terraform ni OpenTofu. La ejecución
  autenticada se realizará en Google Cloud Shell, sin instalar herramientas
  adicionales en el equipo.
- No se crearán commits ni pull requests.

## Decisiones de alcance

La implementación seguirá la guía de GCP sin traducir recursos a AWS. La Parte
4 utilizará `model/`, el servidor de inferencia Iris oficial, en CPU y puerto
8081. No se desplegarán GPU, GKE, Ollama ni componentes reales de Juana en este
laboratorio.

El proyecto recién creado se reutilizará como proyecto exclusivo del curso. No
se creará otro proyecto. Su nombre visible se cambiará de `My First Project` a
`unlu-ia-aguirre`; el ID `project-d9126d04-1cca-424d-8dc` permanecerá sin
cambios. Las configuraciones específicas del proyecto y los archivos
generados por Terraform permanecerán fuera del control de versiones.

## Arquitectura

### Estado remoto

Un bucket GCS globalmente único, `${PROJECT_ID}-tfstate`, almacenará el estado
remoto. Tendrá acceso uniforme a nivel de bucket y versionado habilitado. Cada
entorno utilizará un prefijo distinto:

- `infra-cloud-template/dev` para el servicio patrón;
- `infra-cloud-template/ia-artefacto` para Iris.

No se aceptará una migración de estado entre los dos prefijos. El bucket se
conservará después del cleanup porque contiene la evidencia operativa del
curso y puede reutilizarse en las clases siguientes.

### Entorno dev

`terraform/envs/dev` combinará los módulos oficiales:

- `network`: VPC, subred y reglas de firewall;
- `artifact-registry`: repositorio Docker `infra-cloud-template`;
- `vm`: VM Spot `e2-small`, disco persistente y servicio patrón en el puerto
  8080.

El despliegue se hará en tres pasos: crear primero Artifact Registry mediante
un plan dirigido, construir `app:v1` con Cloud Build y aplicar después el plan
completo de red y VM. El servicio se validará mediante `/`, `/healthz` y
`/metrics`.

### Entorno ia-artefacto

`terraform/envs/ia-artefacto` será independiente de `dev` y reutilizará los
módulos oficiales sin compartir estado ni nombres de recursos. Tendrá:

- prefijo de recursos `infra-cloud-ia`;
- VM Spot en CPU;
- imagen `model:v1` construida desde `model/`;
- puerto 8081;
- disco persistente de 20 GB;
- Artifact Registry deshabilitado en este entorno porque lo crea `dev`;
- service account `ia-artefacto` dedicada;
- rol `roles/artifactregistry.reader` como permiso mínimo para descargar la
  imagen privada;
- dependencia explícita entre el permiso y el arranque de la VM.

Iris entrena el modelo durante la construcción de la imagen y lo carga una vez
al iniciar el servidor. La validación real incluirá `/healthz`, `/`,
`/metrics` y `POST /predict` con las cuatro características de una flor Iris.

## Flujo de ejecución

1. Verificar identidad, proyecto activo, crédito, versiones y ausencia de
   recursos previos con los nombres del laboratorio; cambiar el nombre visible
   del proyecto a `unlu-ia-aguirre` y registrar el comando y su verificación.
2. Preparar en Cloud Shell una copia de este repositorio y comprobar formato,
   validación y pruebas del modelo sin crear infraestructura.
3. Crear y versionar el bucket del estado remoto.
4. Crear `dev.tfvars` con el proyecto, región, zona e imagen `app:v1`.
5. Inicializar el backend de `dev` y validar Terraform.
6. Generar y revisar el plan dirigido de Artifact Registry antes de aplicarlo.
7. Publicar `app:v1` con Cloud Build.
8. Generar, revisar y aplicar el plan completo de `dev`.
9. Validar el servicio patrón y conservar la evidencia 2.1.
10. Modificar manualmente el rango de origen de la regla de aplicación,
    ejecutar `terraform plan`, conservar la evidencia del drift y restaurar el
    valor declarado mediante Terraform.
11. Crear `envs/ia-artefacto` sin copiar `.terraform`, locks ni planes de
    `dev`, y agregar la service account de mínimo privilegio.
12. Probar y publicar `model:v1`.
13. Inicializar el backend independiente y comprobar que el plan de Iris sólo
    contiene altas, sin reemplazos ni destrucciones de `dev`.
14. Aplicar el plan de Iris y validar salud, descripción, predicción y
    métricas.
15. Conservar el código y todas las evidencias antes de limpiar.
16. Destruir primero `ia-artefacto` y después `dev`, usando los mismos archivos
    de variables de cada entorno.
17. Verificar que no queden VMs ni discos y que el bucket del estado continúe
    disponible.

## Política de planes y costo

Ningún `terraform apply` se ejecutará sin un archivo de plan guardado y
revisado. Antes del primer apply que genere consumo se presentarán la cantidad
de recursos a crear, cambiar o destruir y los recursos con costo directo. El
uso será CPU-only y Spot. Las VMs y discos se conservarán sólo el tiempo
necesario para producir la evidencia.

Cloud Build, Artifact Registry, GCS, las IP públicas, las VMs y los discos
pueden consumir crédito. El saldo de la prueba se comprobará antes y después
del laboratorio. Una alerta de presupuesto, si se configura, se documentará
como aviso y no como límite de gasto.

## Evidencias

Las capturas se obtendrán desde Cloud Shell y mostrarán el prompt, el comando
completo y su salida. No se usarán capturas recortadas que oculten cómo se
produjo el resultado. Además, cada bloque relevante conservará un transcript
de texto para poder comprobar cifras y evitar errores de transcripción.

Se recopilarán como mínimo:

1. **Entregable 1.1:** árbol de `terraform/` con los módulos `network` y `vm`.
2. **Entregable 2.1:** `terraform apply` completo, resumen final, outputs y
   respuestas del servicio patrón.
3. **Entregable 3.1:** comando que modifica el firewall, estado modificado y
   plan que detecta el drift.
4. **Entregable 4.1:** código de `ia-artefacto`, apply exitoso, `/healthz`, una
   predicción Iris completa y justificación de CPU, disco y service account.
5. **Entregable 5.1:** destrucción de ambos entornos y consultas finales que
   demuestren que no quedan VMs ni discos.

El correo, la cuenta de facturación y cualquier dato de pago se ocultarán. El
ID del proyecto y los nombres de los recursos se conservarán cuando sean parte
de la evidencia técnica, porque no son credenciales. Nunca se capturarán ni se
guardarán contraseñas, códigos de verificación, tokens o claves JSON.

## Archivos

Se mantendrán los módulos oficiales y el trabajo AWS existente. Los cambios se
limitan a:

```text
terraform/envs/dev/dev.tfvars                         # local, ignorado
terraform/envs/ia-artefacto/backend.tf
terraform/envs/ia-artefacto/main.tf
terraform/envs/ia-artefacto/outputs.tf
terraform/envs/ia-artefacto/variables.tf
terraform/envs/ia-artefacto/ia.tfvars.example
terraform/envs/ia-artefacto/ia.tfvars                # local, ignorado
docs/lab-clase-2-gcp.md
docs/entrega/Lab-Clase-2-Terraform-GCP-Katherine-Aguirre.docx
docs/entrega/Lab-Clase-2-Terraform-GCP-Katherine-Aguirre.pdf
```

Los directorios `.terraform`, los locks copiados desde otro entorno, los
archivos `*.plan`, los estados y sus respaldos no formarán parte de la
entrega. Después de eliminar el lock heredado de `dev`, el lock que genere
desde cero la inicialización de `ia-artefacto` sí podrá conservarse como parte
del código reproducible; no contiene el estado ni la configuración remota.

## Manejo de fallos

- Si una API no está habilitada, se registrará el error y se habilitará sólo
  la API requerida.
- Si IAM todavía no propagó el permiso de Artifact Registry, se esperará y se
  reiniciará únicamente la VM afectada.
- Si una VM Spot queda detenida, se iniciará de nuevo y se actualizarán los
  outputs antes de validar el servicio.
- Si el backend informa un cambio de configuración, no se migrará el estado:
  se eliminará la inicialización local del entorno nuevo y se repetirá el
  `init` con `-reconfigure`.
- Si un plan de `ia-artefacto` propone modificar o destruir recursos de
  `dev`, se detendrá la ejecución y se corregirán el prefijo y los nombres.
- Si el servicio no responde, se conservarán `journalctl`, `docker ps -a` y
  los logs del contenedor antes de reiniciar o reemplazar recursos.

## Criterios de aceptación

El laboratorio queda completo cuando:

- el estado remoto está versionado y separado por entorno;
- el servicio patrón responde y expone métricas;
- Terraform detecta y revierte el drift;
- Iris responde en CPU con una predicción válida y métricas;
- la service account de Iris tiene solamente el permiso necesario para leer
  Artifact Registry;
- los cinco entregables contienen comandos y resultados verificables;
- el PDF y el DOCX final están ordenados y revisados visualmente;
- la limpieza elimina VMs y discos sin borrar el bucket del estado;
- no se exponen credenciales ni se altera el trabajo AWS previo.
