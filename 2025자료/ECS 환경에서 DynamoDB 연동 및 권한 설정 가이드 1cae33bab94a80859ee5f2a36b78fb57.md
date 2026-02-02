# ECS 환경에서 DynamoDB 연동 및 권한 설정 가이드

---

### 🧱 0단계: 개요 요약

| 항목 | 내용 |
| --- | --- |
| 대상 | ECS Fargate 서비스 |
| 목표 | 컨테이너 내부 애플리케이션이 DynamoDB 접근 가능하게 하기 |
| 핵심 구성요소 | IAM Role, 정책, Task Definition, 환경변수, SDK |

---

### 1️⃣ DynamoDB 테이블 생성

1. 콘솔 → **DynamoDB** → [테이블 생성]
2. 테이블 이름: `Students` (예시)
3. 파티션 키: `StudentID` (String)
4. 나머지 옵션 기본값 → 생성

💡 **주의**: ECS Task와 동일한 리전에 생성해야 접근이 가능

---

### 2️⃣ IAM Role 생성 (ECS Task Role)

1. 콘솔 → **IAM** → 역할(Roles) → [역할 생성]
2. **신뢰할 수 있는 엔터티**: AWS 서비스 → ECS → **ECS Task**
3. 정책 연결: 아래 두 가지 중 택1
    - **빠르게 테스트용**: `AmazonDynamoDBFullAccess`
    - **실제 서비스용 최소 권한**: 아래처럼 직접 작성

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:ap-northeast-2:<account-id>:table/Students"
    }
  ]
}
```

1. 역할 이름: `ecs-task-dynamodb-role` 등 → 생성

---

### 3️⃣ ECS Task Definition에 IAM Role 연결

1. 콘솔 → **ECS → Task Definitions** → 사용 중인 Definition 선택 or 새로 생성
2. **Task Role** 항목에 방금 만든 `ecs-task-dynamodb-role` 지정
3. 컨테이너 정의에서 애플리케이션에 필요한 **환경변수 추가**
    - 예: `DYNAMODB_TABLE_NAME=Students`

---

### 4️⃣ 애플리케이션 코드에서 DynamoDB 호출

### 예: Python boto3

```python
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMODB_TABLE_NAME']
table = dynamodb.Table(table_name)

response = table.put_item(
    Item={
        'StudentID': '12345',
        'Name': 'Alice'
    }
)
print("Item inserted:", response)
```

> ✅ SDK는 ECS Task 내부에서 IAM Role을 통해 자동 인증됨 (키 입력 불필요)
> 

---

## ✅ Amazon Linux 2023에서 EC2 인스턴스로 DynamoDB 연동하기

---

### 기본 개념

| 요소 | 설명 |
| --- | --- |
| 운영체제 | Amazon Linux 2023 |
| 도구 | AWS CLI v2 (기본 설치됨) |
| 인증 방식 | **IAM Role 연결** (권장) 또는 `aws configure` 이용 |
| 목표 | CLI 명령어로 DynamoDB 테이블에 접근 (`put-item`, `get-item`, `scan`) |

---

## Amazon Linux 2023에서 CLI로 테스트

### (1) EC2 접속

```bash
ssh -i your-key.pem ec2-user@<EC2 퍼블릭 IP>
```

### (2) CLI 정상 설치 확인

```bash
aws --version
# 출력 예: aws-cli/2.x.x Python/3.x.x ...
```

💡 Amazon Linux 2023에는 `aws`와 `python3`가 기본 내장된 경우가 대부분입니다. 없으면 아래 명령 실행:

```bash
sudo dnf install -y awscli
```

---

## DynamoDB 명령어 테스트

### ✅ 예제용 테이블: `Students`

### 항목 구성

| 키 | 값 | 타입 |
| --- | --- | --- |
| StudentID | 101 | String |
| Name | Alice | String |

---

### 📌 (1) put-item (데이터 삽입)

```bash
aws dynamodb put-item \
  --table-name Students \
  --item '{"StudentID": {"S": "101"}, "Name": {"S": "Alice"}}' \
  --region ap-northeast-2
```

---

### 📌 (2) get-item (단건 조회)

```bash
aws dynamodb get-item \
  --table-name Students \
  --key '{"StudentID": {"S": "101"}}' \
  --region ap-northeast-2
```

---

### 📌 (3) scan (전체 조회)

```bash
aws dynamodb scan \
  --table-name Students \
  --region ap-northeast-2
```

---

## 🔍 오류 예시 및 해결

| 오류 메시지 | 원인 | 해결 방법 |
| --- | --- | --- |
| `AccessDeniedException` | IAM Role에 권한 없음 | IAM 역할 확인 또는 정책 수정 |
| `Unable to locate credentials` | IAM Role 미연결 | EC2에 IAM Role 연결하거나 `aws configure` 사용 |
| `Table not found` | 테이블 이름 오타 또는 리전 불일치 | DynamoDB 테이블 이름/리전 확인 |

---

## 📎 참고: aws configure로 자격 증명 설정 (비추천이지만 가능)

```bash
bash
복사편집
aws configure
# Access Key ID:
# Secret Access Key:
# Region: ap-northeast-2
# Output format: json

```

### CloudWatch에서 로그 확인

- 정상 호출 시 → 애플리케이션 로그에 응답 정보 확인 가능
- 오류 발생 시 → 권한 오류 (`AccessDeniedException`), 테이블 없음 등 로그로 추적

---

### 📌 점검 체크리스트

| 항목 | 확인 여부 |
| --- | --- |
| DynamoDB 테이블이 같은 리전에 생성됨 | 🔲 |
| ECS Task Role에 DynamoDB 접근 권한 포함됨 | 🔲 |
| Task Definition에 IAM Role이 연결되었는가 | 🔲 |
| 애플리케이션 코드가 Role 인증 방식 사용 중 | 🔲 |
| CloudWatch 로그로 연동 결과 확인 가능 |  |