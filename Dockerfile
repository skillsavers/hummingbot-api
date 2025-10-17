# Stage 1: Builder stage
FROM continuumio/miniconda3 AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y python3-dev gcc && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy only the environment file first (for better layer caching)
COPY environment.yml .

# Create the conda environment
RUN conda env create -f environment.yml && \
    conda clean -afy && \
    rm -rf /root/.cache/pip/*

# Stage 2: Runtime stage
FROM continuumio/miniconda3

# Build arguments (for CI/CD and versioning)
ARG VERSION="dev"
ARG VCS_REF=""
ARG BUILD_DATE=""

# OCI Standard Labels
LABEL org.opencontainers.image.title="Hummingbot API"
LABEL org.opencontainers.image.description="FastAPI backend for Hummingbot bot orchestration"
LABEL org.opencontainers.image.vendor="Skillsavers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.source="https://github.com/skillsavers/hummingbot-api"

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libusb-1.0-0 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the conda environment from builder
COPY --from=builder /opt/conda/envs/hummingbot-api /opt/conda/envs/hummingbot-api

# Set the working directory
WORKDIR /hummingbot-api

# Copy only necessary application files
COPY main.py config.py deps.py ./
COPY models ./models
COPY routers ./routers
COPY services ./services
COPY utils ./utils
COPY database ./database
COPY bots/controllers ./bots/controllers
COPY bots/scripts ./bots/scripts

# Create necessary directories
RUN mkdir -p bots/instances bots/conf bots/credentials bots/data bots/archived

# Expose port
EXPOSE 8000

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Set environment variables to ensure conda env is used
ENV PATH="/opt/conda/envs/hummingbot-api/bin:$PATH"
ENV CONDA_DEFAULT_ENV=hummingbot-api
ENV VERSION=${VERSION}

# Run the application
ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
