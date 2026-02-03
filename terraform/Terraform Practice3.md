# Terraform Practice3

# Terraform Module 사용법과 Source 유형

Terraform에서 **Module은 매우 중요한 개념**이다.

Module은 Terraform에서 **리소스 구성을 패키징하고 재사용하는 핵심 수단**이다.

모듈을 적절히 사용하면 다음과 같은 장점이 있다.

- 코드 가독성 향상
- 재사용성 증가
- 구성 표준화 및 일관성 유지
- 베스트 프랙티스 강제

---

## 1. Terraform Module이란?

Terraform Module은 **하나의 디렉터리 안에 있는 Terraform 설정 파일들의 집합**이다.

사실 우리는 이미 이전 챕터에서 모듈을 사용했다.

지금까지 작성해 온 `main.tf`, `variables.tf` 등은 모두 **Root Module**이다.

모듈은 규모가 작을 때는 중요성이 잘 느껴지지 않지만,

인프라가 커지고 복잡해질수록 **필수 요소**가 된다.

---

## 2. Module 생성 방법

### 2-1. Module 디렉터리 생성

Terraform 프로젝트 루트 디렉터리에서 새로운 폴더를 만든다.

이 예제에서는 `server`라는 이름의 모듈을 만든다.

```bash
$mkdir server
$cd server
$touch server.tf
```

### 2-2. 프로젝트 디렉터리 구조

(숨김 폴더 `.terraform/` 제외)

```
.
├── main.tf
├── outputs.tf
├──server
│   └──server.tf
├── terraform.tf
├── terraform.tfstate
├── terraform.tfstate.backup
└── variables.tf
```

---

## 3. server 모듈 작성

`server/server.tf` 파일에 다음 내용을 작성한다.

```hcl
variable "subnet_id" {}

variable "size" {
  default = "t2.micro"
}

variable "security_groups" {
  type = list(any)
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["**099720109477**"]
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.size
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_groups

  tags = {
    Name      = "Web Server from module"
    Terraform = "true"
  }
}

output "public_ip" {
  value = aws_instance.web_server.public_ip
}

output "public_dns" {
  value = aws_instance.web_server.public_dns
}

```

### 구성 설명

- **variable**: 모듈 입력값
- **data**: 최신 Ubuntu AMI 자동 조회
- **resource**: EC2 인스턴스 생성
- **output**: 모듈 실행 결과 출력

---

## 4. Root Module에서 Module 호출

이제 생성한 모듈을 `main.tf`에서 사용한다.

```hcl
module "my_server_module" {
  source          = "./server"
  subnet_id       = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.public_sg.id]
}
```

> module 블록에서 중요한 것은 **source 경로**이며,
> 
> 
> module 이름은 코드 내에서 참조하기 위한 식별자일 뿐이다.
> 

---

## 5. Module 추가 후 초기화

모듈을 새로 추가했기 때문에 반드시 초기화를 다시 수행해야 한다.

```bash
$ terraform init
```

---

## 6. 검증 및 확인

```bash
$ terraform validate
```

출력:

```
Success! Theconfigurationisvalid.
```

Provider 및 module 로딩 여부 확인:

```bash
$ terraform providers
```

예시 출력:

```
Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/aws] >=2.7.0
└──module.my_server_module
    └── provider[registry.terraform.io/hashicorp/aws]
```

---

## 7. 실행 계획 확인

```bash
$ terraform plan
```

출력 요약:

```
Plan:19to add,0to change,0to destroy.
```

→ 새로운 EC2 인스턴스 1대가 추가됨

---

## 8. 배포 및 상태 확인

```bash
$ terraform apply
```

상태 목록 확인:

```bash
$ terraform state list
```

출력 예시 중 마지막 두 줄:

```
module.my_server_module.data.aws_ami.ubuntu
module.my_server_module.aws_instance.web_server
```

👉 모듈에서 생성된 리소스가 정상적으로 관리됨을 확인할 수 있다.

특정 리소스 상세 조회:

```bash
$ terraform state show module.my_server_module.aws_instance.web_server
```

---

## 9. Module 재사용 예시

같은 모듈을 사용해 **프라이빗 서브넷**에 인스턴스를 하나 더 생성한다.

```hcl
module "another_server_from_a_module" {
  source          = "./server"
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.private_sg.id]
}
```

이후 다시:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

---

## 10. Terraform Module Source 유형

Terraform은 다양한 방식으로 모듈을 불러올 수 있다.

### 지원되는 주요 Source 유형

- 로컬 경로
- Terraform Public Registry
- GitHub / Bitbucket
- HTTP URL
- S3 (AWS), GCS (GCP)

---

## 11. 로컬 경로 Module 구조 개선

일반적인 권장 구조는 `modules/` 디렉터리를 사용하는 것이다.

```
.
├── main.tf
├── modules
│   └──server
│       └──server.tf
├── outputs.tf
├── terraform.tf
├── terraform.tfstate
├── terraform.tfstate.backup
└── variables.tf
```

Module 호출 방식:

```hcl
module "server_from_local_module" {
  source          = "./modules/server"
  subnet_id       = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.private_sg.id]
}
```

> 기존 module들의 source 경로도 함께 수정해야 한다.
> 

---

## 12. Terraform Public Module Registry 사용

Terraform은 공식 **Public Module Registry**를 제공한다.

👉 [https://registry.terraform.io](https://registry.terraform.io/)

### 예시: Auto Scaling Group 모듈 사용

AMI 조회용 data 블록 추가:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["**099720109477**"]
}

```

Registry 모듈 호출:

```hcl
module "autoscaling_from_registry" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.5.0"

  name                 = "demo_module_asg"
  vpc_zone_identifier  = [aws_subnet.private_subnet.id]
  min_size             = 0
  max_size             = 1
  desired_capacity     = 1
  image_id             = data.aws_ami.ubuntu.id
  instance_type        = "t3.micro"

  tags = {
    Name      = "Web servers from asg module"
    Terraform = "true"
  }
}

```

---

## 13. GitHub Module 사용

GitHub 저장소를 직접 source로 지정할 수도 있다.

```hcl
module "autoscaling_from_github" {
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling"

  name                = "demo_module_asg"
  vpc_zone_identifier = [aws_subnet.private_subnet.id]
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1
  image_id            = data.aws_ami.ubuntu.id
  instance_type       = "t3.micro"

  tags = {
    Name      = "Web servers from asg module"
    Terraform = "true"
  }
}
```

※ GitHub source 사용 시 **version 속성은 사용하지 않는다**.

---

## 14. 정리

이번 파트에서는 다음을 학습했다.

- Terraform Module 개념
- Custom Module 작성
- Module 재사용
- Module Source 유형
- Registry / GitHub Module 활용

이제 Terraform 프로젝트는 **실무 수준의 구조**를 갖추게 되었다.