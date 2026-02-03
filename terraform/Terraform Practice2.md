# Terraform Practice2

# Security Group, NAT Gateway, Internet Gateway, Route Table 구성

Terraform과 HCL 블록에 익숙해졌으므로, 이번 파트에서는 **AWS 네트워크의 핵심 구성 요소**를 Terraform으로 계속 확장한다.

이번 글에서는 다음 리소스를 다룬다.

- Security Group
- Internet Gateway
- NAT Gateway
- Route Table 및 Subnet 연결

---

## 1. Security Group 개요

AWS에서 네트워크 보안을 구성하는 방법은 두 가지가 있다.

- **Security Group**
    - 인스턴스 단위
    - Inbound / Outbound 트래픽 제어
- **Network ACL (NACL)**
    - 서브넷 단위
    - 추가적인 보안 계층

### Terraform 사용 시 주의점

Terraform은 기본적으로 AWS Security Group의 **ALLOW ALL 규칙을 자동으로 생성하지 않는다.**

따라서,

- Outbound ALL 허용
- 필요한 Inbound 규칙을 **명시적으로 작성해야 한다.**

---

## 2. 보안 그룹 설계

이번 구성에서는 **보안 그룹 2개**를 만든다.

### Public Subnet용 Security Group

- Outbound: 전체 허용
- Inbound:
    - SSH (22)
    - HTTP (80)
    - HTTPS (443)

### Private Subnet용 Security Group

- Outbound: 전체 허용
- Inbound:
    - VPC 내부 통신만 허용 (`10.0.0.0/16`)

---

## 3. Public Security Group 생성

### main.tf에 추가

```hcl
# Public Security Group
resource "aws_security_group" "public_sg" {
  name        = "Public Security Group"
  description = "Public internet access"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name      = "Security Group for Public Subnet"
    Terraform = "true"
  }
}

# Outbound ALL
resource "aws_security_group_rule" "public_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_sg.id
}

# SSH
resource "aws_security_group_rule" "public_ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_sg.id
}

# HTTP
resource "aws_security_group_rule" "public_http_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_sg.id
}

# HTTPS
resource "aws_security_group_rule" "public_https_in" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_sg.id
}
```

---

## 4. Private Security Group 생성

```hcl
# Private Security Group
resource "aws_security_group" "private_sg" {
  name        = "Private Security Group"
  description = "Private subnet access"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name      = "Security Group for Private Subnet"
    Terraform = "true"
  }
}

# Outbound ALL
resource "aws_security_group_rule" "private_out" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.private_sg.id
}

# Inbound VPC only
resource "aws_security_group_rule" "private_in" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.private_sg.id
}
```

---

## 5. Security Group ID 출력(Output)

나중에 EC2에서 사용하기 위해 ID를 출력한다.

### outputs.tf

```hcl
output "security_group_public" {
  value = aws_security_group.public_sg.id
}

output "security_group_private" {
  value = aws_security_group.private_sg.id
}
```

---

## 6. 실행 및 검증

```bash
$ terraformfmt
$ terraform validate
$ terraform plan
```

예상 결과:

```
Plan:11to add,0to change,0to destroy.
```

구성 내용:

- VPC 1
- Subnet 2
- Security Group 2
- Security Group Rule 6

```bash
$ terraform apply
```

AWS 콘솔에서 Security Group 및 규칙 생성 확인

---

## 7. Internet Gateway 생성

```hcl
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name      = "demo_igw"
    Terraform = "true"
  }
}
```

---

## 8. NAT Gateway 생성

### NAT Gateway 역할

- Private Subnet 인스턴스의 **Outbound 인터넷 통신**
- 외부 → Private Subnet 접근은 불가

### Elastic IP + NAT Gateway

```hcl
# NAT Gateway EIP
resource "aws_eip" "nat_gateway_eip" {
  vpc = true

  depends_on = [
    aws_internet_gateway.internet_gateway
  ]

  tags = {
    Name      = "demo_nat_gateway"
    Terraform = "true"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name      = "demo_nat_gateway"
    Terraform = "true"
  }
}
```

---

## 9. Route Table 구성

### Public Route Table

- `0.0.0.0/0 → Internet Gateway`

```hcl
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}
```

### Private Route Table

- `0.0.0.0/0 → NAT Gateway`

```hcl
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}
```

---

## 10. 최종 실행 계획 확인

```bash
$ terraform plan
```

예상 결과:

```
Plan:18to add,0to change,0to destroy.
```

---

## 11. 파트 2 정리

이번 파트에서 완료한 항목:

- Public / Private Security Group
- Internet Gateway
- NAT Gateway + Elastic IP
- Public / Private Route Table
- Subnet별 Route Table 연결