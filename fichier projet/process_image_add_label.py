import io
import os
from urllib.parse import unquote_plus
import boto3
from PIL import Image, ImageDraw, ImageOps

REGION = os.environ.get('AWS_REGION', 'us-east-1')
s3 = boto3.client('s3', region_name=REGION)
rekognition = boto3.client('rekognition', region_name=REGION)


def normalize_for_rekognition(image):
    """Return an RGB JPEG suitable for DetectLabels (maximum 5 MB as bytes)."""
    image = ImageOps.exif_transpose(image).convert('RGB')
    image.thumbnail((4096, 4096))

    for quality in (90, 80, 70, 60, 50):
        buffer = io.BytesIO()
        image.save(buffer, format='JPEG', quality=quality, optimize=True)
        if buffer.tell() <= 5 * 1024 * 1024:
            return image, buffer.getvalue()

    # Keep lowering the resolution for exceptionally large source images.
    while max(image.size) > 512:
        image.thumbnail((int(image.width * 0.8), int(image.height * 0.8)))
        buffer = io.BytesIO()
        image.save(buffer, format='JPEG', quality=60, optimize=True)
        if buffer.tell() <= 5 * 1024 * 1024:
            return image, buffer.getvalue()

    raise ValueError('The image cannot be compressed below the Rekognition 5 MB limit.')


def lambda_handler(event, context):
    records = event.get('Records', [])
    if not records:
        return {'status': 'no_records'}

    source_bucket = records[0]['s3']['bucket']['name']
    object_key = unquote_plus(records[0]['s3']['object']['key'])

    response = s3.get_object(Bucket=source_bucket, Key=object_key)
    img_bytes = response['Body'].read()

    img = Image.open(io.BytesIO(img_bytes))
    img, rekognition_bytes = normalize_for_rekognition(img)
    width, height = img.size

    analysis = rekognition.detect_labels(
        Image={'Bytes': rekognition_bytes},
        MaxLabels=10,
        MinConfidence=50
    )

    draw = ImageDraw.Draw(img)
    boxes_drawn = 0

    for label in analysis.get('Labels', []):
        for instance in label.get('Instances', []):
            box = instance['BoundingBox']
            left = width * box['Left']
            top = height * box['Top']
            w = width * box['Width']
            h = height * box['Height']

            points = (left, top, left + w, top + h)
            draw.rectangle(points, outline='red', width=5)
            display_text = f"{label['Name']} ({label['Confidence']:.1f}%)"
            draw.text((left, max(0, top - 20)), display_text, fill='red')
            boxes_drawn += 1

    buffer = io.BytesIO()
    img.save(buffer, format='JPEG', quality=90, optimize=True)
    buffer.seek(0)

    output_bucket = os.environ['PROCESSED_BUCKET']
    output_key = f"labeled-{object_key}"
    s3.put_object(Bucket=output_bucket, Key=output_key, Body=buffer, ContentType='image/jpeg')

    return {'status': 'complete', 'file': output_key, 'boxes_drawn': boxes_drawn}
