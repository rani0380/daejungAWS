#!/bin/bash

echo "=== Skills Task 3 배포 스크립트 ==="

# 1. Terraform 초기화 및 배포
echo "1. Terraform 초기화 중..."
terraform init

echo "2. Terraform 계획 확인 중..."
terraform plan

echo "3. Terraform 배포 중..."
terraform apply -auto-approve

# 2. ECR 이미지 푸시
echo "4. ECR 이미지 푸시 중..."
./push-images.sh

# 3. 배포 완료 후 정보 출력
echo "5. 배포 정보 확인 중..."
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "ALB DNS: $ALB_DNS"

# 4. 서비스 Health Check
echo "6. 서비스 Health Check 중..."
sleep 60  # ECS 서비스 시작 대기

curl -s http://$ALB_DNS/v1/user/healthcheck && echo " - User service: OK" || echo " - User service: FAIL"
curl -s http://$ALB_DNS/v1/product/healthcheck && echo " - Product service: OK" || echo " - Product service: FAIL"
curl -s http://$ALB_DNS/v1/stress/healthcheck && echo " - Stress service: OK" || echo " - Stress service: FAIL"

echo "=== 배포 완료 ==="
echo "서비스 엔드포인트:"
echo "- User: http://$ALB_DNS/v1/user"
echo "- Product: http://$ALB_DNS/v1/product"
echo "- Stress: http://$ALB_DNS/v1/stress"