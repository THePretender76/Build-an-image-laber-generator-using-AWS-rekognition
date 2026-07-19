import json
import os
import boto3
from botocore.exceptions import ClientError

REGION = os.environ.get('AWS_REGION', 'us-east-1')
s3 = boto3.client('s3', region_name=REGION)


def lambda_handler(event, context):
    params = event.get('queryStringParameters', {}) or {}
    file_name = params.get('file')
    action = params.get('action', 'upload')
    input_bucket = os.environ['INPUT_BUCKET']
    processed_bucket = os.environ['PROCESSED_BUCKET']

    try:
        if action == 'view':
            processed_file_name = f"labeled-{file_name}"
            try:
                s3.head_object(Bucket=processed_bucket, Key=processed_file_name)
            except ClientError as error:
                if error.response['Error']['Code'] in ('404', 'NoSuchKey', 'NotFound'):
                    return {
                        'statusCode': 200,
                        'body': json.dumps({'url': None, 'status': 'processing'})
                    }
                raise
            url = s3.generate_presigned_url(
                'get_object',
                Params={'Bucket': processed_bucket, 'Key': processed_file_name},
                ExpiresIn=60
            )
            status = 'ready'
        else:
            url = s3.generate_presigned_url(
                'put_object',
                Params={'Bucket': input_bucket, 'Key': file_name, 'ContentType': 'image/jpeg'},
                ExpiresIn=300
            )
            status = 'upload_ready'

        return {
            'statusCode': 200,
            'body': json.dumps({'url': url, 'status': status})
        }
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
