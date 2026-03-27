#!/bin/bash
# ============================================================
#  2026 지방기능경기대회 — 클라우드컴퓨팅 제1과제
#  WorldPay Solution Architecture 채점 스크립트
#  총점: 60점
#  실행: bash grade.sh <비번호>
# ============================================================

set -euo pipefail

# ── 색상 ─────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── 인자 확인 ─────────────────────────────────────────────────
if [ $# -lt 1 ]; then
  echo -e "${RED}사용법: bash grade.sh <비번호>${NC}"
  echo -e "  예시: bash grade.sh 07"
  exit 1
fi

BINO="$1"
REGION="ap-northeast-2"
TOTAL=0
MAX=60
LOG_FILE="grade_result_${BINO}.txt"

# ── 헬퍼 함수 ────────────────────────────────────────────────
pass() {
  local pts=$1 msg=$2
  echo -e "  ${GREEN}[PASS +${pts}pt]${NC} ${msg}"
  echo "  [PASS +${pts}pt] ${msg}" >> "$LOG_FILE"
  TOTAL=$((TOTAL + pts))
}

fail() {
  local pts=$1 msg=$2
  echo -e "  ${RED}[FAIL  +0pt ]${NC} ${msg} ${YELLOW}(기대: ${pts}점)${NC}"
  echo "  [FAIL  +0pt] ${msg} (기대: ${pts}점)" >> "$LOG_FILE"
}

info() {
  echo -e "  ${CYAN}[INFO ]${NC} $1"
  echo "  [INFO ] $1" >> "$LOG_FILE"
}

section() {
  local title=$1 max=$2
  echo ""
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${BLUE}  $title  [최대 ${max}점]${NC}"
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "" >> "$LOG_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOG_FILE"
  echo "  $title  [최대 ${max}점]" >> "$LOG_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOG_FILE"
}

# ── 헤더 출력 ────────────────────────────────────────────────
{
echo "============================================================"
echo "  2026 지방기능경기대회 클라우드컴퓨팅 제1과제 채점 결과"
echo "  비번호: $BINO  |  채점 시작: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  리전: $REGION"
echo "============================================================"
} | tee "$LOG_FILE"

echo -e "\n${BOLD}비번호 ${CYAN}${BINO}${NC}${BOLD} 채점을 시작합니다...${NC}\n"


# ============================================================
#  SECTION 1 — VPC / Subnet / IGW  [10점]
# ============================================================
section "1. VPC / Subnet / IGW" 10
SEC1=0

# 1-1. VPC 존재 및 Name 태그 (3점)
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=worldpay-vpc" \
            "Name=state,Values=available" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  pass 3 "VPC 'worldpay-vpc' 존재 확인 ($VPC_ID)"
  SEC1=$((SEC1+3))

  # 1-2. Public Subnet 2개 (2점)
  PUB_COUNT=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
              "Name=tag:Name,Values=worldpay-public-*" \
    --query "length(Subnets)" --output text 2>/dev/null || echo "0")
  if [ "$PUB_COUNT" -ge 2 ] 2>/dev/null; then
    pass 2 "Public Subnet 2개 이상 확인 (${PUB_COUNT}개)"
    SEC1=$((SEC1+2))
  else
    fail 2 "Public Subnet 2개 미확인 (현재: ${PUB_COUNT}개, 이름: worldpay-public-*)"
  fi

  # 1-3. Private Subnet 2개 (2점)
  PRI_COUNT=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
              "Name=tag:Name,Values=worldpay-private-*" \
    --query "length(Subnets)" --output text 2>/dev/null || echo "0")
  if [ "$PRI_COUNT" -ge 2 ] 2>/dev/null; then
    pass 2 "Private Subnet 2개 이상 확인 (${PRI_COUNT}개)"
    SEC1=$((SEC1+2))
  else
    fail 2 "Private Subnet 2개 미확인 (현재: ${PRI_COUNT}개, 이름: worldpay-private-*)"
  fi

  # 1-4. IGW 연결 확인 (2점)
  IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
              "Name=tag:Name,Values=worldpay-igw" \
    --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "None")
  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    pass 2 "IGW 'worldpay-igw' VPC 연결 확인 ($IGW_ID)"
    SEC1=$((SEC1+2))
  else
    fail 2 "IGW 미연결 또는 이름 불일치 (기대: worldpay-igw)"
  fi

  # 1-5. Public RT → IGW 라우트 확인 (1점)
  RT_ROUTE=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
              "Name=tag:Name,Values=worldpay-public-rt" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
    --output text 2>/dev/null || echo "None")
  if echo "$RT_ROUTE" | grep -q "igw-"; then
    pass 1 "Public Route Table 0.0.0.0/0 → IGW 라우트 확인"
    SEC1=$((SEC1+1))
  else
    fail 1 "Public Route Table IGW 라우트 미확인"
  fi
else
  fail 10 "VPC 'worldpay-vpc' 미존재 — 이 섹션 전체 0점"
fi
info "섹션 1 소계: ${SEC1}/10점"
TOTAL=$((TOTAL > 0 ? TOTAL : 0))


# ============================================================
#  SECTION 2 — Security Group  [8점]
# ============================================================
section "2. Security Group" 8
SEC2=0

# 2-1. ALB SG (2점)
ALB_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" \
            "Name=tag:Name,Values=worldpay-alb-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
if [ "$ALB_SG" != "None" ] && [ -n "$ALB_SG" ]; then
  # 80 인바운드 확인
  PORT80=$(aws ec2 describe-security-groups --group-ids $ALB_SG \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`].IpRanges[?CidrIp=='0.0.0.0/0'].CidrIp" \
    --output text 2>/dev/null || echo "")
  if [ -n "$PORT80" ]; then
    pass 2 "ALB SG 'worldpay-alb-sg' 포트 80 인바운드 허용 확인"
    SEC2=$((SEC2+2))
  else
    fail 2 "ALB SG 포트 80 인바운드 0.0.0.0/0 미확인"
  fi
else
  fail 2 "ALB SG 'worldpay-alb-sg' 미존재"
fi

# 2-2. Bastion SG (2점)
BASTION_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" \
            "Name=tag:Name,Values=worldpay-bastion-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
if [ "$BASTION_SG" != "None" ] && [ -n "$BASTION_SG" ]; then
  PORT22=$(aws ec2 describe-security-groups --group-ids $BASTION_SG \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges[0].CidrIp" \
    --output text 2>/dev/null || echo "")
  if [ -n "$PORT22" ]; then
    pass 2 "Bastion SG 'worldpay-bastion-sg' 포트 22 인바운드 허용 확인"
    SEC2=$((SEC2+2))
  else
    fail 2 "Bastion SG 포트 22 인바운드 미확인"
  fi
else
  fail 2 "Bastion SG 'worldpay-bastion-sg' 미존재"
fi

# 2-3. App EC2 SG — ALB에서만 8080 허용 (2점)
EC2_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" \
            "Name=tag:Name,Values=worldpay-ec2-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
if [ "$EC2_SG" != "None" ] && [ -n "$EC2_SG" ]; then
  PORT8080=$(aws ec2 describe-security-groups --group-ids $EC2_SG \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`8080\`].UserIdGroupPairs[0].GroupId" \
    --output text 2>/dev/null || echo "")
  if [ -n "$PORT8080" ]; then
    pass 2 "App EC2 SG 포트 8080 ALB SG source 인바운드 확인"
    SEC2=$((SEC2+2))
  else
    fail 2 "App EC2 SG 포트 8080 ALB source 인바운드 미확인"
  fi
else
  fail 2 "App EC2 SG 'worldpay-ec2-sg' 미존재"
fi

# 2-4. RDS SG — EC2에서만 3306 허용 (2점)
RDS_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" \
            "Name=tag:Name,Values=worldpay-rds-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "None")
if [ "$RDS_SG" != "None" ] && [ -n "$RDS_SG" ]; then
  PORT3306=$(aws ec2 describe-security-groups --group-ids $RDS_SG \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`3306\`].UserIdGroupPairs[0].GroupId" \
    --output text 2>/dev/null || echo "")
  if [ -n "$PORT3306" ]; then
    pass 2 "RDS SG 포트 3306 EC2 SG source 인바운드 확인"
    SEC2=$((SEC2+2))
  else
    fail 2 "RDS SG 포트 3306 EC2 source 인바운드 미확인"
  fi
else
  fail 2 "RDS SG 'worldpay-rds-sg' 미존재"
fi
info "섹션 2 소계: ${SEC2}/8점"


# ============================================================
#  SECTION 3 — KMS + Secrets Manager  [8점]
# ============================================================
section "3. KMS + Secrets Manager" 8
SEC3=0

# 3-1. KMS 키 별칭 확인 (3점)
KMS_ALIAS=$(aws kms list-aliases \
  --query "Aliases[?AliasName=='alias/worldpay-rds-key'].AliasName" \
  --output text 2>/dev/null || echo "")
if [ -n "$KMS_ALIAS" ]; then
  KMS_KEY_ID=$(aws kms describe-key \
    --key-id alias/worldpay-rds-key \
    --query "KeyMetadata.KeyId" --output text 2>/dev/null || echo "None")
  KMS_ENABLED=$(aws kms describe-key \
    --key-id alias/worldpay-rds-key \
    --query "KeyMetadata.Enabled" --output text 2>/dev/null || echo "false")
  if [ "$KMS_ENABLED" = "True" ] || [ "$KMS_ENABLED" = "true" ]; then
    pass 3 "KMS 키 'alias/worldpay-rds-key' 활성화 상태 확인 ($KMS_KEY_ID)"
    SEC3=$((SEC3+3))
  else
    fail 3 "KMS 키 비활성화 상태"
  fi
else
  fail 3 "KMS 키 별칭 'alias/worldpay-rds-key' 미존재"
fi

# 3-2. Secrets Manager 시크릿 존재 (3점)
SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id worldpay/db/credentials \
  --query "ARN" --output text 2>/dev/null || echo "None")
if [ "$SECRET_ARN" != "None" ] && [ -n "$SECRET_ARN" ]; then
  pass 2 "Secrets Manager 시크릿 'worldpay/db/credentials' 존재 확인"
  SEC3=$((SEC3+2))

  # 3-3. 시크릿 내용에 username/password 키 포함 확인 (1점)
  SECRET_KEYS=$(aws secretsmanager get-secret-value \
    --secret-id worldpay/db/credentials \
    --query "SecretString" --output text 2>/dev/null || echo "{}")
  if echo "$SECRET_KEYS" | grep -q "username" && echo "$SECRET_KEYS" | grep -q "password"; then
    pass 1 "시크릿에 username/password 키 포함 확인"
    SEC3=$((SEC3+1))
  else
    fail 1 "시크릿에 username/password 키 미포함"
  fi
else
  fail 3 "Secrets Manager 시크릿 'worldpay/db/credentials' 미존재"
fi

# 3-4. KMS로 시크릿 암호화 확인 (2점)
if [ "$SECRET_ARN" != "None" ] && [ -n "$SECRET_ARN" ] && [ -n "$KMS_ALIAS" ]; then
  SECRET_KMS=$(aws secretsmanager describe-secret \
    --secret-id worldpay/db/credentials \
    --query "KmsKeyId" --output text 2>/dev/null || echo "None")
  if [ "$SECRET_KMS" != "None" ] && [ -n "$SECRET_KMS" ]; then
    pass 2 "Secrets Manager KMS 암호화 적용 확인"
    SEC3=$((SEC3+2))
  else
    fail 2 "Secrets Manager KMS 암호화 미적용"
  fi
else
  fail 2 "KMS 또는 시크릿 미존재로 암호화 확인 불가"
fi
info "섹션 3 소계: ${SEC3}/8점"


# ============================================================
#  SECTION 4 — RDS MySQL  [10점]
# ============================================================
section "4. RDS MySQL" 10
SEC4=0

# 4-1. RDS 인스턴스 존재 및 상태 (3점)
RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier worldpay-db \
  --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null || echo "None")
if [ "$RDS_STATUS" = "available" ]; then
  pass 3 "RDS 'worldpay-db' available 상태 확인"
  SEC4=$((SEC4+3))
elif [ "$RDS_STATUS" != "None" ]; then
  info "RDS 상태: $RDS_STATUS (아직 생성 중일 수 있음)"
  fail 3 "RDS 'worldpay-db' available 아님 (현재: $RDS_STATUS)"
else
  fail 3 "RDS 'worldpay-db' 미존재"
fi

# 4-2. MySQL 엔진 확인 (1점)
RDS_ENGINE=$(aws rds describe-db-instances \
  --db-instance-identifier worldpay-db \
  --query "DBInstances[0].Engine" --output text 2>/dev/null || echo "None")
if [ "$RDS_ENGINE" = "mysql" ]; then
  pass 1 "RDS 엔진 MySQL 확인"
  SEC4=$((SEC4+1))
else
  fail 1 "RDS 엔진 미확인 (현재: $RDS_ENGINE)"
fi

# 4-3. 퍼블릭 액세스 비활성화 확인 (2점)
RDS_PUBLIC=$(aws rds describe-db-instances \
  --db-instance-identifier worldpay-db \
  --query "DBInstances[0].PubliclyAccessible" --output text 2>/dev/null || echo "None")
if [ "$RDS_PUBLIC" = "False" ] || [ "$RDS_PUBLIC" = "false" ]; then
  pass 2 "RDS 퍼블릭 액세스 비활성화 확인"
  SEC4=$((SEC4+2))
else
  fail 2 "RDS 퍼블릭 액세스 활성화 상태 (보안 위험)"
fi

# 4-4. KMS 스토리지 암호화 확인 (2점)
RDS_ENCRYPTED=$(aws rds describe-db-instances \
  --db-instance-identifier worldpay-db \
  --query "DBInstances[0].StorageEncrypted" --output text 2>/dev/null || echo "false")
if [ "$RDS_ENCRYPTED" = "True" ] || [ "$RDS_ENCRYPTED" = "true" ]; then
  pass 2 "RDS 스토리지 KMS 암호화 활성화 확인"
  SEC4=$((SEC4+2))
else
  fail 2 "RDS KMS 스토리지 암호화 미적용"
fi

# 4-5. Private 서브넷 배치 확인 (1점)
RDS_SUBNET_GRP=$(aws rds describe-db-instances \
  --db-instance-identifier worldpay-db \
  --query "DBInstances[0].DBSubnetGroup.DBSubnetGroupName" --output text 2>/dev/null || echo "None")
if [ "$RDS_SUBNET_GRP" = "worldpay-db-subnet-group" ]; then
  pass 1 "RDS 서브넷 그룹 'worldpay-db-subnet-group' 확인"
  SEC4=$((SEC4+1))
else
  fail 1 "RDS 서브넷 그룹 불일치 (현재: $RDS_SUBNET_GRP)"
fi

# 4-6. 삭제 보호 확인 (1점)
RDS_DEL_PROT=$(aws rds describe-db-instances \
  --db-instance-identifier worldpay-db \
  --query "DBInstances[0].DeletionProtection" --output text 2>/dev/null || echo "false")
if [ "$RDS_DEL_PROT" = "True" ] || [ "$RDS_DEL_PROT" = "true" ]; then
  pass 1 "RDS 삭제 보호 활성화 확인"
  SEC4=$((SEC4+1))
else
  fail 1 "RDS 삭제 보호 비활성화"
fi
info "섹션 4 소계: ${SEC4}/10점"


# ============================================================
#  SECTION 5 — EC2 (App + Bastion)  [10점]
# ============================================================
section "5. EC2 (App + Bastion)" 10
SEC5=0

# 5-1. App EC2 존재 및 running 상태 (3점)
APP_STATE=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=worldpay-app" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null || echo "None")
if [ "$APP_STATE" = "running" ]; then
  APP_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=worldpay-app" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" --output text)
  pass 3 "App EC2 'worldpay-app' running 상태 확인 ($APP_ID)"
  SEC5=$((SEC5+3))
else
  fail 3 "App EC2 'worldpay-app' running 상태 아님"
fi

# 5-2. App EC2 Private 서브넷 배치 확인 (2점)
if [ -n "${APP_ID:-}" ]; then
  APP_PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $APP_ID \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null || echo "None")
  if [ "$APP_PUBLIC_IP" = "None" ] || [ -z "$APP_PUBLIC_IP" ]; then
    pass 2 "App EC2 퍼블릭 IP 없음 — Private 서브넷 배치 확인"
    SEC5=$((SEC5+2))
  else
    fail 2 "App EC2에 퍼블릭 IP 존재 (Private 서브넷 배치 권장)"
  fi
fi

# 5-3. App EC2 IAM 역할 확인 (1점)
if [ -n "${APP_ID:-}" ]; then
  APP_ROLE=$(aws ec2 describe-instances \
    --instance-ids $APP_ID \
    --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" --output text 2>/dev/null || echo "None")
  if [ "$APP_ROLE" != "None" ] && [ -n "$APP_ROLE" ]; then
    pass 1 "App EC2 IAM 인스턴스 프로파일 연결 확인"
    SEC5=$((SEC5+1))
  else
    fail 1 "App EC2 IAM 인스턴스 프로파일 미연결"
  fi
fi

# 5-4. Bastion EC2 존재 및 running 상태 (2점)
BASTION_STATE=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=worldpay-bastion" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null || echo "None")
if [ "$BASTION_STATE" = "running" ]; then
  BASTION_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=worldpay-bastion" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" --output text)
  pass 2 "Bastion EC2 'worldpay-bastion' running 상태 확인 ($BASTION_ID)"
  SEC5=$((SEC5+2))
else
  fail 2 "Bastion EC2 'worldpay-bastion' running 상태 아님"
fi

# 5-5. Bastion EC2 Public 서브넷 + 퍼블릭 IP 확인 (2점)
if [ -n "${BASTION_ID:-}" ]; then
  BASTION_IP=$(aws ec2 describe-instances \
    --instance-ids $BASTION_ID \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null || echo "None")
  if [ "$BASTION_IP" != "None" ] && [ -n "$BASTION_IP" ]; then
    pass 2 "Bastion EC2 퍼블릭 IP 할당 확인 ($BASTION_IP)"
    SEC5=$((SEC5+2))
  else
    fail 2 "Bastion EC2 퍼블릭 IP 미할당"
  fi
fi
info "섹션 5 소계: ${SEC5}/10점"


# ============================================================
#  SECTION 6 — ALB  [8점]
# ============================================================
section "6. ALB (Application Load Balancer)" 8
SEC6=0

# 6-1. ALB 존재 및 active 상태 (3점)
ALB_STATE=$(aws elbv2 describe-load-balancers \
  --names worldpay-alb \
  --query "LoadBalancers[0].State.Code" --output text 2>/dev/null || echo "None")
if [ "$ALB_STATE" = "active" ]; then
  ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names worldpay-alb \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)
  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names worldpay-alb \
    --query "LoadBalancers[0].DNSName" --output text)
  pass 3 "ALB 'worldpay-alb' active 상태 확인 (DNS: $ALB_DNS)"
  SEC6=$((SEC6+3))
else
  fail 3 "ALB 'worldpay-alb' 미존재 또는 active 아님 (현재: $ALB_STATE)"
fi

# 6-2. internet-facing 타입 확인 (1점)
if [ -n "${ALB_ARN:-}" ]; then
  ALB_SCHEME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query "LoadBalancers[0].Scheme" --output text 2>/dev/null || echo "None")
  if [ "$ALB_SCHEME" = "internet-facing" ]; then
    pass 1 "ALB internet-facing 스킴 확인"
    SEC6=$((SEC6+1))
  else
    fail 1 "ALB 스킴 불일치 (현재: $ALB_SCHEME, 기대: internet-facing)"
  fi
fi

# 6-3. Target Group 존재 및 healthy 타겟 확인 (2점)
TG_ARN=$(aws elbv2 describe-target-groups \
  --names worldpay-tg \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "None")
if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
  HEALTHY=$(aws elbv2 describe-target-health \
    --target-group-arn $TG_ARN \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text 2>/dev/null || echo "0")
  if [ "$HEALTHY" -ge 1 ] 2>/dev/null; then
    pass 2 "Target Group 'worldpay-tg' healthy 타겟 ${HEALTHY}개 확인"
    SEC6=$((SEC6+2))
  else
    fail 2 "Target Group healthy 타겟 없음 (앱 미실행 또는 헬스체크 실패)"
  fi
else
  fail 2 "Target Group 'worldpay-tg' 미존재"
fi

# 6-4. Listener 포트 80 확인 (2점)
if [ -n "${ALB_ARN:-}" ]; then
  LISTENER_PORT=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --query "Listeners[?Port==\`80\`].Port" --output text 2>/dev/null || echo "")
  if [ "$LISTENER_PORT" = "80" ]; then
    pass 2 "ALB HTTP 포트 80 Listener 확인"
    SEC6=$((SEC6+2))
  else
    fail 2 "ALB 포트 80 Listener 미존재"
  fi
fi
info "섹션 6 소계: ${SEC6}/8점"


# ============================================================
#  SECTION 7 — CloudWatch  [6점]
# ============================================================
section "7. CloudWatch" 6
SEC7=0

# 7-1. 로그 그룹 존재 확인 (2점)
LOG_GRP=$(aws logs describe-log-groups \
  --log-group-name-prefix "/worldpay/application" \
  --query "logGroups[0].logGroupName" --output text 2>/dev/null || echo "None")
if [ "$LOG_GRP" = "/worldpay/application" ]; then
  pass 2 "CloudWatch 로그 그룹 '/worldpay/application' 확인"
  SEC7=$((SEC7+2))
else
  fail 2 "CloudWatch 로그 그룹 '/worldpay/application' 미존재"
fi

# 7-2. EC2 CPU 경보 확인 (2점)
CPU_ALARM=$(aws cloudwatch describe-alarms \
  --alarm-names worldpay-cpu-high \
  --query "MetricAlarms[0].AlarmName" --output text 2>/dev/null || echo "None")
if [ "$CPU_ALARM" = "worldpay-cpu-high" ]; then
  CPU_THRESHOLD=$(aws cloudwatch describe-alarms \
    --alarm-names worldpay-cpu-high \
    --query "MetricAlarms[0].Threshold" --output text)
  pass 2 "CloudWatch CPU 경보 'worldpay-cpu-high' 확인 (임계값: ${CPU_THRESHOLD}%)"
  SEC7=$((SEC7+2))
else
  fail 2 "CloudWatch CPU 경보 'worldpay-cpu-high' 미존재"
fi

# 7-3. ALB 5xx 에러 경보 확인 (2점)
ALB_ALARM=$(aws cloudwatch describe-alarms \
  --alarm-names worldpay-alb-5xx \
  --query "MetricAlarms[0].AlarmName" --output text 2>/dev/null || echo "None")
if [ "$ALB_ALARM" = "worldpay-alb-5xx" ]; then
  pass 2 "CloudWatch ALB 5xx 경보 'worldpay-alb-5xx' 확인"
  SEC7=$((SEC7+2))
else
  fail 2 "CloudWatch ALB 5xx 경보 'worldpay-alb-5xx' 미존재"
fi
info "섹션 7 소계: ${SEC7}/6점"


# ============================================================
#  SECTION 8 — 앱 동작 확인 (HTTP 응답)  [8점]
# ============================================================
section "8. 앱 동작 확인 (HTTP 응답)" 8
SEC8=0

if [ -n "${ALB_DNS:-}" ]; then
  # 8-1. ALB /health 엔드포인트 응답 확인 (3점)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 --max-time 15 \
    "http://${ALB_DNS}/health" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    pass 3 "ALB http://${ALB_DNS}/health → HTTP 200 OK"
    SEC8=$((SEC8+3))
  elif [ "$HTTP_CODE" = "000" ]; then
    fail 3 "ALB 응답 없음 (타임아웃 또는 앱 미실행)"
    info "확인: Target Group 헬스체크 상태 및 앱 실행 여부 점검 필요"
  else
    fail 3 "ALB /health HTTP ${HTTP_CODE} (기대: 200)"
  fi

  # 8-2. ALB 루트 / 엔드포인트 응답 확인 (2점)
  HTTP_ROOT=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 --max-time 15 \
    "http://${ALB_DNS}/" 2>/dev/null || echo "000")
  if [ "$HTTP_ROOT" = "200" ] || [ "$HTTP_ROOT" = "301" ] || [ "$HTTP_ROOT" = "302" ]; then
    pass 2 "ALB http://${ALB_DNS}/ → HTTP ${HTTP_ROOT}"
    SEC8=$((SEC8+2))
  else
    fail 2 "ALB 루트 경로 응답 없음 또는 오류 (HTTP ${HTTP_ROOT})"
  fi

  # 8-3. Bastion SSH 접속 가능 확인 (3점)
  if [ -n "${BASTION_IP:-}" ]; then
    SSH_RESULT=$(nc -z -w 5 "$BASTION_IP" 22 2>/dev/null && echo "open" || echo "closed")
    if [ "$SSH_RESULT" = "open" ]; then
      pass 3 "Bastion SSH 포트 22 접속 가능 확인 ($BASTION_IP:22)"
      SEC8=$((SEC8+3))
    else
      fail 3 "Bastion SSH 포트 22 접속 불가 ($BASTION_IP) — 채점 불이익 주의!"
    fi
  else
    fail 3 "Bastion IP 확인 불가 — SSH 접속 테스트 건너뜀"
  fi
else
  fail 8 "ALB DNS 확인 불가 — 앱 동작 확인 전체 0점"
fi
info "섹션 8 소계: ${SEC8}/8점"


# ============================================================
#  최종 결과 출력
# ============================================================
{
echo ""
echo "============================================================"
echo "  최종 채점 결과 요약"
echo "============================================================"
printf "  %-35s %3d / 10점\n" "1. VPC / Subnet / IGW"         "${SEC1:-0}"
printf "  %-35s %3d /  8점\n" "2. Security Group"             "${SEC2:-0}"
printf "  %-35s %3d /  8점\n" "3. KMS + Secrets Manager"      "${SEC3:-0}"
printf "  %-35s %3d / 10점\n" "4. RDS MySQL"                  "${SEC4:-0}"
printf "  %-35s %3d / 10점\n" "5. EC2 (App + Bastion)"        "${SEC5:-0}"
printf "  %-35s %3d /  8점\n" "6. ALB"                        "${SEC6:-0}"
printf "  %-35s %3d /  6점\n" "7. CloudWatch"                 "${SEC7:-0}"
printf "  %-35s %3d /  8점\n" "8. 앱 동작 확인"               "${SEC8:-0}"
echo "------------------------------------------------------------"
FINAL=$(( ${SEC1:-0}+${SEC2:-0}+${SEC3:-0}+${SEC4:-0}+${SEC5:-0}+${SEC6:-0}+${SEC7:-0}+${SEC8:-0} ))
printf "  %-35s %3d / 60점\n" "총점" "$FINAL"
echo "============================================================"
echo "  비번호: $BINO  |  채점 완료: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  결과 파일: $LOG_FILE"
echo "============================================================"
} | tee -a "$LOG_FILE"

# 점수에 따른 색상 출력
if [ "${FINAL:-0}" -ge 54 ]; then
  echo -e "\n${GREEN}${BOLD}  🏆 우수 (${FINAL}/60점)${NC}"
elif [ "${FINAL:-0}" -ge 42 ]; then
  echo -e "\n${YELLOW}${BOLD}  👍 양호 (${FINAL}/60점)${NC}"
else
  echo -e "\n${RED}${BOLD}  📝 추가 작업 필요 (${FINAL}/60점)${NC}"
fi
echo ""
