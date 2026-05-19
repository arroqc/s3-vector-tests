# Lambda Layer Setup

This directory builds an AWS Lambda layer using Docker.
The layer includes dependencies from `requirements.txt` and packages them for the Python Lambda runtime.

## Quick Start

### Build with Docker via Makefile
```bash
make build
make zip
```

This will:
1. Build a Docker image for the selected Python runtime
2. Install dependencies into the Lambda layer layout
3. Extract the resulting `python/` directory locally
4. Create `lambda_layer.zip`

### Build with a specific Python runtime
```bash
make build PYTHON_RUNTIME=3.12
make zip
```

### Build and zip in one step
```bash
make all
```

### Clean build artifacts
```bash
make clean
```

## Requirements

- Docker installed and available on the command line
- `requirements.txt` present in this directory

## Uploading to AWS

1. **Via AWS Console:**
   - Go to Lambda → Layers
   - Create a new layer
   - Upload `lambda_layer.zip`
   - Choose the matching Python runtime

2. **Via AWS CLI:**
   ```bash
   aws lambda publish-layer-version \
     --layer-name my-layer \
     --zip-file fileb://lambda_layer.zip \
     --compatible-runtimes python3.11
   ```

## Adding to your Lambda Function

Attach the layer to your function via:
- AWS Console: Function → Layers → Add a layer
- CloudFormation/SAM template or Terraform

## Output Structure

After building, the layer has this structure:
```
python/
└── lib/
    └── python<runtime>/
        └── site-packages/
            ├── PIL/          (pillow)
            ├── numpy/
            ├── boto3/
            └── [dependencies]
```

## Notes

- `make build` now uses Docker only.
- `build.sh` is no longer used.
- Docker ensures the layer is built with Linux-compatible packages for AWS Lambda.
