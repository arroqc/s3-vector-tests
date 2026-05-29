import json
import base64
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
bedrock_client = boto3.client('bedrock-runtime')


MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


def lambda_handler(event, context):
    """
    Routes requests to /search or /presign endpoints
    """
    path = event.get('rawPath', '/')

    if path == '/presign':
        return handle_presign(event, context)
    elif path == '/search':
        return handle_search(event, context)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'Endpoint not found'})
        }


def handle_presign(event, context):
    """
    Generate a pre-signed URL for S3 upload
    Expects: {"filename": "image.jpg", "size": 1024}
    """
    try:
        body = json.loads(event.get('body', '{}'))
        filename = body.get('filename')
        file_size = body.get('size', 0)

        if not filename:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'filename required'})
            }

        # Validate file size
        if file_size > MAX_FILE_SIZE:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'File too large. Max size is {MAX_FILE_SIZE / 1024 / 1024:.0f} MB'})
            }

        # Validate file extension
        allowed_extensions = ('.jpg', '.jpeg', '.png', '.gif', '.webp')
        if not any(filename.lower().endswith(ext) for ext in allowed_extensions):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Only image files allowed: {", ".join(allowed_extensions)}'})
            }

        bucket = os.environ.get('UPLOAD_BUCKET')
        key = f"uploads/{filename}"

        # Generate pre-signed URL (valid for 15 minutes)
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket,
                'Key': key,
                'ContentType': 'image/*'
            },
            ExpiresIn=900  # 15 minutes
        )

        logger.info(f"Generated pre-signed URL for {filename}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'presigned_url': presigned_url,
                'bucket': bucket,
                'key': key
            })
        }

    except Exception as e:
        logger.error(f"Presign failed: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to generate upload URL'})
        }


def handle_search(event, context):
    """
    Search for similar images
    Expects: {"bucket": "...", "key": "..."}
    """
    try:
        body = json.loads(event.get('body', '{}'))
        bucket = body.get('bucket')
        key = body.get('key')

        # Get embedding from Bedrock Nova
        image_base64 = load_image_as_base64(bucket, key)
        embedding = get_nova_embedding(image_base64)

        # Index
        index_embedding(key, embedding, {'bucket': bucket, 'key': key})

        # Search
        neighbors = search_nearest_neighbors(embedding, topK=5)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'nearest_neighbors': neighbors
            })
        }

    except Exception as e:
        logger.error(f"Search failed: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Search service temporarily unavailable'})
        }


def load_image_as_base64(bucket, key):
    """Load image from S3 and convert to base64"""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    image_data = response['Body'].read()
    image_base64 = base64.b64encode(image_data).decode('utf-8')
    return image_base64


def get_nova_embedding(image_base64):
    """Call Bedrock Nova to get 256-dimensional embedding"""
    model_id = 'amazon.nova-2-multimodal-embeddings-v1:0'

    request_body = {
        'taskType': 'SINGLE_EMBEDDING',
        'singleEmbeddingParams': {
            'embeddingPurpose': 'GENERIC_INDEX',
            'embeddingDimension': 256,
            "image": {
                "format": "jpeg",
                "source": {"bytes": image_base64}
            },
        },
    }

    response = bedrock_client.invoke_model(
        modelId=model_id,
        body=json.dumps(request_body),
        accept='application/json',
        contentType='application/json',
    )

    response_body = json.loads(response["body"].read())
    embedding = response_body["embeddings"][0]["embedding"]

    return embedding

def index_embedding(key, embedding, metadata):
    s3vectors = boto3.client("s3vectors")
    s3vectors.put_vectors(
        indexArn=os.environ["INDEX_PATH"],
        vectors=[{
            'key': key,
            'data': {'float32': embedding},
            'metadata': metadata
        }]
    )


def search_nearest_neighbors(embedding, topK=5):
    s3vectors = boto3.client("s3vectors")

    response = s3vectors.query_vectors(
        indexArn=os.environ["INDEX_PATH"],
        topK=topK,
        queryVector={'float32': embedding},
        returnMetadata=True,
        returnDistance=True
    )

    neighbors = response.get('results', [])
    return neighbors

