# Image Vector Search UI

A static website for uploading images and finding similar ones using vector embeddings. Configuration and deployment are automated via Terraform.

## Features

- Drag-and-drop image upload
- Real-time search for similar images using vector embeddings
- Responsive design
- Clean, modern UI
- Automatic configuration injection via Terraform

## Deployment

### Production (via Terraform)

The website is deployed automatically as part of the Terraform infrastructure:

```bash
cd terraform
terraform apply
```

This will:
1. Create an HTTP API Gateway with `/presign` and `/search` endpoints
2. Set up S3 bucket for website hosting
3. Automatically inject the API endpoint, S3 bucket, and region into `index.html`
4. Upload the rendered HTML to S3
5. Configure S3 CORS for direct browser uploads

After deployment, the Terraform outputs will show:
- `api_gateway_endpoint` - Your API endpoint URL (base URL for both endpoints)
- `s3_bucket` - The image upload bucket
- `s3_region` - The AWS region
- `website_url` - Your website URL (HTTP)

**No manual configuration needed.** Terraform handles everything.

### Local Development

For local testing:

```bash
# Python 3
python -m http.server 8000

# Or Node.js
npx http-server
```

Then open `http://localhost:8000`

**Note:** Local development won't have the API endpoint injected. You'll need to manually set `API_GATEWAY_URL`, `S3_BUCKET`, and `S3_REGION` in the browser console or modify `index.html` temporarily.

## Architecture

### Files

- `index.html` - Main HTML with template variables for API configuration
- `style.css` - Responsive design and styling
- `app.js` - Image upload handling and API integration

### Configuration

Configuration values are injected by Terraform at deployment:

```javascript
// In index.html, Terraform injects:
const API_GATEWAY_URL = '${api_gateway_url}';  // API Gateway endpoint
const S3_BUCKET = '${s3_bucket}';               // S3 bucket for uploads
const S3_REGION = '${s3_region}';               // AWS region
```

These are then used in `app.js`:

```javascript
const CONFIG = {
    API_ENDPOINT: `${API_GATEWAY_URL}`,  // Base URL for /presign and /search
    S3_BUCKET: S3_BUCKET,
    S3_REGION: S3_REGION,
};

// Frontend uses:
// - ${CONFIG.API_ENDPOINT}/presign for upload URL
// - ${CONFIG.API_ENDPOINT}/search for image search
```

### API Flow

1. **User selects/drags image** - File validation (size, type) happens in browser
2. **Request presigned URL** - Frontend calls `/presign` endpoint with filename and size
3. **Get upload URL** - Lambda validates and returns S3 pre-signed URL (valid 15 min)
4. **Direct S3 upload** - Frontend uploads directly to S3 using pre-signed URL
5. **Search similar images** - Frontend calls `/search` with S3 bucket and key
6. **Lambda processes** - Lambda generates embedding via Bedrock and searches S3 Vectors
7. **Results displayed** - Similar images with distance scores shown in UI

### API Contract

**POST /presign** - Get upload URL:
- **Body**: `{ "filename": "image.jpg", "size": 1024000 }`
- **Response**: `{ "presigned_url": "...", "bucket": "...", "key": "uploads/image.jpg" }`
- **Errors**: File too large (>10 MB), invalid file type

**POST /search** - Search similar images:
- **Body**: `{ "bucket": "s3-vector-test-image-uploads", "key": "uploads/image.jpg" }`
- **Response**: `{ "nearest_neighbors": [...] }`
- **Errors**: Missing bucket/key

Each neighbor in response includes:
```json
{
  "key": "uploads/similar-image.jpg",
  "distance": 0.1234,
  "metadata": {
    "bucket": "s3-vector-test-image-uploads",
    "key": "uploads/similar-image.jpg"
  }
}
```
