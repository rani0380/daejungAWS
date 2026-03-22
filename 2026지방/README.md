# 🌍 WorldPay User Management System

엔터프라이즈급 결제 서비스를 위한 **유저 관리 시스템 인프라 및 서비스 구현 프로젝트**

---

## 📌 Overview

WorldPay는 전 세계 사용자들의 결제 서비스를 지원하는 플랫폼으로,  
본 시스템은 **고가용성, 보안성, 확장성**을 고려하여 설계되었습니다.

---

## 🏗️ Architecture Features

### ✅ High Availability (고가용성)
- Multi-AZ 기반 배포로 장애 발생 시 자동 복구
- Auto Scaling을 통한 트래픽 변화 대응
- Application Load Balancer(ALB)를 통한 트래픽 분산

---

### 🔐 Security (보안)
- VPC 기반 네트워크 격리
- Security Group을 통한 포트 접근 제어
- RDS 암호화 적용
- AWS Secrets Manager를 통한 민감 정보 관리
- bcrypt 기반 비밀번호 해싱

---

### 🚀 Scalability (확장성)
- ECS Fargate 기반 서버리스 컨테이너 운영
- 마이크로서비스 아키텍처 적용
- 데이터베이스 자동 확장 설정

---

## 📂 Project Structure

```bash
.
├── infrastructure/        # Terraform 기반 인프라 코드
├── src/
│   └── main.go           # Go 기반 사용자 관리 API
├── config/
│   └── init.sql          # DB 초기화 스크립트
├── docs/
│   └── architecture.md   # 아키텍처 상세 문서
├── Dockerfile            # 컨테이너 이미지 정의
└── README.md
