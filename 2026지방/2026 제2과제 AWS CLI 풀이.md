# 🚀 2026 클라우드컴퓨팅 제2과제 AWS CLI 풀이

> 시험 대비용 5단계 구조 정리  
> 환경 설정 → 보안 → 리소스 생성 → 연결 → 검증

---

# ⚙️ STEP 0: 환경 설정

```bash
# Account ID 확인
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "Account ID: $AWS_ACCOUNT_ID"

# VPC / Subnet 환경변수
export VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

export SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].SubnetId' \
  --output text)

export SUBNET_ID1=$(echo $SUBNET_IDS | awk '{print $1}')
export SUBNET_ID2=$(echo $SUBNET_IDS | awk '{print $2}')

echo "VPC: $VPC_ID / Subnet1: $SUBNET_ID1 / Subnet2: $SUBNET_ID2"
```

---

# 1️⃣ 문제 1: EFS (5 Steps)

## 📌 구조
```text
EC2 #1  ────┐
            ├── EFS (NFS)
EC2 #2  ────┘
```

---

## 1) Security Group 생성

```bash
export EFS_SG=$(aws ec2 create-security-group \
  --group-name efs-sg \
  --description "EFS access" \
  --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $EFS_SG \
  --protocol tcp --port 2049 --cidr 0.0.0.0/0
```

---

## 2) EFS 생성

```bash
export EFS_ID=$(aws efs create-file-system \
  --creation-token my-efs \
  --performance-mode generalPurpose \
  --query 'FileSystemId' --output text)

echo "EFS: $EFS_ID"
```

---

## 3) Mount Target 생성

```bash
aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $SUBNET_ID1 \
  --security-groups $EFS_SG
```

---

## 4) EC2에서 마운트

```bash
export INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "sudo yum install -y amazon-efs-utils",
    "sudo mkdir -p /mnt/efs",
    "sudo mount -t efs '"$EFS_ID"':/ /mnt/efs",
    "df -h /mnt/efs"
  ]'
```

---

## 5) 공유 검증

```bash
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo hello-efs | sudo tee /mnt/efs/test.txt",
    "cat /mnt/efs/test.txt"
  ]'
```

---

# 2️⃣ 문제 2: S3 + Athena (5 Steps)

## 1) S3 생성

```bash
export BUCKET_NAME="athena-lab-${AWS_ACCOUNT_ID}"
aws s3 mb s3://$BUCKET_NAME
```

---

## 2) CSV 업로드

```bash
cat <<'EOF' > /tmp/employees.csv
id,name,department,salary
1,Kim,Engineering,80000
2,Lee,Marketing,70000
3,Park,Engineering,90000
4,Choi,Sales,60000
5,Jung,Marketing,75000
EOF

aws s3 cp /tmp/employees.csv s3://$BUCKET_NAME/data/employees.csv
```

---

## 3) Athena 설정

```bash
export RESULT_BUCKET="athena-results-${AWS_ACCOUNT_ID}"
aws s3 mb s3://$RESULT_BUCKET

aws athena create-work-group \
  --name my-workgroup \
  --configuration "ResultConfiguration={OutputLocation=s3://$RESULT_BUCKET/}"
```

---

## 4) 테이블 생성

```bash
aws athena start-query-execution \
  --query-string "
    CREATE EXTERNAL TABLE IF NOT EXISTS employees (
      id INT, name STRING, department STRING, salary INT
    )
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
    LOCATION 's3://$BUCKET_NAME/data/'
  " \
  --work-group my-workgroup
```

---

## 5) 쿼리 실행

```bash
aws athena start-query-execution \
  --query-string "SELECT * FROM employees;" \
  --work-group my-workgroup
```

---

# 3️⃣ 문제 3: IAM Policy (5 Steps)

## 1) Policy 생성

```bash
cat <<'EOF' > /tmp/policy-a.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "*"
    }
  ]
}
EOF
```

---

## 2) IAM 사용자 생성

```bash
aws iam create-user --user-name lab-user
```

---

## 3) 정책 연결

```bash
aws iam attach-user-policy \
  --user-name lab-user \
  --policy-arn <POLICY_ARN>
```

---

## 4) 시뮬레이션

```bash
aws iam simulate-principal-policy \
  --policy-source-arn <USER_ARN> \
  --action-names s3:GetObject
```

---

# 4️⃣ 문제 4: RDS + Lambda (5 Steps)

## 1) RDS 생성

```bash
aws rds create-db-instance \
  --db-instance-identifier my-lab-db \
  --engine mysql \
  --db-instance-class db.t3.micro
```

---

## 2) Lambda 역할 생성

```bash
aws iam create-role \
  --role-name lambda-rds-role \
  --assume-role-policy-document file:///tmp/lambda-trust.json
```

---

## 3) Lambda 코드

```python
def lambda_handler(event, context):
    return {"statusCode": 200}
```

---

## 4) Lambda 생성

```bash
aws lambda create-function \
  --function-name rds-connector
```

---

## 5) 실행

```bash
aws lambda invoke \
  --function-name rds-connector \
  output.json
```

---

# 🎯 시험 핵심 암기

```
1. 환경변수
2. 보안(SG/IAM)
3. 리소스 생성
4. 연결
5. 검증
```

---

# 🔥 특징

- 시험용 구조 최적화
- CLI 그대로 복붙 가능
- GitHub 깨짐 없음
- 단계별 암기 가능
