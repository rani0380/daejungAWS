# Skills Task 3 - 빠른 시작 가이드

## 🚀 원클릭 배포

### Windows 환경
```cmd
# 1. ECR 이미지 푸시
push-images.bat

# 2. Terraform 배포
terraform init
terraform apply -auto-approve
```

### Linux/Mac 환경
```bash
# 전체 배포 (권장)
chmod +x deploy.sh
./deploy.sh

# 또는 단계별 실행
chmod +x push-images.sh
./push-images.sh
terraform init
terraform apply -auto-approve
```

## 📋 필수 사전 준비
1. **Docker 설치 및 실행**
2. **AWS CLI 설정**: `aws configure`
3. **Terraform 설치**

## 🔍 배포 후 확인
```bash
# ALB DNS 확인
terraform output alb_dns_name

# 서비스 테스트
curl http://<alb-dns>/v1/user/healthcheck
curl http://<alb-dns>/v1/product/healthcheck  
curl http://<alb-dns>/v1/stress/healthcheck
```

## 🧹 리소스 정리
```bash
# Linux/Mac
./cleanup.sh

# Windows
terraform destroy -auto-approve
```

## ⚠️ 주의사항
- **ECR 이미지 Push 필수**: ECS Task 실행을 위해 반드시 필요
- **Health Check**: 모든 서비스에 `/healthcheck` 엔드포인트 구현됨
- **DB 연결**: RDS/DynamoDB 자동 연결 설정
- **비용 관리**: 테스트 후 반드시 `terraform destroy` 실행