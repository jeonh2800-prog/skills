#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
REGION_CODE="ap-northeast-2"
IMAGE_TAGS=("user" "product" "stress")

aws ecr get-login-password --region $REGION_CODE | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION_CODE.amazonaws.com"

for IMAGE_TAG in "${IMAGE_TAGS[@]}"; do
    ECR_NAME="apdev-$IMAGE_TAG-ecr"
    ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION_CODE.amazonaws.com/$ECR_NAME"

    docker build -t "$ECR_URI:$IMAGE_TAG" "/home/ec2-user/ecr/$IMAGE_TAG"
    docker push "$ECR_URI:$IMAGE_TAG"

    sed -i "s|IMAGE|$ECR_URI:$IMAGE_TAG|g" /home/ec2-user/eks/manifest/$IMAGE_TAG/deployment.yaml
done