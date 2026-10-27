# Ollama CPU - Lab Clase 3

La imagen contiene sólo el runtime Ollama fijado en `0.40.3`. Los pesos de
`llama3.2:1b` se descargan y persisten en un volumen montado en
`/root/.ollama`; no se hornean dentro de la imagen.

```bash
docker build -t ollama:local ./ollama
docker run -d --name ollama-lab -p 11434:11434 \
  -v ollama-models:/root/.ollama ollama:local
docker exec ollama-lab ollama pull llama3.2:1b
```
