🚀 2026 클라우드컴퓨팅 제2과제 AWS CLI 풀이

Small Challenge · 4시간 · 4개 문제

📚 목차
Shared Network Storage (EFS)
Query from S3 (Athena)
Fine-grained IAM Policy
MySQL with Lambda
1️⃣ Shared Network Storage (EFS)

📌 구조
EC2 #1 ──┐
         ├── EFS (NFS)
EC2 #2 ──┘
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
2️⃣ Query from S3 (Athena)
📌 구조
S3 → Athena → SQL 결과
1. S3 생성
aws s3 mb s3://<data-bucket>
aws s3 mb s3://<athena-result-bucket>
2. 데이터 업로드
aws s3 cp sample.csv s3://<data-bucket>/data/
3. DB 생성
aws athena start-query-execution \
  --query-string "CREATE DATABASE mydb;"
4. 테이블 생성
CREATE EXTERNAL TABLE mydb.users (
  id INT,
  name STRING,
  age INT,
  city STRING
)
5. 쿼리 실행
SELECT * FROM mydb.users WHERE age > 28;
3️⃣ Fine-grained IAM Policy
📌 핵심: 최소 권한 원칙
1. S3 제한 정책
{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::bucket/*"
}
2. 태그 기반 EC2 정책
"Condition": {
  "StringEquals": {
    "ec2:ResourceTag/Environment": "dev"
  }
}
3. 사용자/역할 연결
aws iam attach-user-policy
4. MFA 정책
"aws:MultiFactorAuthPresent": "false"
4️⃣ MySQL with Lambda
📌 구조
Lambda → RDS MySQL
1. RDS 생성
aws rds create-db-instance \
  --engine mysql \
  --db-instance-class db.t3.micro
2. Lambda 코드
import pymysql

def lambda_handler(event, context):
    conn = pymysql.connect(...)
3. 패키징
pip install pymysql -t .
zip lambda.zip .
4. Lambda 생성
aws lambda create-function \
  --function-name mysql-query-fn
5. 실행
aws lambda invoke ...

✅ 검증

MySQL 버전 반환 확인
⚠️ 시험 꿀팁
변수 먼저 선언
Security Group → Network → Service 순서
이름 태그 필수
리전 고정 (ap-northeast-2)
🎯 핵심 요약 (시험용)
1. 네트워크 확인
2. 보안 설정
3. 리소스 생성
4. 연결
5. 검증
