# Terraform Practice4

## Module Input과 Output 사용하기

모듈을 **진짜로 유용하게** 만들기 위해서는

- 모듈에 **입력값(Input)**을 전달하고
- 모듈에서 생성된 값을 **출력(Output)**으로 받아 다른 구성에서 재사용할 수 있어야 한다.

Terraform에서는 이를 위해 **variables.tf**와 **outputs.tf** 파일을 사용한다.

이 구조는 **사실상 표준(best practice)**이며, 실무에서도 거의 동일하게 사용된다.

---

## 1. 모듈 파일 구조 Best Practice

- `variables.tf` : 모듈 입력 변수 정의
- `main.tf` : 실제 리소스 정의
- `outputs.tf` : 모듈이 외부로 제공할 출력 값 정의

---

## 2. server 모듈 리팩터링

이전 파트에서 작성했던 `server.tf`를 분리하여 다음과 같이 **3개의 파일로 재구성**한다.

---

### 2-1. modules/server/variables.tf

```hcl
variable "subnet_id" {}

variable "size" {
  default = "t2.micro"
}

variable "security_groups" {
  type = list(any)
}
```

### 변수 설명

- `subnet_id`
    - 기본값 없음 → **필수 입력 변수**
- `size`
    - 기본값 존재 → **선택 입력 변수**
- `security_groups`
    - 보안 그룹 ID 목록

---

### 2-2. modules/server/main.tf

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

  owners = ["099720109477"]
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
```

---

### 2-3. modules/server/outputs.tf

```hcl
output "public_ip" {
  value = aws_instance.web_server.public_ip
}

output "public_dns" {
  value = aws_instance.web_server.public_dns
}
```

---

## 3. 기존 server.tf 제거

위와 같이 파일을 분리했으면

기존의 `server.tf` 파일은 삭제해도 된다.

이후 다음 명령어를 실행하여 변경 사항을 확인한다.

```bash
$ terraform init
$ terraformfmt
$ terraform validate
$ terraform plan
```

---

## 4. 리팩터링 후 프로젝트 구조

최종 디렉터리 구조는 다음과 같다.

```
.
├──main.tf
├── modules
│   └── server
│       ├──main.tf
│       ├── outputs.tf
│       ├── variables.tf
├── outputs.tf
├── terraform.tf
├── terraform.tfstate
├── terraform.tfstate.backup
└── variables.tf
```

---

## 5. Terraform Input Variables 이해하기

Terraform의 입력 변수는 **필수(required)**와 **선택(optional)**로 나뉜다.

### 필수 입력 변수

- `default` 값이 없음
- 반드시 외부에서 값을 전달해야 함

```hcl
variable "subnet_id" {}
```

### 선택 입력 변수

- `default` 값이 존재
- 값이 전달되지 않으면 기본값 사용

```hcl
variable "size" {
  default = "t2.micro"
}
```

---

## 6. Terraform Outputs 이해하기

Output은 **모듈이 외부에 제공하는 읽기 전용 값**이다.

### Output의 특징

- Child module → Parent module로 값 전달
- 읽기 전용(Read-only)
- **Child module의 리소스 속성에 접근할 수 있는 유일한 방법**

---

## 7. Root Module에서 Output 사용하기

모듈에서 정의한 output은

**module.<모듈이름>.<output이름>** 형태로 접근한다.

### root main.tf 예시

```hcl
output "public_ip" {
  value = module.my_server_module.public_ip
}
```

이렇게 하면:

- 모듈 내부 EC2의 퍼블릭 IP를
- 루트 모듈에서 출력하거나
- 다른 리소스의 입력값으로 활용할 수 있다.

---

## 8. pt.4 핵심 정리

이번 파트에서 배운 핵심 내용은 다음과 같다.

- Terraform 모듈의 **입력(Input)과 출력(Output)** 개념
- variables.tf / main.tf / outputs.tf 분리 구조
- 필수 변수와 선택 변수 차이
- Output을 통한 Child Module 값 참조
- Dot notation(`module.xxx.yyy`) 사용법