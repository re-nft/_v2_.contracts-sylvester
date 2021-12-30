FROM python:3.9.6-slim-buster as requirements

RUN mkdir /registry && \
    apt-get update && \
    apt-get install -y linux-headers-amd64 gcc && \
    rm -rf /var/lib/apt/lists/*

RUN pip install poetry

COPY / /registry
WORKDIR /registry

RUN poetry export -f requirements.txt --dev --without-hashes -o /tmp/requirements.txt

FROM python:3.9.6-slim-buster

RUN mkdir /registry \
    && apt-get update \
    && apt-get install -y curl linux-headers-amd64 gcc \
    && rm -rf /var/lib/apt/lists/*

COPY / /registry
WORKDIR /registry

COPY --from=requirements /tmp/requirements.txt .

RUN pip install -r requirements.txt \
    && brownie pm install OpenZeppelin/openzeppelin-contracts@4.3.0

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g ganache-cli

RUN brownie compile --all

CMD ["/usr/local/bin/brownie","test"]
