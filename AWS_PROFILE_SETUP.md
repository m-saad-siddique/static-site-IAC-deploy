# AWS Profile Setup Guide

## Quick Setup

Configure the AWS profile `deploy-config` using the interactive method:

```bash
aws configure --profile deploy-config
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key  
- Default region (e.g., `us-east-1`)
- Default output format (`json`)

## Verify Configuration

```bash
# Check if profile exists
aws configure list-profiles | grep deploy-config

# Test the profile
aws sts get-caller-identity --profile deploy-config
```

## What Happens If Profile Is Missing?

All deployment scripts automatically check for the `deploy-config` profile. If it's not configured, you'll see an error message like:

```
Error: AWS profile 'deploy-config' is not configured.

Please configure the AWS profile using one of these methods:

Method 1: Using AWS CLI (Interactive)
  aws configure --profile deploy-config

Method 2: Using AWS CLI (Non-interactive)
  aws configure set aws_access_key_id YOUR_ACCESS_KEY --profile deploy-config
  aws configure set aws_secret_access_key YOUR_SECRET_KEY --profile deploy-config
  aws configure set region us-east-1 --profile deploy-config

Method 3: Edit ~/.aws/credentials and ~/.aws/config files directly
```

## Using a Different Profile Name

If you want to use a different profile name, set the environment variable:

```bash
export AWS_PROFILE_NAME=my-custom-profile
./scripts/plan.sh dev
```

## File Locations

AWS profiles are stored in:

- **Credentials**: `~/.aws/credentials`
- **Configuration**: `~/.aws/config`

## Security Notes

- Never commit AWS credentials to version control
- Use IAM roles with least privilege principles
- Rotate access keys regularly
- Consider using AWS SSO or temporary credentials for production

