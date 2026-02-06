# Skills Task 3 - 기능경기대회 클라우드컴퓨팅 직종

## 아키텍처 개요
- **ECS on EC2**: t3.medium 인스턴스 기반 컨테이너 서비스
- **ALB**: 경로 기반 라우팅 (/v1/user, /v1/product, /v1/stress)
- **RDS MySQL**: Multi-AZ, db.t3.micro
- **DynamoDB**: PAY_PER_REQUEST 모드
- **WAF**: 403/404 구분 처리

## 배포 순서

### 1. Terraform 초기화
```bash
terraform init
terraform plan
terraform apply
```

### 2. ECR 이미지 Push (필수)
```bash
# AWS CLI 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 각 서비스별 이미지 빌드 및 푸시
docker build -t skills-task3-competition-user ./user-service
docker tag skills-task3-competition-user:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/skills-task3-competition-user:latest
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/skills-task3-competition-user:latest

docker build -t skills-task3-competition-product ./product-service
docker tag skills-task3-competition-product:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/skills-task3-competition-product:latest
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/skills-task3-competition-product:latest

docker build -t skills-task3-competition-stress ./stress-service
docker tag skills-task3-competition-stress:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/skills-task3-competition-stress:latest
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/skills-task3-competition-stress:latest
```

### 3. 서비스 확인
```bash
# ALB DNS 확인
terraform output alb_dns_name

# 서비스 테스트
curl http://<alb-dns>/v1/user/healthcheck
curl http://<alb-dns>/v1/product/healthcheck
curl http://<alb-dns>/v1/stress/healthcheck
```

## 주요 특징

### 네트워크 설계
- **Public Subnet**: ALB, ECS EC2 인스턴스
- **DB Subnet**: RDS 전용
- **NAT Gateway 미사용**: 비용 절감 및 안정성

### 보안 설정
- **Security Groups**: 최소 권한 원칙
- **IAM Roles**: 서비스별 역할 분리
- **WAF**: API 경로별 세밀한 제어

### 모니터링
- **CloudWatch Alarms**: ALB, ECS, RDS 핵심 지표
- **Log Groups**: 서비스별 로그 분리
- **Container Insights**: ECS 클러스터 모니터링

## 채점 포인트 대응
- ✅ 인스턴스 타입: t3.medium 고정
- ✅ RDS: Multi-AZ, db.t3.micro
- ✅ 고가용성: ASG 최소 2대
- ✅ 경로 기반 라우팅: /v1/* 패턴
- ✅ 403/404 구분: WAF + ALB 조합
- ✅ 모니터링: 핵심 지표 알람 설정

## 주의사항
1. **ECR 이미지 Push 필수**: 미배포 시 ECS Task 실행 실패
2. **Health Check 엔드포인트**: 각 서비스에 `/healthcheck` 구현 필요
3. **DB 연결 정보**: RDS 엔드포인트 및 DynamoDB 테이블명 확인
4. **비용 관리**: 테스트 후 리소스 정리 (`terraform destroy`)