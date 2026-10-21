# Lab Clase 2 IaC con Terraform sobre GCP

**Estudiante:** Katherine Aguirre  
**Proyecto GCP:** `unlu-ia-aguirre` (`project-d9126d04-1cca-424d-8dc`)  
**Región y zona:** `us-central1` y `us-central1-a`  
**Fecha:** 20 de octubre de 2026

## Resultado

El laboratorio se ejecutó completo sobre GCP. Terraform administró el servicio patrón y el servidor de inferencia Iris incluido en el repositorio oficial. También se demostró la detección de drift y se destruyeron los recursos de cómputo. La verificación final dio cero VMs, discos, redes, repositorios de imágenes y cuentas de servicio de la carga.

## 1.1 Backend remoto y estructura

- Bucket: `gs://project-d9126d04-1cca-424d-8dc-tfstate`.
- Acceso uniforme y versionado habilitados.
- Estado dev: `infra-cloud-template/dev`.
- Estado Iris: `infra-cloud-template/ia-artefacto`.
- Módulos reutilizados: `network`, `vm` y `artifact-registry`.
- Terraform 1.16.6 y provider Google 5.45.2.
- Ambas configuraciones pasaron `terraform validate`.

## 2.1 Apply del entorno base

El plan del entorno dev declaró siete recursos y el apply terminó correctamente:

```text
Plan: 7 to add, 0 to change, 0 to destroy.
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.
vm_external_ip = "34.171.90.36"
vm_url = "http://34.171.90.36:8080/"
```

Artifact Registry se había creado antes con un apply dirigido y luego quedó administrado por el estado dev.

## 2.2 Servicio patrón

Dos solicitudes consecutivas incrementaron el contador y la métrica coincidió:

```text
{"message":"servicio-patron","hits":1}
{"message":"servicio-patron","hits":2}
servicio_patron_hits_total 2.0
```

## 3.1 Detección y corrección de drift

Se cambió fuera de Terraform el rango de origen de `infra-cloud-dev-allow-app` a `203.0.113.0/24`. El plan detectó exactamente un cambio y propuso restaurar `0.0.0.0/0`:

```text
~ source_ranges = [
  - "203.0.113.0/24",
  + "0.0.0.0/0",
]
Plan: 0 to add, 1 to change, 0 to destroy.
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

## 4.1 Servidor de inferencia Iris en CPU

La imagen `model:v1` se construyó con Cloud Build y quedó en Artifact Registry. El entorno creó nueve recursos:

```text
Plan: 9 to add, 0 to change, 0 to destroy.
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.
ia_service_account_email = "ia-artefacto@project-d9126d04-1cca-424d-8dc.iam.gserviceaccount.com"
vm_external_ip = "35.223.14.110"
vm_url = "http://35.223.14.110:8081/"
```

La VM fue una `e2-small` Spot. La carga usó CPU porque la regresión logística de Iris es pequeña y una GPU no aportaría una mejora útil para el costo y el tiempo de inicialización. La cuenta de servicio dedicada recibió únicamente `roles/artifactregistry.reader`. El disco de datos persistente fue de 20 GB.

La inferencia real respondió:

```text
$ curl -fsS -X POST http://35.223.14.110:8081/predict \
  -H 'Content-Type: application/json' \
  -d '{"features":[5.1,3.5,1.4,0.2]}'
{"class":"setosa","confidence":0.9815563095631855}

$ curl -fsS http://35.223.14.110:8081/metrics | grep model_predictions_total
model_predictions_total 1.0
```

Un plan posterior terminó con `No changes` y código 0.

## 5.1 Cleanup

Se destruyó primero `ia-artefacto` y después `dev`. Una llamada de la API de Compute rechazó transitoriamente la conexión durante el primer destroy. El reintento idempotente eliminó los dos recursos pendientes.

La verificación final confirmó:

```text
terraform state list (ia-artefacto): <empty>
terraform state list (dev): <empty>
VMs: 0
discos: 0
redes: 0
repositorios de Artifact Registry: 0
cuentas de servicio ia-artefacto: 0
```

El bucket de estado permanece intencionalmente con versionado y conserva los dos archivos de estado vacíos como evidencia de auditoría.

## Incidencias resueltas

- Cloud Build rechazó el `COPY` del Dockerfile porque varios archivos requerían un destino terminado en `/`. Se cambió el destino a `./` y el build terminó en `SUCCESS`.
- La imagen Debian de la VM no incluía `gcloud`. El startup script pasó a obtener un token OAuth del metadata server y a usar `docker login`.
- El destroy de Iris tuvo un error transitorio de red. El reintento administrado por Terraform completó la limpieza.

## Evidencia

El paquete `lab-clase2-evidence.tar.gz` contiene los logs completos de Cloud Shell. SHA-256:

```text
A0F3FEAF10EDD451F9628426410230B95E95FC321BD1D8DEFB0B28B954A7D804
```
