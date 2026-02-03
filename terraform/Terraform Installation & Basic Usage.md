# Terraform: Installation & Basic Usage

## 1. 사전 준비 사항(Prerequisites)

Terraform을 사용하기 위해 다음 준비가 필요하다.

### 1) Terraform 설치

- 운영체제에 맞는 Terraform 설치

https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

### 2) AWS CLI 설치

- AWS 리소스를 관리하기 위한 CLI 도구

### 3) AWS 계정 및 자격 증명

- **Programmatic access**가 가능한 IAM User
- 다음 두 정보 필요
    - AWS Access Key ID
    - AWS Secret Access Key

---

## 2. AWS 자격 증명 환경 변수 설정

Terraform과 AWS CLI가 인증 정보를 사용할 수 있도록 **환경 변수**를 설정한다.

(꺾쇠(< >) 없이, 따옴표 안에 실제 키 값을 입력)

```bash
$export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
$export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
```

위 작업이 완료되면 Terraform이 AWS 리소스를 관리할 준비가 끝난다.

---

## 3. 첫 번째 인프라 배포하기

이제 Terraform을 이용해 **EC2 인스턴스 1대**를 배포해 본다.

이 과정에서 Terraform의 기본 워크플로와 구성 파일 구조를 익히게 된다.

---

## 4. 실습용 프로젝트 디렉터리 생성

터미널에서 다음 명령을 실행한다.

```bash
# tf-demo 디렉터리 생성
$mkdir tf-demo

# 디렉터리 이동
$cd tf-demo
```

---

## 5. 첫 번째 Terraform 구성 파일 작성

프로젝트 디렉터리 안에 `main.tf` 파일을 생성한다.

```bash
$touch main.tf
```

`main.tf` 파일을 열고 아래 코드를 입력한다.

```hcl
# Terraform 설정 블록
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

# AWS Provider 설정
provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

# EC2 인스턴스 리소스 정의
resource "aws_instance" "app_server" {
  ami           = "ami-830c94e3"
  instance_type = "t2.micro"

  tags = {
    Name = "PathToTerraformCertInstance"
  }
}
```

---

## 6. Terraform 초기화

Terraform이 필요한 Provider를 다운로드하도록 초기화한다.

```bash
$ terraform ini
```

정상적으로 완료되면 다음 메시지가 출력된다.

```
Terraform has been successfully initialized!
```

---

## 7. 코드 정렬(fmt)

들여쓰기나 형식이 맞지 않더라도 걱정할 필요는 없다.

Terraform은 자동 정렬 명령어를 제공한다.

```bash
$ terraformfmt
```

---

## 8. 구성 파일 유효성 검사(validate)

작성한 코드에 문법 오류가 없는지 확인한다.

```bash
$ terraform validate
```

정상일 경우 다음과 같은 메시지가 출력된다.

```
Success! Theconfigurationisvalid.
```

---

## 9. 실행 계획 확인(plan)

실제 리소스를 생성하기 전에, Terraform이 **무엇을 할지 미리 확인**한다.

```bash
$ terraform plan
```

출력 결과에서 확인할 수 있는 핵심 포인트는 다음과 같다.

- `+ create` : 새로운 리소스를 생성함
- 생성될 EC2 인스턴스의 상세 정보
- 요약 결과

```
Plan:1to add,0to change,0to destroy.
```

즉,

- 1개 리소스 생성
- 변경 없음
- 삭제 없음

---

## 10. 인프라 생성(apply)

모든 내용이 정상이라면 실제로 리소스를 생성한다.

```bash
$ terraform apply
```

Terraform은 실행 전에 반드시 사용자에게 확인을 요청한다.

```
Do you wanttoperform these actions?
Only'yes' will be acceptedto approve.
```

`yes`를 입력하면 배포가 시작된다.

배포 완료 시 다음과 같은 메시지가 출력된다.

```
Applycomplete!Resources:1added,0changed,0destroyed.
```

🎉 **Infrastructure as Code를 이용한 첫 번째 리소스 배포 성공!**

---

## 11. Terraform 상태 확인

Terraform이 관리 중인 리소스를 확인한다.

```bash
$ terraform state list
```

출력 예시:

```
aws_instance.app_server
```

---

## 12. 리소스 삭제(destroy)

실습이 끝났다면 리소스를 삭제한다.

Terraform은 생성뿐만 아니라 **정리까지 자동화**한다.

```bash
$ terraform destroy
```

역시 `yes` 입력 후 삭제가 진행된다.

```
Destroycomplete!Resources:1destroyed.
```

---

## 13. 정리 및 핵심 요약

이번 실습을 통해 Terraform의 기본 워크플로를 익혔다.

### Terraform 기본 워크플로

1. **write** : 구성 파일 작성
2. **plan** : 변경 사항 사전 확인
3. **apply** : 인프라 생성
4. **destroy** : 인프라 삭제

EC2 한 대를 만드는 것이 AWS 콘솔보다 느려 보일 수도 있다.

하지만 Terraform의 핵심 가치는 **규모가 커질수록 더욱 분명해진다.**