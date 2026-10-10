# syntax=docker/dockerfile:1
# One-shot publisher: waits for API Manager, then runs scripts/apim-bootstrap.sh
# (tier, APIs, API Product, demo app) and scripts/gateway-check.sh.
# Contains curl, jq, bash and apictl, so nothing needs installing on the host.
#
# apictl source: dist/apictl-<version>-linux-<arch>.tar.gz if present (offline builds),
# otherwise downloaded from the WSO2 GitHub releases.
FROM alpine:3.20
ARG APICTL_VERSION=4.4.1
ARG TARGETARCH
RUN apk add --no-cache bash curl jq ca-certificates tar
RUN --mount=type=bind,from=dist,target=/dist \
    ARCH="${TARGETARCH:-amd64}"; FILE="apictl-${APICTL_VERSION}-linux-${ARCH}.tar.gz"; \
    if [ -f "/dist/$FILE" ]; then echo "apim-init: using dist/$FILE"; cp "/dist/$FILE" /tmp/apictl.tgz; \
    else URL="https://github.com/wso2/product-apim-tooling/releases/download/v${APICTL_VERSION}/$FILE"; \
         echo "apim-init: dist/$FILE not found, downloading $URL"; curl -fsSL "$URL" -o /tmp/apictl.tgz; fi \
 && tar -xzf /tmp/apictl.tgz -C /tmp \
 && mv /tmp/apictl/apictl /usr/local/bin/apictl && chmod +x /usr/local/bin/apictl \
 && rm -rf /tmp/apictl /tmp/apictl.tgz \
 && apictl version
WORKDIR /work
ENTRYPOINT ["bash", "-c"]
CMD ["bash scripts/apim-bootstrap.sh dev && if [ \"${RUN_GATEWAY_CHECK:-true}\" = true ]; then GATEWAY_URL_OVERRIDE=$GATEWAY_URL TOKEN_URL_OVERRIDE=$APIM_URL/oauth2/token bash scripts/gateway-check.sh; fi"]
