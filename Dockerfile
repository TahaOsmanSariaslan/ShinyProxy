FROM ubuntu:22.04

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    git \
    bash \
    sudo \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy setup script and kustomize directory
COPY setup.sh /usr/local/bin/setup.sh
COPY shinyproxy/ ./shinyproxy/
COPY .env .env
# Set permissions
RUN chmod +x /usr/local/bin/setup.sh

ENV ARCH=${ARCH}

CMD ["/usr/local/bin/setup.sh"]
