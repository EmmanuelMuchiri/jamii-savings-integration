# WSO2 distributions

Download the self-managed (Option C) distributions from wso2.com and place them here.
The zips are gitignored; only this README and `checksums.txt` are committed.

| File | Product |
| --- | --- |
| `wso2mi-<MI_VERSION>.zip` | WSO2 Micro Integrator |
| `wso2am-<APIM_VERSION>.zip` | WSO2 API Manager |

Record the hashes after downloading:

```bash
cd dist && sha256sum wso2mi-*.zip wso2am-*.zip > checksums.txt
```

The image builds verify each zip against `checksums.txt` before unpacking it.

## apictl (optional)

The `apim-init` container downloads apictl automatically. For offline builds, put the **Linux** archive here
(not the macOS one): `apictl-4.4.1-linux-arm64.tar.gz` on Apple Silicon, `apictl-4.4.1-linux-amd64.tar.gz` on Intel.
