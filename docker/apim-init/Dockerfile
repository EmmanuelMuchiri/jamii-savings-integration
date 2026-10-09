# One-shot publisher: waits for API Manager, then runs scripts/apim-bootstrap.sh
# (tier, APIs, API Product, demo app) and scripts/gateway-check.sh.
# Contains curl, jq, bash and apictl, so nothing needs installing on the host.
FROM alpine:3.20
ARG APICTL_VERSION=4.4.1
ARG TARGETARCH
RUN apk add --no-cache bash curl jq ca-certificates tar \
 && ARCH="${TARGETARCH:-amd64}" \
 && URL="https://github.com/wso2/product-apim-tooling/releases/download/v${APICTL_VERSION}/apictl-${APICTL_VERSION}-linux-${ARCH}.tar.gz" \
 && echo "apim-init: downloading $URL" \
 && curl -fsSL "$URL" -o /tmp/apictl.tgz \
 && tar -xzf /tmp/apictl.tgz -C /tmp \
 && mv /tmp/apictl/apictl /usr/local/bin/apictl && chmod +x /usr/local/bin/apictl \
 && rm -rf /tmp/apictl /tmp/apictl.tgz \
 && apictl version
WORKDIR /work
ENTRYPOINT ["bash", "-c"]
CMD ["scripts/apim-bootstrap.sh dev && if [ \"${RUN_GATEWAY_CHECK:-true}\" = true ]; then GATEWAY_URL_OVERRIDE=$GATEWAY_URL TOKEN_URL_OVERRIDE=$APIM_URL/oauth2/token scripts/gateway-check.sh; fi"]
