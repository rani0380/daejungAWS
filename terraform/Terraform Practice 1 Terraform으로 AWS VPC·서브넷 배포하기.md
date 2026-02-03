# Terraform Practice 1: Terraform으로 AWS VPC·서브넷 배포하기

## 1. 목표 인프라(구성 목표)

이번 실습에서 만들고자 하는 Terraform 구성 목표는 다음과 같다.

![image.png](Terraform%20Practice%201%20Terraform%EC%9C%BC%EB%A1%9C%20AWS%20VPC%C2%B7%EC%84%9C%EB%B8%8C%EB%84%B7%20%EB%B0%B0%ED%8F%AC%ED%95%98%EA%B8%B0/image.png)

### 필수 목표

https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

1. **VPC 생성**
    - CIDR: `10.0.0.0/16`
2. **퍼블릭 서브넷 1개 생성**
    - AZ 1에 생성
    - CIDR: `10.0.0.0/24`
    - 인터넷 게이트웨이로 향하는 라우팅이 포함된 라우트 테이블과 연결
3. **프라이빗 서브넷 1개 생성**
    - AZ 2에 생성
    - CIDR: `10.0.1.0/24`
4. **각 서브넷별 보안 그룹 분리 구성**
5. **퍼블릭 서브넷에 웹 서버 EC2 3대 생성**
    - AZ 1, 퍼블릭 서브넷 범위 내
    - 각 인스턴스에 Elastic IPv4 연결
    - 인터넷에서 접속 가능해야 함
    - Docker 설치 및 GitHub 저장소 코드 클론
6. **퍼블릭 서브넷에 NAT Gateway 생성**
    - NAT Gateway용 Elastic IPv4 포함
7. **프라이빗 서브넷에 DB EC2 3대 생성**
    - AZ 2, 프라이빗 서브넷 범위 내
    - NAT Gateway를 통해 인터넷으로 요청 가능해야 함
8. **서브넷별 라우트 테이블 구성**
    - 퍼블릭: IGW 라우팅
    - 프라이빗: NAT Gateway 라우팅
9. **인터넷 게이트웨이 생성**
    - VPC를 인터넷 및 AWS 서비스와 연결
10. **프라이빗 서브넷에 메인 라우트 테이블 연결**
    - VPC 내부 IPv4 통신 경로 포함
    - NAT Gateway를 통한 인터넷 통신 경로 포함

### 선택 목표(옵션)

- 퍼블릭 서브넷 인스턴스에 대한 서브도메인 생성
- URL, 퍼블릭 IP 등 정보를 보기 좋게 출력(Output)

※ **파트 1: VPC 및 서브넷 배포**까지 다룬다.

다음 파트에서 라우트 테이블, NAT Gateway, IGW를 구성할 예정이다.

---

# Part 1. 초기 세팅

프로젝트 폴더를 만들고, Terraform 기본 파일 3개를 생성한다.

```bash
$mkdir terraform-practice
$cd terraform-practice
$touch main.tf variables.tf outputs.tf
```

---

# Part 2. Terraform 설정(terraform block)

사용할 Terraform 및 AWS Provider 버전을 고정하기 위해 `terraform.tf` 파일을 별도로 만든다.

`terraform.tf` 파일을 만들고 아래 코드를 입력한다.

```hcl
# terraform.tf

terraform {
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }
  required_version = ">= 0.14.9"
}
```

이제 Terraform 초기화를 수행한다.

```bash
$ terraform init
```

정상 출력 예시:

```
Terraform has been successfully initialized!
```

---

# Part 3. 리전, VPC, 서브넷 구성

이번 실습에서는 좋은 습관으로 **variable 블록**을 활용해 설정 값을 분리한다.

프로젝트가 진행되면서 변수를 추가해 나갈 예정이다.

## 3-1. variables.tf 작성

`variables.tf`에 아래 내용을 입력한다.

```hcl
# variables.tf

variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "vpc_name" {
  type    = string
  default = "TerraformCertPrep_vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet" {
  default = {
    "public_subnet_1" = 1
  }
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet" {
  default = {
    "private_subnet_1" = 1
  }
}
```

---

## 3-2. main.tf 작성(VPC + Subnet 리소스)

이제 실제 리소스를 정의한다. 코드는 `main.tf`에 작성한다.

```c
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "public" {
  name   = "public-sg"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private" {
  name   = "private-sg"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "web" {
  count    = 3
  domain   = "vpc"
  instance = aws_instance.web[count.index].id
}

resource "aws_instance" "web" {
  count                  = 3
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker git
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    git clone https://github.com/your-repo/your-project.git /home/ec2-user/project
  EOF
}

resource "aws_instance" "db" {
  count                  = 3
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id]
}

```

### 코드 포인트 정리

- `data "aws_availability_zones"`를 사용해 가용 영역 목록을 조회하고
    - 퍼블릭 서브넷은 첫 번째 AZ
    - 프라이빗 서브넷은 두 번째 AZ
        
        에 배치한다.
        
- `map_public_ip_on_launch = true`
    
    → 퍼블릭 서브넷에 생성되는 인스턴스가 기본적으로 퍼블릭 IP를 할당받도록 설정한다.
    

---

# 4. 실행 전 점검(fmt, validate)

서식 정리 및 문법 점검을 수행한다.

```bash
$ terraform fmt
$ terraform validate
```

---

# 5. 실행 계획 확인(plan)

```bash
$ terraform plan
```

정상 출력 예시:

```
Plan:3to add,0to change,0to destroy.
```

즉,

- VPC 1개
- 서브넷 2개(퍼블릭 1, 프라이빗 1)
    
    총 3개 리소스가 생성될 예정이다.
    

---

# 6. 리소스 생성(apply)

```bash
$ terraform apply
```

중간에 승인 입력이 나오면 `yes`를 입력한다.

정상 완료 예시:

```
Applycomplete!Resources:3added,0changed,0destroyed.
```

이후 AWS 콘솔에서 VPC 및 Subnet이 정상 생성되었는지 확인한다.

---

# 7. 리소스 정리(destroy)

현재는 실습 목적이므로 리소스를 유지할 필요가 없다면 삭제한다.

```bash
$ terraform destroy
```

---

# 8. 이번 파트 결과 요약

이번 파트에서 목표 중 다음 항목을 완료했다.

- VPC 생성 완료
- 퍼블릭 서브넷 1개 생성 완료
- 프라이빗 서브넷 1개 생성 완료

다음 파트에서는 다음을 구성할 예정이다.

- 라우트 테이블(Route Tables)
- NAT Gateway
- Internet Gateway