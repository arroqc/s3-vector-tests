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
1. Create an HTTP API Gateway with Lambda integration
2. Set up S3 bucket for website hosting
3. Automatically inject the API endpoint, S3 bucket, and region into `index.html`
4. Upload the rendered HTML to S3

After deployment, the Terraform outputs will show:
- `api_gateway_endpoint` - Your API endpoint URL
- `s3_bucket` - The image upload bucket
- `s3_region` - The AWS region

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
    API_ENDPOINT: `${API_GATEWAY_URL}/search`,
    S3_BUCKET: S3_BUCKET,
    S3_REGION: S3_REGION,
};
```

### API Flow

1. User selects/drags image
2. Frontend sends to API Gateway `/search` endpoint
3. API Gateway invokes Lambda function
4. Lambda processes image and returns similar images
5. Results displayed in UI

### API Contract

The Lambda function expects:
- **Method**: POST
- **Path**: `/search`
- **Body**: `{ "bucket": "...", "key": "..." }`
- **Response**: `{ "nearest_neighbors": [...] }`

Each neighbor should include:
```json
{
  "key": "image-key",
  "distance": 0.1234,
  "metadata": {
    "bucket": "bucket-name",
    "key": "image-key"
  }
}
```
