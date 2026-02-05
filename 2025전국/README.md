
1️⃣ 전체 아키텍처 개요
🔹 핵심 구성

ECS on EC2

인스턴스 타입: t3.medium (대회 조건 강제)

Auto Scaling Group 기반 고가용성

Application Load Balancer

단일 엔드포인트

경로 기반 라우팅

RDS MySQL

MySQL 8.0

Multi-AZ

db.t3.micro, gp3

DynamoDB

PAY_PER_REQUEST

product 테이블 단일 구성

CloudWatch Logs

ECS 서비스별 로그 그룹 분리

(옵션) AWS WAF

403 / 404 구분 처리용 보조 정책

````2️⃣ 디렉토리 구조 역할 정리
skills-task3/
├─ versions.tf        # Terraform / Provider 버전 고정
├─ providers.tf       # AWS 리전 설정
├─ variables.tf       # 대회 조건을 반영한 변수 정의
├─ locals.tf          # 태그, 로그 그룹, 공통 포트
├─ vpc.tf             # VPC, Subnet, Routing
├─ security.tf        # ALB / ECS / RDS 보안그룹
├─ iam.tf             # ECS Instance / Task IAM 역할
├─ ecr.tf             # user / product / stress ECR
├─ ecs_cluster_ec2.tf # ECS Cluster + ASG + Capacity Provider
├─ ecs_tasks.tf       # Task Definition + Log Group
├─ ecs_services.tf    # ECS Service (user/product/stress)
├─ alb.tf             # ALB + Target Group + Listener Rule
├─ rds.tf             # RDS MySQL Multi-AZ
├─ dynamodb.tf        # DynamoDB Table
├─ waf.tf             # (옵션) WAF 403 제어
├─ monitoring.tf      # (선택) CloudWatch Alarm
└─ outputs.tf         # 배포 결과 출력
