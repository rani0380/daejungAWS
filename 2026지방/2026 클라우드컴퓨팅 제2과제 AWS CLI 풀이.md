🚀 2026 클라우드컴퓨팅 제2과제 AWS CLI 풀이

Small Challenge · 4시간 · 4개 문제

📚 목차
Shared Network Storage (EFS)
Query from S3 (Athena)
Fine-grained IAM Policy
MySQL with Lambda
1️⃣ Shared Network Storage (EFS)\
📌 구조 다이어그램\
        ┌────────────┐
        │   EC2 #1   │
        └─────┬──────┘
              │
              │ (NFS)
              ▼
        ┌────────────┐
        │    EFS     │
        └─────┬──────┘
              │
              ▼
        ┌────────────┐
        │   EC2 #2   │
        └────────────┘

👉 두 EC2가 동일한 EFS를 공유

1. VPC & Subnet 확인
aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query "Vpcs[0].VpcId" \
  --output text

aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=<vpc-id> \
  --query "Subnets[*].[SubnetId,AvailabilityZone]" \
  --output table
2. EFS Security Group 생성
aws ec2 create-security-group \
  --group-name efs-sg \
  --description "Security group for EFS" \
  --vpc-id <vpc-id>

aws ec2 authorize-security-group-ingress \
  --group-id <efs-sg-id> \
  --protocol tcp \
  --port 2049 \
  --source-group <ec2-sg-id>
3. EFS 생성
aws efs create-file-system \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --encrypted \
  --tags Key=Name,Value=shared-efs
4. Mount Target 생성
aws efs create-mount-target \
  --file-system-id <efs-id> \
  --subnet-id <subnet-id-1> \
  --security-groups <efs-sg-id>
5. EC2에서 마운트
sudo yum install -y amazon-efs-utils
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls <efs-id>:/ /mnt/efs

✅ 검증

EC2 간 파일 공유 확인
