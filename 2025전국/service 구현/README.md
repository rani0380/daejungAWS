# ✅ ECR 이미지 Push 및 서비스 구현 완료

본 프로젝트는 **최소 코드 기반 서비스 구현 + 자동화 스크립트**를 통해  
기능경기대회 클라우드컴퓨팅 과제 요구사항을 충족합니다.
---

## 📦 생성된 구성 요소

### 🔧 서비스 구현 (최소 코드)

- **User Service**
  - RDS MySQL 연결
  - `/healthcheck` 엔드포인트 제공

- **Product Service**
  - DynamoDB 연결
  - `/healthcheck` 엔드포인트 제공

- **Stress Service**
  - CPU 부하 테스트 로직 구현
  - `/healthcheck` 엔드포인트 제공

---

## 🚀 배포 자동화 스크립트

| 파일명 | 설명 |
|------|------|
| `push-images.bat` | Windows 환경용 ECR 이미지 Push |
| `push-images.sh` | Linux / macOS 환경용 ECR 이미지 Push |
| `deploy.sh` | 전체 배포 자동화 (이미지 Push + Terraform Apply) |
| `cleanup.sh` | 생성된 AWS 리소스 정리 |

---

## 📋 핵심 해결 사항

- **ECR 이미지 Push**
  - 자동화 스크립트로 반복 작업 제거

- **Health Check**
  - 모든 서비스에 `/healthcheck` 구현

- **DB 연결**
  - 환경 변수 기반으로 RDS / DynamoDB 자동 연결

- **비용 관리**
  - `cleanup.sh` 실행 시 원클릭 리소스 정리

---

## 🎯 배포 순서

```bash
# Windows
push-images.bat
terraform init
terraform apply -auto-approve
# Linux / macOS
chmod +x deploy.sh
./deploy.sh
