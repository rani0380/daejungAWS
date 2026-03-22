# WorldPay 유저 관리 시스템 아키텍처

## 시스템 개요

WorldPay 유저 관리 시스템은 전 세계 결제 서비스를 위한 고가용성, 보안, 확장성을 갖춘 마이크로서비스 아키텍처입니다.

## 핵심 설계 원칙

### 1. 고가용성 (High Availability)
- **Multi-AZ 배포**: 모든 컴포넌트가 최소 2개 가용 영역에 분산
- **Auto Scaling**: 트래픽에 따른 자동 확장/축소
- **Health Check**: 애플리케이션 및 인프라 상태 모니터링

### 2. 보안 (Security)
- **네트워크 격리**: VPC, 서브넷, 보안 그룹을 통한 계층별 보안
- **암호화**: 전송 중/저장 중 데이터 암호화
- **비밀 관리**: AWS Secrets Manager를 통한 민감 정보 관리
- **최소 권한**: IAM 역할 기반 최소 권한 원칙

### 3. 확장성 (Scalability)
- **컨테이너화**: Docker 기반 마이크로서비스
- **서버리스**: AWS Fargate를 통한 서버 관리 불필요
- **로드 밸런싱**: Application Load Balancer를 통한 트래픽 분산

## 인프라 구성

### 네트워크 아키텍처
```
Internet Gateway
    ↓
Public Subnet (Multi-AZ)
    ↓ (ALB)
Private Subnet (Multi-AZ)
    ↓ (ECS Fargate)
Database Subnet (Multi-AZ)
    ↓ (RDS PostgreSQL)
```

### 컴포넌트 구성
- **VPC**: 10.0.0.0/16 CIDR 블록
- **퍼블릭 서브넷**: ALB 배치 (10.0.1.0/24, 10.0.2.0/24)
- **프라이빗 서브넷**: ECS 서비스 배치 (10.0.10.0/24, 10.0.11.0/24)
- **데이터베이스 서브넷**: RDS 배치 (10.0.20.0/24, 10.0.21.0/24)

## 애플리케이션 아키텍처

### API 엔드포인트
- `POST /users`: 사용자 생성
- `GET /users/{id}`: 사용자 조회
- `GET /health`: 헬스 체크

### 데이터베이스 설계
- **users 테이블**: 사용자 기본 정보
- **인덱스**: 이메일, 사용자명 검색 최적화
- **트리거**: 자동 업데이트 시간 관리

## 보안 고려사항

1. **비밀번호 암호화**: bcrypt 해싱
2. **데이터베이스 암호화**: RDS 저장 암호화 활성화
3. **네트워크 보안**: 보안 그룹을 통한 포트 제한
4. **접근 제어**: IAM 역할 기반 권한 관리

## 모니터링 및 로깅

- **CloudWatch Logs**: 애플리케이션 로그 수집
- **Container Insights**: ECS 클러스터 모니터링
- **Health Check**: ALB 및 ECS 서비스 상태 확인

## 배포 가이드

1. Terraform 초기화: `terraform init`
2. 변수 설정: `terraform.tfvars` 파일 생성
3. 인프라 배포: `terraform apply`
4. Docker 이미지 빌드 및 푸시
5. ECS 서비스 업데이트