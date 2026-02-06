#!/bin/bash

# AWS 계정 ID 가져오기
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-2"

# ECR 로그인
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# 서비스별 이미지 빌드 및 푸시
SERVICES=("user" "product" "stress")

for SERVICE in "${SERVICES[@]}"; do
    echo "Building and pushing $SERVICE service..."
    
    # 이미지 빌드
    docker build -t skills-task3-competition-$SERVICE ./services/$SERVICE/
    
    # 태그 지정
    docker tag skills-task3-competition-$SERVICE:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/skills-task3-competition-$SERVICE:latest
    
    # ECR에 푸시
    docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/skills-task3-competition-$SERVICE:latest
    
    echo "$SERVICE service pushed successfully!"
done

echo "All services pushed to ECR!"