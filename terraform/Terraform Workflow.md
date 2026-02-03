# Terraform Workflow

## write → plan → apply

Terraform의 구성 요소(HCL 블록, 모듈, 변수, 출력)를 충분히 익혔으므로, 이제 Terraform이 의도하는 올바른 사용 흐름(Workflow)을 살펴본다.

겉보기에는 단순해 보이지만, 이 워크플로를 정확히 이해하지 못하면 **실수·예기치 않은 변경·사고**로 이어질 수 있다.

특히 이 내용은 **Terraform 자격증 시험에서도 직접적으로 출제되는 핵심 개념**이다.

![image.png](Terraform%20Workflow/image.png)

![image.png](Terraform%20Workflow/image%201.png)

## 1. Terraform 기본 워크플로 개요

Terraform이 권장하는 기본 워크플로는 다음과 같다.

1. **write**
    - Terraform 구성 파일 작성
    - 프로젝트 초기화
2. **validate / fmt**
    - 코드 정리 및 문법 검사
3. **plan**
    - 실제 적용 전 변경 사항 미리 확인(dry-run)
4. **apply**
    - 인프라 생성 또는 변경 적용
5. **destroy** *(필요 시)*
    - 인프라 정리 및 삭제

우리는 실습 과정에서 이미 이 흐름을 자연스럽게 사용해 왔지만,

이제 이를 **명시적으로 정리**한다.

---

## 2. terraform init

### 역할

- Terraform 프로젝트 **초기화**
- Provider 다운로드
- Backend 설정
- Lock 파일 및 내부 메타데이터 생성

### 언제 실행해야 하나?

다음 상황에서는 반드시 `terraform init`을 실행해야 한다.

- 새 Terraform 프로젝트를 시작할 때
- 기존 프로젝트를 Git에서 클론했을 때
- 새로운 **Module**을 추가했을 때
- Provider 버전을 변경했을 때
- Backend 설정을 변경했을 때

### 명령어

```bash
$ terraform init
```

Terraform은 초기화가 필요하지만 실행하지 않았을 경우,

**에러 메시지로 친절하게 알려준다.**

---

## 3. terraform validate

### 역할

- Terraform 코드의 **문법 오류 검사**
- 구성 파일 간의 내부 일관성 확인
- 실제 리소스 생성은 하지 않음

### 특징

- 현재 디렉터리의 `.tf` 파일만 검사
- 빠르고 안전한 사전 점검 단계

### 명령어

```bash
$ terraform validate
```

### 모듈까지 함께 검사할 경우

```bash
$ terraform validate -recursive
```

---

## 4. terraform plan

### 역할

- **Dry-run (실행 계획)** 생성
- 실제로 어떤 리소스가
    - 생성(create)
    - 변경(update)
    - 삭제(destroy)
        
        될지 미리 보여줌
        

### 핵심 포인트

- `execution plan` = `terraform plan`
- 배포 전 반드시 확인하는 것이 **베스트 프랙티스**
- 계획을 파일로 저장 가능 (분석·감사용)

### 명령어

```bash
$ terraform plan
```

예시 출력 요약:

```
Plan:3to add,1to change,0to destroy.
```

---

## 5. terraform apply

### 역할

- Terraform 구성에 정의된 인프라를 **실제로 배포**
- 기존 인프라가 있다면 필요한 부분만 변경

### 특징

- 실행 전 사용자 승인 필요
- 실행 후 **state 파일(terraform.tfstate)** 생성 또는 갱신
- 현재 구성에 포함된 리소스만 대상

### 명령어

```bash
$ terraform apply
```

승인 없이 바로 실행하려면:

```bash
$ terraform apply -auto-approve
```

⚠️ 실무에서는 `-auto-approve` 사용에 주의가 필요하다.

---

## 6. terraform destroy

### 역할

- Terraform으로 생성한 인프라 **완전 삭제**
- 재현 가능한 인프라의 핵심 개념 중 하나

### 왜 중요한가?

- 실습·테스트 후 **기술 부채 제거**
- 불필요한 클라우드 비용 방지
- 인프라 생명주기 관리

### 명령어

```bash
$ terraform destroy
```

자동 승인 옵션:

```bash
$ terraform destroy -auto-approve
```

---

## 7. Terraform Workflow 한 줄 요약

```
write → init → fmt/validate → plan → apply → (destroy)
```

이 흐름을 지키면 다음을 보장할 수 있다.

- 예측 가능한 인프라 변경
- 불필요한 사고 방지
- 시험 및 실무 모두에서 안정적인 운영

---

## 8. 시험 대비 핵심 포인트

자격증 시험에서 특히 자주 묻는 내용은 다음이다.

- `terraform plan` = dry-run / execution plan
- `terraform init` 실행이 필요한 상황
- `validate` vs `plan` 차이
- `apply`는 **state 파일을 생성/갱신**함
- Terraform은 **구성에 포함되지 않은 리소스는 건드리지 않음**