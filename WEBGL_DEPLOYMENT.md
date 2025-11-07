# WebGL Build Deployment with S3 and CloudFront

---

## Prerequisites

Before you begin, ensure you have the following:

- **AWS CLI** installed and configured ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **jq** installed ([Install Guide](https://stedolan.github.io/jq/download/))
- **Access to an AWS account** with permissions to manage S3, CloudFront, and ACM
- **S3 bucket** and **CloudFront distribution** creation permissions
- (Recommended) **ACM certificate** for your custom domain (for HTTPS)

---

This guide explains how to upload and serve your Unity WebGL build using Amazon S3 and CloudFront, with best practices for compression, caching, and updates.

---

## 1. Create and Prepare the S3 Bucket

### a. Create the S3 Bucket

```bash
aws s3api create-bucket \
  --bucket webgl-static-build \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1
```

### b. Set the Bucket Policy (Public Read Access)

Create a file named `webgl-bucket-policy.json` with the following content:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::webgl-static-build/*"
    }
  ]
}
```

Apply the policy:

```bash
aws s3api put-bucket-policy \
  --bucket webgl-static-build \
  --policy file://webgl-bucket-policy.json
```

---

## 2. Upload Your WebGL Build to S3

Use the following Bash script to upload your build files with the correct headers for Brotli compression, caching, and content types.

> **Note:** This script does NOT perform CloudFront invalidation. Use it for initial upload and for updates (see step 4).

```bash
#!/bin/bash

# ==== CONFIG ====
BUCKET_NAME="webgl-static-build" # Replace with your bucket name
LOCAL_DIR="./WebGlBuild23"       # Replace with your local build directory
# ===============

# Determine Content-Type based on file extension
get_content_type() {
  case "$1" in
    *.html) echo "text/html" ;;
    *.js|*.js.br|*.framework.js.br|*.loader.js.br) echo "application/javascript" ;;
    *.wasm.br) echo "application/wasm" ;;
    *.data.br) echo "application/octet-stream" ;;
    *.json) echo "application/json" ;;
    *.css) echo "text/css" ;;
    *) echo "application/octet-stream" ;;
  esac
}

echo "Uploading all files from $LOCAL_DIR/ to s3://$BUCKET_NAME/ (root) with correct headers..."

find "$LOCAL_DIR" -type f | while read -r FILE; do
  REL_PATH="${FILE#$LOCAL_DIR/}"
  CONTENT_TYPE=$(get_content_type "$FILE")

  echo "→ Uploading: $REL_PATH"

  if [[ "$FILE" == *.br ]]; then
    aws s3 cp "$FILE" "s3://$BUCKET_NAME/$REL_PATH" \
      --content-type "$CONTENT_TYPE" \
      --content-encoding br \
      --cache-control max-age=31536000,public
  else
    aws s3 cp "$FILE" "s3://$BUCKET_NAME/$REL_PATH" \
      --content-type "$CONTENT_TYPE" \
      --cache-control max-age=31536000,public
  fi
done

echo "Upload complete!"
```

---

## 3. Set Up CloudFront Distribution

You can use the AWS Console (recommended for most users) or the AWS CLI.

### Option A: Using AWS Console

1. Go to **CloudFront** → Click **Create Distribution**
2. **Origin Domain:** `webgl-static-build.s3.amazonaws.com`
3. **Viewer Protocol Policy:** Redirect HTTP to HTTPS
4. **Compress Objects Automatically:** Yes
5. **Default Root Object:** `index.html`
6. **Error Pages:**  
   - Create custom error response for 403 and 404:  
     - Response Page Path: `/index.html`  
     - HTTP Response Code: `200`
7. **Caching:**  
   - Use `CachingOptimized` or a custom policy  
   - TTL: `31536000` seconds (1 year)
8. **SSL:**  
   - Attach ACM certificate for your domain (recommended)
9. **Save and Deploy**

### Option B: Using AWS CLI

1. Create a `cloudfront-config.json` file with the following content (edit as needed):

```json
{
  "CallerReference": "webgl-distribution-001",
  "Comment": "WebGL build distribution",
  "Enabled": true,
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "webglS3Origin",
        "DomainName": "webgl-static-build.s3.amazonaws.com",
        "OriginPath": "",
        "CustomHeaders": { "Quantity": 0 },
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }
    ]
  },
  "DefaultRootObject": "index.html",
  "DefaultCacheBehavior": {
    "TargetOriginId": "webglS3Origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 7,
      "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": { "Forward": "none" },
      "Headers": { "Quantity": 1, "Items": ["Origin"] }
    },
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "OriginRequestPolicyId": "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "arn:aws:acm:ap-northeast-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID",
    "SslSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 0
      },
      {
        "ErrorCode": 403,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 0
      }
    ]
  },
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2",
  "IsIPV6Enabled": true
}
```

- **OriginAccessIdentity**: Add if you want to restrict S3 bucket access to CloudFront only.
- **CachePolicyId**: Use AWS managed or your own custom cache policy.
- **ViewerCertificate**: Use ACM for custom domains/SSL.
- **CustomErrorResponses**: Handles SPA routing for 403/404.
- **AllowedMethods**: Supports all HTTP methods if needed.
- **PriceClass**: Adjust for global or regional delivery.

2. Run:

```bash
aws cloudfront create-distribution --distribution-config file://cloudfront-config.json
```

---

## Update/Deploy New Build with CloudFront Invalidation

Whenever you need to update your WebGL build:

1. Place your new build files in your local build directory.
2. Run the upload script below to upload the new files to S3 and invalidate the CloudFront cache so users get the latest version immediately.

```bash
#!/bin/bash

# ==== CONFIG ====
BUCKET_NAME="webgl-static-build" # Replace with your bucket name
LOCAL_DIR="./WebGlBuild23"       # Replace with your local build directory
DISTRIBUTION_ID="YOUR_CLOUDFRONT_DISTRIBUTION_ID" # Replace with your CloudFront Distribution ID
# ===============

# Determine Content-Type based on file extension
get_content_type() {
  case "$1" in
    *.html) echo "text/html" ;;
    *.js|*.js.br|*.framework.js.br|*.loader.js.br) echo "application/javascript" ;;
    *.wasm.br) echo "application/wasm" ;;
    *.data.br) echo "application/octet-stream" ;;
    *.json) echo "application/json" ;;
    *.css) echo "text/css" ;;
    *) echo "application/octet-stream" ;;
  esac
}

echo "Uploading all files from $LOCAL_DIR/ to s3://$BUCKET_NAME/ (root) with correct headers..."

find "$LOCAL_DIR" -type f | while read -r FILE; do
  REL_PATH="${FILE#$LOCAL_DIR/}"
  CONTENT_TYPE=$(get_content_type "$FILE")

  echo "→ Uploading: $REL_PATH"

  if [[ "$FILE" == *.br ]]; then
    aws s3 cp "$FILE" "s3://$BUCKET_NAME/$REL_PATH" \
      --content-type "$CONTENT_TYPE" \
      --content-encoding br \
      --cache-control max-age=31536000,public
  else
    aws s3 cp "$FILE" "s3://$BUCKET_NAME/$REL_PATH" \
      --content-type "$CONTENT_TYPE" \
      --cache-control max-age=31536000,public
  fi
done

echo "Upload complete!"

if [[ "$DISTRIBUTION_ID" != "YOUR_CLOUDFRONT_DISTRIBUTION_ID" ]]; then
  echo "Creating CloudFront invalidation for /*"
  aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/*"
fi

echo "Deployment and invalidation complete!"
```

> **Tip:** Use this script every time you update your build files. Just set the correct `DISTRIBUTION_ID` and `LOCAL_DIR` for your project.

---

## 📝 Notes & Best Practices

- Ensure `index.html` is at the root of the S3 bucket.
- Use correct Content-Encoding and Content-Type headers for best performance.
- Use CloudFront for global delivery and lower latency.
- For SPA routing, set custom error responses to redirect to `index.html`.

---

## Using a Custom Domain with CloudFront

To serve your WebGL build from a custom domain (e.g., `game.example.com`):

1. **Request an ACM Certificate**
   - Go to the [AWS Certificate Manager (ACM) Console](https://console.aws.amazon.com/acm/home?region=us-east-1#/)
   - Request a public certificate for your domain (e.g., `game.example.com`)
   - Complete DNS validation as instructed by AWS

2. **Attach the ACM Certificate to CloudFront**
   - In your CloudFront distribution settings, set the 'Alternate Domain Names (CNAMEs)' to your domain (e.g., `game.example.com`)
   - Select the ACM certificate you created
   - Save and deploy the changes

3. **Update Your DNS Records**
   - In your DNS provider, create a CNAME record pointing your domain (e.g., `game.example.com`) to your CloudFront distribution's domain name (e.g., `d1234abcd.cloudfront.net`)
   - Wait for DNS propagation

4. **Test Your Custom Domain**
   - Visit `https://game.example.com` in your browser to verify it serves your WebGL build securely

> **Note:** ACM certificates for CloudFront must be in the `us-east-1` region, regardless of your S3 bucket's region. 