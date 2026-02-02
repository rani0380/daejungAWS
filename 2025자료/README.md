# ☁️ Cloud Computing 기능경기대회 풀이 아카이브

본 저장소는 **기능경기대회 클라우드컴퓨팅 직종**을 대비하며  
AWS 기반 인프라 설계 및 서비스 구축 문제를 풀이·정리한 포트폴리오 아카이브입니다.

---

## 📌 아카이브 목적
- 기능경기대회 **문제 해결 과정 기록**
- 채점 기준 기반 **설계 의도 및 구현 근거 정리**
- 학생 지도 및 대회 대비 **학습 자료 축적**

---

## 🧱 풀이 구성 체계

### 1️⃣ Network
- VPC, IGW, Route Table
- Security Group
- Network Firewall, GWLBe 라우팅

📂 `01_network/`

---

### 2️⃣ Compute
- EC2 인스턴스 구성
- Bastion Host 설계 및 접근 제어

📂 `02_compute/`

---

### 3️⃣ Container & Application
- Docker 환경 구성
- Golang 애플리케이션 컨테이너화
- ECR 이미지 관리
- ECS Fargate 서비스 배포
- ALB 연동

📂 `03_container/`

---

### 4️⃣ Monitoring
- CloudWatch Logs
- ECS Task 로그 분석

📂 `04_monitoring/`

---

## 🏆 대회별 문제풀이

### 2024 지방기능경기대회
- 문제 요약
- 주요 감점 포인트
- 풀이 전략

📂 `competition/2024_local/`

### 2025 지방기능경기대회
- Solution Architecture 기반 설계
- 실전 구성 흐름 정리

📂 `competition/2025_local/`

---

## 🧠 학습 및 연구 노트
- EC2 / Docker / Lambda
- Terraform 실습 정리

📂 `study_notes/`

---

## ✍️ 활용 방식
- **Issue**: 문제 단위 풀이 요약 및 에러 기록
- **Repository**: 상세 절차, 설정 파일, 코드 보관
- **Project**: 대회 준비 진행 관리

---

> 본 아카이브는 실습 재현성과 채점 기준 대응을 우선으로 구성됨.
