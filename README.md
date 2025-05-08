## ✅ 1. 과제 개요: 필수 인프라 구성 (Terraform)

### 🌐 네트워크 구성  
Hub VPC (IGW + Public Subnet)  
App VPC (NAT GW + Private Subnet + DB Subnet)

### 🧱 인프라 구성 요소  
- EC2 (Bastion)  
- ECS (Green/Red App)  
- ECR (이미지 저장소)  
- RDS or Aurora (MySQL)  
- ALB (Internal)  
- NLB (External)  
- Secret Manager  
- CloudWatch

### 📁 프로젝트 구조  
![image](https://github.com/user-attachments/assets/9bdcc542-530f-4797-9d7b-a85991f4a3f5)

