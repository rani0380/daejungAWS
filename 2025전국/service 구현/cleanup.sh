#!/bin/bash

echo "=== Skills Task 3 리소스 정리 ==="

# 1. ECR 이미지 삭제
echo "1. ECR 이미지 정리 중..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-2"

SERVICES=("user" "product" "stress")
for SERVICE in "${SERVICES[@]}"; do
    echo "Deleting images from skills-task3-competition-$SERVICE..."
    aws ecr batch-delete-image \
        --repository-name skills-task3-competition-$SERVICE \
        --image-ids imageTag=latest \
        --region $REGION 2>/dev/null || echo "No images to delete for $SERVICE"
done

# 2. Terraform 리소스 삭제
echo "2. Terraform 리소스 삭제 중..."
terraform destroy -auto-approve

echo "=== 정리 완료 ==="
echo "모든 AWS 리소스가 삭제되었습니다."