#!/bin/bash
export AWS_PAGER=""
REGION="ap-northeast-2"

# ============================================================
# 0. 기본 변수
# ============================================================
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "Account: $AWS_ACCOUNT_ID"

# ============================================================
# 1. VPC / Subnet / IGW / RT (10점)
# ============================================================
export VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=worldpay-vpc
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
echo "VPC: $VPC_ID"

# AZ
AZ1=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
AZ2=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text)

# Public Subnets
export PUB_SUB1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone $AZ1 --query 'Subnet.SubnetId' --output text)
export PUB_SUB2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone $AZ2 --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PUB_SUB1 --tags Key=Name,Value=worldpay-public-1
aws ec2 create-tags --resources $PUB_SUB2 --tags Key=Name,Value=worldpay-public-2
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB2 --map-public-ip-on-launch

# Private Subnets
export PRI_SUB1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 --availability-zone $AZ1 --query 'Subnet.SubnetId' --output text)
export PRI_SUB2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.12.0/24 --availability-zone $AZ2 --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $PRI_SUB1 --tags Key=Name,Value=worldpay-private-1
aws ec2 create-tags --resources $PRI_SUB2 --tags Key=Name,Value=worldpay-private-2

# IGW
export IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=worldpay-igw
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Public Route Table
export PUB_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources $PUB_RT --tags Key=Name,Value=worldpay-public-rt
aws ec2 create-route --route-table-id $PUB_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_SUB1
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_SUB2

echo "=== 섹션1 완료: VPC/Subnet/IGW/RT ==="

# ============================================================
# 2. Security Groups (8점)
# ============================================================
# ALB SG - 80 from 0.0.0.0/0
export ALB_SG=$(aws ec2 create-security-group --group-name worldpay-alb-sg --description "ALB SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $ALB_SG --tags Key=Name,Value=worldpay-alb-sg
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

# Bastion SG - 22 from 0.0.0.0/0
export BASTION_SG=$(aws ec2 create-security-group --group-name worldpay-bastion-sg --description "Bastion SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $BASTION_SG --tags Key=Name,Value=worldpay-bastion-sg
aws ec2 authorize-security-group-ingress --group-id $BASTION_SG --protocol tcp --port 22 --cidr 0.0.0.0/0

# EC2 App SG - 8080 from ALB SG
export EC2_SG=$(aws ec2 create-security-group --group-name worldpay-ec2-sg --description "App EC2 SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $EC2_SG --tags Key=Name,Value=worldpay-ec2-sg
aws ec2 authorize-security-group-ingress --group-id $EC2_SG --protocol tcp --port 8080 --source-group $ALB_SG

# RDS SG - 3306 from EC2 SG
export RDS_SG=$(aws ec2 create-security-group --group-name worldpay-rds-sg --description "RDS SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 create-tags --resources $RDS_SG --tags Key=Name,Value=worldpay-rds-sg
aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 3306 --source-group $EC2_SG

echo "=== 섹션2 완료: SG 4개 ==="

# ============================================================
# 3. KMS + Secrets Manager (8점)
# ============================================================
export KMS_KEY_ID=$(aws kms create-key --description "WorldPay RDS encryption key" --query 'KeyMetadata.KeyId' --output text)
aws kms create-alias --alias-name alias/worldpay-rds-key --target-key-id $KMS_KEY_ID

aws secretsmanager create-secret \
  --name worldpay/db/credentials \
  --kms-key-id alias/worldpay-rds-key \
  --secret-string '{"username":"admin","password":"WorldPay2026!"}'

echo "=== 섹션3 완료: KMS + Secrets Manager ==="

# ============================================================
# 4. RDS MySQL (10점) — 먼저 시작! 5~10분 소요
# ============================================================
aws rds create-db-subnet-group \
  --db-subnet-group-name worldpay-db-subnet-group \
  --db-subnet-group-description "WorldPay DB subnet group" \
  --subnet-ids $PRI_SUB1 $PRI_SUB2

aws rds create-db-instance \
  --db-instance-identifier worldpay-db \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --master-username admin \
  --master-user-password "WorldPay2026!" \
  --allocated-storage 20 \
  --vpc-security-group-ids $RDS_SG \
  --db-subnet-group-name worldpay-db-subnet-group \
  --no-publicly-accessible \
  --storage-encrypted \
  --kms-key-id $KMS_KEY_ID \
  --deletion-protection \
  --no-multi-az

echo "=== 섹션4: RDS 생성 시작 (백그라운드 5~10분) ==="

# ============================================================
# 5. EC2 — App + Bastion (10점)
# ============================================================
# AMI 조회
export AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)

# App EC2 IAM Role
aws iam create-role --role-name worldpay-app-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]
  }'
aws iam attach-role-policy --role-name worldpay-app-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam attach-role-policy --role-name worldpay-app-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
aws iam create-instance-profile --instance-profile-name worldpay-app-profile
aws iam add-role-to-instance-profile --instance-profile-name worldpay-app-profile --role-name worldpay-app-role
echo "IAM Profile 전파 대기..."
sleep 10

# App EC2 (Private subnet, 8080에서 간단한 웹서버)
export APP_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --subnet-id $PRI_SUB1 \
  --security-group-ids $EC2_SG \
  --iam-instance-profile Name=worldpay-app-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=worldpay-app}]' \
  --user-data '#!/bin/bash
yum install -y python3
cat <<PYEOF > /home/ec2-user/app.py
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type","application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status":"healthy"}).encode())
        else:
            self.send_response(200)
            self.send_header("Content-Type","text/html")
            self.end_headers()
            self.wfile.write(b"<h1>WorldPay Application</h1>")
    def log_message(self, format, *args):
        pass

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
PYEOF
nohup python3 /home/ec2-user/app.py &
' \
  --query 'Instances[0].InstanceId' --output text)
echo "App EC2: $APP_ID"

# Key Pair 생성 (Bastion SSH용)
aws ec2 create-key-pair --key-name worldpay-key --query 'KeyMaterial' --output text > /tmp/worldpay-key.pem
chmod 400 /tmp/worldpay-key.pem

# Bastion EC2 (Public subnet)
export BASTION_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --subnet-id $PUB_SUB1 \
  --security-group-ids $BASTION_SG \
  --key-name worldpay-key \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=worldpay-bastion}]' \
  --query 'Instances[0].InstanceId' --output text)
echo "Bastion EC2: $BASTION_ID"

echo "=== 섹션5 완료: EC2 App + Bastion ==="

# ============================================================
# 6. ALB + Target Group + Listener (8점)
# ============================================================
# ALB
export ALB_ARN=$(aws elbv2 create-load-balancer \
  --name worldpay-alb \
  --subnets $PUB_SUB1 $PUB_SUB2 \
  --security-groups $ALB_SG \
  --scheme internet-facing \
  --type application \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
echo "ALB: $ALB_ARN"

# Target Group
export TG_ARN=$(aws elbv2 create-target-group \
  --name worldpay-tg \
  --protocol HTTP --port 8080 \
  --vpc-id $VPC_ID \
  --target-type instance \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

# 타겟 등록
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$APP_ID

# Listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

echo "=== 섹션6 완료: ALB + TG + Listener ==="

# ============================================================
# 7. CloudWatch (6점)
# ============================================================
# 로그 그룹
aws logs create-log-group --log-group-name /worldpay/application

# CPU 경보
aws cloudwatch put-metric-alarm \
  --alarm-name worldpay-cpu-high \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=InstanceId,Value=$APP_ID

# ALB 5xx 경보
ALB_FULL=$(aws elbv2 describe-load-balancers --names worldpay-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_SUFFIX=$(echo $ALB_FULL | sed 's|.*loadbalancer/||')

aws cloudwatch put-metric-alarm \
  --alarm-name worldpay-alb-5xx \
  --metric-name HTTPCode_ELB_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=LoadBalancer,Value=$ALB_SUFFIX \
  --treat-missing-data notBreaching

echo "=== 섹션7 완료: CloudWatch ==="

# ============================================================
# 8. RDS 대기 & 최종 확인
# ============================================================
echo ""
echo "RDS 생성 대기중... (5~10분 소요)"
aws rds wait db-instance-available --db-instance-identifier worldpay-db
echo "RDS available!"

# ALB DNS 확인
ALB_DNS=$(aws elbv2 describe-load-balancers --names worldpay-alb --query 'LoadBalancers[0].DNSName' --output text)
echo ""
echo "============================================"
echo "  전체 인프라 구성 완료!"
echo "  ALB DNS: http://$ALB_DNS"
echo "  /health 테스트: curl http://$ALB_DNS/health"
echo "============================================"
