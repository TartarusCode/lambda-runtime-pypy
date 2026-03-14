# lambda-runtime-pypy

An AWS Lambda custom runtime layer for [PyPy](https://pypy.org) on `provided.al2023`.

Derived from https://github.com/iopipe/lambda-runtime-pypy3.5

## Overview

This project packages a PyPy runtime as a Lambda layer and ships a hardened `bootstrap` that:

- Implements the Lambda Runtime API with correct `/next`, `/response`, `/error`, and `/init/error` lifecycle behavior.
- Handles `SIGTERM` and `SIGINT` so the runtime can stop polling and exit cleanly.
- Reports structured error payloads including stack traces.
- Publishes helper modules for structured logging, optional X-Ray integration, and Provisioned Concurrency init hooks.

## Supported Runtime

- `pypy3.11-v7.3.21`
- Lambda runtime target: `provided.al2023`

Python 2 and the legacy `provided` runtime are intentionally no longer built or published.

## Build

Build the runtime layer:

```bash
make build
```

Security checks:

```bash
make audit
```

The build pipeline now:

- Downloads PyPy over HTTPS with retries.
- Verifies the downloaded archive against the pinned SHA-256 checksum in `checksums/pypy.sha256`.
- Copies the runtime helper package into the layer's `site-packages`.
- Runs a best-effort vulnerability scan when `trivy` or `grype` is installed.

## Publish

Upload and publish the layer:

```bash
make upload
make publish
```

Published layer versions are marked as compatible with `provided.al2023`.

## Usage

### Basic Handler

```python
def handler(event, context):
    return {
        "statusCode": 200,
        "body": "Hello from PyPy Lambda!",
    }
```

### Structured Logging

```python
from lambda_runtime_pypy import get_logger

logger = get_logger("app", service="orders")


def handler(event, context):
    logger.info("handling request")
    return {"statusCode": 200, "body": "ok"}
```

### Optional Init Hooks

```python
from lambda_runtime_pypy import register_init_hook


@register_init_hook
def warm_dependencies():
    import json
    json.dumps({"warm": True})
```

You can also register hooks through the `PYPY_RUNTIME_INIT_HOOKS` environment variable using a comma-separated list of `module.function` references.

### Optional X-Ray Helper

```python
from lambda_runtime_pypy import subsegment


def handler(event, context):
    with subsegment("load-order", annotations={"tenant": "demo"}):
        return {"statusCode": 200, "body": "ok"}
```

If `aws_xray_sdk` is not present, the helper becomes a no-op so application code does not need branching logic.

## Handler Resolution

Handlers use the standard `module.function` format and now support nested modules correctly, for example:

- `app.handler`
- `src.handlers.api.handler`

## Performance Notes

- PyPy can improve warm execution performance for CPU-heavy functions.
- Cold starts can be slower than CPython because of JIT warm-up.
- For latency-sensitive workloads, pair this runtime with Provisioned Concurrency and keep init hooks focused on reusable work only.

## Local Build Shell

For a local shell that matches the Lambda base runtime more closely:

```bash
make shell
```

This uses `public.ecr.aws/sam/build-provided.al2023`.

## Examples

- `examples/sam/template.yml`
- `examples/sls/serverless.yml`

Both examples now target `provided.al2023` and expect you to supply the published layer ARN for your account and region.

## License

Apache 2.0
