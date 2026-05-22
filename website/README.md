# Image Vector Search UI

A simple static website for uploading images and finding similar ones using vector embeddings.

## Features

- Drag-and-drop image upload
- Real-time search for similar images
- Responsive design
- Clean, modern UI

## Setup

### Quick Start

1. **Update Configuration** in `app.js`:
   ```javascript
   const CONFIG = {
       API_ENDPOINT: 'https://your-api-gateway-url...',
       S3_BUCKET: 'your-bucket-name',
       S3_REGION: 'us-east-1',
   };
   ```

2. **Serve locally** (for development):
   ```bash
   # Python 3
   python -m http.server 8000
   
   # Or Node.js with http-server
   npx http-server
   ```

   Then open `http://localhost:8000`

3. **Deploy to S3** (for production):
   ```bash
   aws s3 sync . s3://your-website-bucket --exclude ".git*"
   ```

## Architecture

### Flow

1. User selects/drags image → Stored in S3
2. Frontend calls API Gateway endpoint with bucket + key
3. API Gateway invokes Lambda function
4. Lambda processes image and returns similar images
5. Results displayed in UI

### File Structure

- `index.html` - Main HTML structure
- `style.css` - Styling and responsive design
- `app.js` - Upload handling and Lambda API integration

## Next Steps

1. **Set up API Gateway** for the Lambda function
2. **Configure S3 pre-signed URLs** for browser uploads
3. **Update `CONFIG`** in `app.js` with your endpoint
4. **Deploy** the website to S3 or your preferred hosting

## Configuration Details

### API Endpoint Expected Format

The API Gateway endpoint should:
- Accept POST requests
- Expect JSON body: `{ "bucket": "...", "key": "..." }`
- Return JSON: `{ "nearest_neighbors": [...] }`

### Result Format

Each neighbor in the response should include:
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
