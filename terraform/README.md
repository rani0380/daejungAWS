# Terraform Practice – AWS Infrastructure with Terraform

이 저장소는 **Terraform Certification Exam Prep** 및  
**AWS 인프라 실습**을 목적으로 작성된 Terraform 예제 프로젝트입니다.

Terraform을 사용하여  
VPC, Subnet, Security Group, Internet/NAT Gateway, Route Table, Module 구조까지  
**점진적으로 확장되는 AWS 인프라**를 구성합니다.

---

## 📌 프로젝트 목표

- Terraform 기본 문법 및 Workflow 이해
- AWS 표준 네트워크 아키텍처 구현
- Terraform Module 구조 및 재사용 패턴 학습
- Terraform 자격증 시험 대비
- 실무 수준의 IaC(Infrastructure as Code) 구조 경험

---

## 🧱 아키텍처 개요

본 프로젝트에서는 다음과 같은 인프라를 구성합니다.

- VPC (10.0.0.0/16)
- Public Subnet (AZ 1)
- Private Subnet (AZ 2)
- Internet Gateway
- NAT Gateway
- Public / Private Route Tables
- Public / Private Security Groups
- EC2 Instance (Module 기반 배포)
- Terraform Module 구조 적용

---

## 📂 디렉터리 구조

