import json
import base64
import os
import boto3

s3_client = boto3.client('s3')
bedrock_client = boto3.client('bedrock-runtime')


def lambda_handler(event, context):
    """
    Event should contain:
    {
        "bucket": "s3-bucket-name",
        "key": "path/to/image.jpg"
    }
    """
    try:
        bucket = event.get('bucket')
        key = event.get('key')

        if not bucket or not key:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'bucket and key required'})
            }

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
        return {
            'statusCode': 500,
            # Todo: Log the error somewhere safe
            'body': "json.dumps({'error': 'Error during lambda search'})"
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

