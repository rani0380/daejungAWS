✅ 1. 과제 개요: 필수 인프라 구성 (Terraform)
🌐 네트워크 구성
Hub VPC (IGW + Public Subnet)
App VPC (NAT GW + Private Subnet + DB Subnet)

🧱 인프라 구성 요소
EC2 (Bastion)
ECS (Green/Red App)
ECR (이미지 저장소)
RDS or Aurora (MySQL)
ALB (Internal)
NLB (External)
Secret Manager
CloudWatch

📁 프로젝트 구조
terraform-project/
├── provider.tf            # AWS Provider 설정
├── vpc.tf                 # VPC, Subnet, IGW, NATGW 구성
├── security_groups.tf     # 보안 그룹
├── bastion.tf             # EC2: Bastion Host
├── ecr.tf                 # ECR Repository
├── ecs.tf                 # ECS Cluster & Task & Service
├── alb.tf                 # ALB (internal), NLB (external)
├── rds.tf                 # RDS MySQL
├── secrets.tf             # Secrets Manager 구성
└── variables.tf           # 변수 선언
