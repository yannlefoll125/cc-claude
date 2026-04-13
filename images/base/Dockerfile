FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    gosu \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH="/root/.local/bin:$PATH"

WORKDIR /workspace

COPY cc-wrapper.sh /cc-wrapper.sh
RUN chmod +x /cc-wrapper.sh

ENTRYPOINT ["/cc-wrapper.sh"]