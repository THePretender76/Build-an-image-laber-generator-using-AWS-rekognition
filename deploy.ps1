param(
    [string]$StackName = "visioncraft-stack",
    [string]$Region = "us-east-1",
    [string]$TemplateFile = "./Cloudformation file/infrastructure-vision-craft.yml",
    [Parameter(Mandatory = $true)]
    [string]$PillowLayerArn,
    [string]$AllowedOrigin = "*"
)

Write-Host "=== Deployment VisionCraft AI ===" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Stack: $StackName" -ForegroundColor Yellow

$ErrorActionPreference = "Stop"

# 1. Vérifier que AWS CLI est installé
aws --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI not found. Install it and configure your credentials first."
}

# 2. Vérifier la configuration AWS
aws sts get-caller-identity --region $Region | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "AWS credentials not configured. Run 'aws configure' first."
}

# 3. Déployer la stack
$accountId = aws sts get-caller-identity --region $Region --query Account --output text
$artifactBucket = "visioncraft-artifacts-$accountId-$Region"
$existingBucket = aws s3api list-buckets --query "Buckets[?Name=='$artifactBucket'].Name | [0]" --output text
if ($LASTEXITCODE -ne 0) {
    throw "Unable to list S3 buckets. Verify that the AWS identity has the s3:ListAllMyBuckets permission."
}
if ([string]::IsNullOrWhiteSpace($existingBucket) -or $existingBucket -eq "None") {
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $artifactBucket --region $Region | Out-Null
    } else {
        aws s3api create-bucket --bucket $artifactBucket --region $Region --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
    }
}

$packageDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("visioncraft-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $packageDirectory | Out-Null
$processorZip = Join-Path $packageDirectory "process_image_add_label.zip"
$presignedZip = Join-Path $packageDirectory "get_presigned_url.zip"
Compress-Archive -LiteralPath "fichier projet\process_image_add_label.py" -DestinationPath $processorZip -Force
Compress-Archive -LiteralPath "fichier projet\get_presigned_url.py" -DestinationPath $presignedZip -Force

$processorKey = "lambda/process_image_add_label.zip"
$presignedKey = "lambda/get_presigned_url.zip"
aws s3 cp $processorZip "s3://$artifactBucket/$processorKey" --region $Region | Out-Null
aws s3 cp $presignedZip "s3://$artifactBucket/$presignedKey" --region $Region | Out-Null
Remove-Item -LiteralPath $packageDirectory -Recurse -Force

Write-Host "Deploying CloudFormation stack..." -ForegroundColor Green
aws cloudformation deploy `
    --region $Region `
    --stack-name $StackName `
    --template-file $TemplateFile `
    --capabilities CAPABILITY_IAM `
    --parameter-overrides ProjectPrefix=visioncraft PillowLayerArn=$PillowLayerArn AllowedOrigin=$AllowedOrigin ProcessorCodeBucket=$artifactBucket ProcessorCodeKey=$processorKey PresignedCodeBucket=$artifactBucket PresignedCodeKey=$presignedKey

if ($LASTEXITCODE -ne 0) {
    throw "CloudFormation deployment failed."
}

# 4. Récupérer les outputs
Write-Host "Retrieving stack outputs..." -ForegroundColor Green
$stackOutputs = aws cloudformation describe-stacks --region $Region --stack-name $StackName --query "Stacks[0].Outputs" --output json | ConvertFrom-Json

$frontendUrl = $stackOutputs | Where-Object { $_.OutputKey -eq "WebsiteURL" } | Select-Object -ExpandProperty OutputValue
$presignedUrl = $stackOutputs | Where-Object { $_.OutputKey -eq "PresignedFunctionUrl" } | Select-Object -ExpandProperty OutputValue

Write-Host "Frontend URL: $frontendUrl" -ForegroundColor Green
Write-Host "Presigned Lambda URL: $presignedUrl" -ForegroundColor Green

# 5. Insert the generated Function URL in a temporary frontend file and upload it.
Write-Host "Uploading frontend files..." -ForegroundColor Green
$frontendBucket = $stackOutputs | Where-Object { $_.OutputKey -eq "FrontendBucketName" } | Select-Object -ExpandProperty OutputValue
$temporaryFrontend = New-TemporaryFile
$urlMarker = "const LAMBDA_URL = '__LAMBDA_FUNCTION_URL__';"
$urlConfiguration = "const LAMBDA_URL = '$presignedUrl';"
(Get-Content -Raw -LiteralPath ./index.html).Replace($urlMarker, $urlConfiguration) | Set-Content -LiteralPath $temporaryFrontend -Encoding utf8
aws s3 cp $temporaryFrontend.FullName "s3://$frontendBucket/index.html" --content-type "text/html; charset=utf-8" --region $Region
Remove-Item -LiteralPath $temporaryFrontend.FullName

Write-Host "Deployment complete. Open: $frontendUrl" -ForegroundColor Green
