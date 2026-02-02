# 2025 지방기능경기대회 클라우드컴퓨팅 (AWS)

본 디렉토리는 **2025년도 지방기능경기대회 클라우드컴퓨팅 직종**을 대비하여  
AWS 기반 인프라 설계 및 구축 과정을 단계별로 정리한 저장소입니다.

---

## 📌 목적
- 대회 제1과제(Solution Architecture) 요구사항 분석
- AWS 서비스 기반 인프라 설계 연습
- CLI 및 자동화 스크립트 기반 실전 풀이 정리
- 수업 및 대회 대비 참고 자료로 활용

---

## 🛠 사용 기술 스택
- **Cloud**: AWS (ap-northeast-2)
- **Network**: VPC, Subnet, Routing, IGW, NAT
- **Compute**: EC2, ECS
- **Container**: ECR
- **Load Balancing**: ELB (ALB)
- **Service Discovery**: Cloud Map
- **Database**: DynamoDB
- **Monitoring**: CloudWatch
- **Language**: Go
- **Tool**: AWS CLI, Bash Script

---

## 📂 디렉토리 구조
```text
2025_지방/
├─ README.md              # 과제 개요 및 설명
├─ docs/                  # 문제 분석, 설계 설명
├─ network/               # VPC, Subnet, Routing 구성
├─ compute/               # EC2, ECS 관련 설정
├─ database/              # DynamoDB 설정
├─ scripts/               # 배포 및 검증 스크립트
└─ images/                # 아키텍처 다이어그램
