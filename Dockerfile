# Setup build arguments with default versions
ARG AWS_CLI_VERSION=1.19.84
ARG TERRAFORM_VERSION=0.15.4
ARG DEBIAN_VERSION=stable-20210511-slim

# Download Terraform binary
FROM debian:${DEBIAN_VERSION} as terraform
ARG TERRAFORM_VERSION
RUN apt-get update
RUN apt-get install --no-install-recommends -y curl
RUN apt-get install --no-install-recommends -y ca-certificates
RUN apt-get install --no-install-recommends -y unzip
RUN apt-get install --no-install-recommends -y gnupg
RUN apt-get install -y gettext-base
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig
COPY hashicorp.asc hashicorp.asc
RUN gpg --import hashicorp.asc
RUN gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN grep terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS | sha256sum -c -
RUN unzip -j terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install AWS CLI using PIP
FROM debian:${DEBIAN_VERSION} as aws-cli
ARG AWS_CLI_VERSION
ARG PYTHON_MAJOR_VERSION
RUN apt-get update
RUN apt-get install -y --no-install-recommends python3
RUN apt-get install -y --no-install-recommends python3-pip
RUN pip3 install setuptools
RUN pip3 install awscli==${AWS_CLI_VERSION}

# Build final image
FROM debian:${DEBIAN_VERSION}
LABEL maintainer="camcam42@github"
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    jq \
    python3 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 1
COPY --from=terraform /terraform /usr/local/bin/terraform
COPY --from=aws-cli /usr/local/bin/aws* /usr/local/bin/
COPY --from=aws-cli /usr/local/lib/python3.7/dist-packages /usr/local/lib/python3.7/dist-packages
COPY --from=aws-cli /usr/lib/python3/dist-packages /usr/lib/python3/dist-packages

WORKDIR /workspace
RUN groupadd --gid 1001 nonroot \
  # user needs a home folder to store aws credentials
  && useradd --gid nonroot --create-home --uid 1001 nonroot \
  && chown nonroot:nonroot /workspace
USER nonroot

CMD ["bash"]