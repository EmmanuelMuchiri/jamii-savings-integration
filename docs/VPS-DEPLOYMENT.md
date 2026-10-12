# Deploying to the VPS (Contabo, host nginx)

Target: the whole stack on one VPS, with the host's existing nginx as the only public entry point (TLS, one subdomain per service, IP allowlists). Every container port is bound to `127.0.0.1`.

| Name | Goes to | Access |
| --- | --- | --- |
| `api.jamii.daqiqtech.co.ke` | API Manager gateway (8243) | Public |
| `portal.jamii.daqiqtech.co.ke` | Developer Portal (9443); `/publisher`, `/admin`, `/carbon` allowlisted | Public / allowlist |
| `jenkins.jamii.daqiqtech.co.ke` | Jenkins (8090) | Allowlist |
| `mi.jamii.daqiqtech.co.ke` | MI management API (9164) | Allowlist |

## 0. Check the server

```bash
nproc; free -h; df -h /; lsb_release -ds
docker --version; docker compose version; nginx -v
```
Needs at least 4 vCPU and **12 GB RAM** for the core stack, 16 GB with Jenkins, and about 20 GB of disk. On 8 GB, add swap (`fallocate -l 8G /swapfile`, `mkswap`, `swapon`) and run Jenkins only when needed. If Docker is missing: `curl -fsSL https://get.docker.com | sh`.

## 1. DNS

At your DNS provider, create four **A records** pointing to the VPS's public IP: `api`, `portal`, `jenkins` and `mi` under `jamii.daqiqtech.co.ke`. Check: `dig +short portal.jamii.daqiqtech.co.ke`.

## 2. Firewall

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable && sudo ufw status
```
Docker can bypass ufw for published ports; that is why every port in `docker-compose.yml` is bound to `127.0.0.1`.

## 3. Code and distributions

```bash
git clone https://github.com/<your-username>/<your-repo>.git jamii-savings-integration
cd jamii-savings-integration && git checkout <branch>
```
The WSO2 zips are not in Git. Copy them from your Mac:
```bash
scp dist/wso2mi-4.3.0.zip dist/wso2am-4.4.0.zip dist/checksums.txt <user>@<vps-ip>:~/jamii-savings-integration/dist/
```

## 4. Settings (`.env`)

```bash
cp .env.example .env && nano .env
```
Set strong passwords (`APIM_ADMIN_PASSWORD`, `H2_PASSWORD`, `JENKINS_ADMIN_PASSWORD`), and the public names:
```
APIM_HOSTNAME=portal.jamii.daqiqtech.co.ke
GATEWAY_HOSTNAME=api.jamii.daqiqtech.co.ke
PUBLIC_APIM_URL=https://portal.jamii.daqiqtech.co.ke
PUBLIC_GATEWAY_URL=https://api.jamii.daqiqtech.co.ke
JENKINS_URL=https://jenkins.jamii.daqiqtech.co.ke/
APIM_SELF_ADDRESS=host-gateway
JAMII_REPO_URL=https://github.com/<your-username>/<your-repo>.git
JAMII_REPO_BRANCH=*/<branch>
COMPOSE_PROFILES=core
```

`APIM_SELF_ADDRESS=host-gateway` makes API Manager reach its own public name through nginx. Its token checks call `https://portal.jamii.daqiqtech.co.ke/oauth2/jwks`, so **nginx and the certificate (steps 6–7) must be in place before OAuth calls work**; API-key calls work regardless.

## 5. Start the stack

```bash
scripts/up.sh
```
First run builds everything (10–15 minutes). It ends with `passed=14 failed=0` (checks run inside Docker). `docker compose logs apim | grep "apim:"` shows the public names API Manager picked up.

## 6. TLS certificate (one certificate, four names)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot certonly --nginx \
  -d api.jamii.daqiqtech.co.ke -d portal.jamii.daqiqtech.co.ke \
  -d jenkins.jamii.daqiqtech.co.ke -d mi.jamii.daqiqtech.co.ke
```
Renewal is automatic (`systemctl list-timers | grep certbot`).

## 7. nginx

```bash
sudo cp docker/nginx/vps/jamii.conf /etc/nginx/sites-available/jamii.conf
sudo cp docker/nginx/vps/jamii-tls.conf docker/nginx/vps/jamii-proxy.conf docker/nginx/vps/jamii-allowlist.conf /etc/nginx/snippets/
curl -s ifconfig.me    # on your Mac: your public IP
sudo nano /etc/nginx/snippets/jamii-allowlist.conf    # put your IP (and reviewers' if needed)
sudo ln -sf /etc/nginx/sites-available/jamii.conf /etc/nginx/sites-enabled/jamii.conf
sudo nginx -t && sudo systemctl reload nginx
```

## 8. Verify from your Mac

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://portal.jamii.daqiqtech.co.ke/devportal      # 200
curl -s -o /dev/null -w "%{http_code}\n" https://api.jamii.daqiqtech.co.ke/jamii/accounts/v1/0123456789/balance   # 401 (no token)
```
Then open the Developer Portal, sign in, and call an API with a token from `https://portal.jamii.daqiqtech.co.ke/oauth2/token`. The demo credentials are in `.apim-demo.env` on the VPS.

## 9. Jenkins

```bash
docker compose --profile ci up -d --build jenkins
```
Open `https://jenkins.jamii.daqiqtech.co.ke`. The pipeline deploys to this same stack.

## 10. Reviewer access

The Developer Portal allows self sign-up (**Create Account** on the sign-in page). Alternatively create a user in the Carbon console (`/carbon`, allowlisted) and share it separately. Never share the admin login.

## Later: push-triggered builds

Add `triggers { githubPush() }` to the `Jenkinsfile`, add a GitHub webhook to `https://jenkins.jamii.daqiqtech.co.ke/github-webhook/` with a secret, and in nginx add a `location /github-webhook/` block that allows GitHub's `hooks` address ranges (https://api.github.com/meta).

## Troubleshooting

| Symptom | Check |
| --- | --- |
| 502 from nginx | `docker compose ps`; is the service healthy? `curl -k https://127.0.0.1:9443` on the VPS |
| Sign-in redirects to `localhost` | `APIM_HOSTNAME` not set: `docker compose logs apim \| grep "apim:"`, then `docker compose up -d --force-recreate apim` and re-run `docker compose run --rm apim-init` |
| 403 on `/publisher` or Jenkins | Your IP is not in `jamii-allowlist.conf` |
| OAuth calls fail with 900900, log shows `JWTValidator` and `Connection refused` | API Manager cannot reach its own public URL: set `APIM_SELF_ADDRESS=host-gateway`, make sure nginx serves `portal` on 443 with the certificate, then `docker compose up -d --force-recreate apim` |
| Container exits with code 137 | Out of memory: add swap or stop Jenkins |
