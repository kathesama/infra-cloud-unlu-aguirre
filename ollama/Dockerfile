# Runtime used by the Class 1 CPU inference workload.
# Model weights are deliberately excluded from the image and mounted at
# /root/.ollama so that they persist and can be versioned independently.
FROM ollama/ollama:0.40.3

LABEL org.opencontainers.image.title="UNLu Ollama CPU inference" \
      org.opencontainers.image.description="Ollama runtime without baked model weights"

ENV OLLAMA_HOST=0.0.0.0:11434

EXPOSE 11434

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=12 \
  CMD ["/bin/ollama", "list"]

ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
