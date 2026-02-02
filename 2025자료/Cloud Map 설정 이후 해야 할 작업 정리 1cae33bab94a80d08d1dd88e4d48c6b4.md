# Cloud Map 설정 이후 해야 할 작업 정리

### 1️⃣ **서비스 정상 작동 여부 확인**

### 🔧 확인 포인트

- ECS 서비스가 **정상 실행 중(steady state)**인지 확인
- ALB를 통해 **HTTP 요청이 정상적으로 응답되는지** 확인
- ECS → CloudMap → ALB 트래픽 흐름이 연결되었는지 확인

```bash
curl http://<ALB DNS>         # 퍼블릭 ALB URL로 테스트
```

---

### 2️⃣ **Cloud Map 도메인 테스트 (내부용)**

### EC2에서 내부 서비스 DNS 테스트

```bash
nslookup web-svc.internal     # Cloud Map에 등록된 서비스
curl http://web-svc.internal  # 내부 서비스로 직접 요청
```

> 💡 목적: ECS 서비스가 Cloud Map을 통해 내부 DNS 이름으로 접근 가능한지 확인
> 

---

### 3️⃣ **CloudWatch 로그 확인**

### 로그 수집 상태 확인

- ECS Task Definition에서 지정한 `logConfiguration`을 확인
- 로그 그룹 `/ecs/<서비스명>`이 존재하는지 확인
- **실행 중인 컨테이너의 로그 내용이 수집되고 있는지** 확인

---

### 4️⃣ **DynamoDB 연동 확인 (있을 경우)**

> 문제에 따라 Golang 애플리케이션이 DynamoDB와 연동되도록 구성된 경우
> 
- DynamoDB 테이블이 생성되었는지 확인
- ECS Task Role에 DynamoDB 접근 권한이 있는지 확인
- CloudWatch 로그에 `PutItem`, `GetItem` 요청이 보이는지 확인

---

### 5️⃣ **Tag 정보 확인**

> 채점 시 실수 많음 ⚠️
> 
- 모든 리소스에 과제에서 요구한 Tag (예: `Name`, `Project`, `Environment`)가 정확히 입력되었는지 확인
- 누락된 리소스는 없는지 다시 검토

---

### 6️⃣ **보안 그룹 및 네트워크 구성 확인**

- ALB → ECS 서비스 통신 (보안 그룹 Inbound)
- ECS Task가 외부 API 또는 DynamoDB와 통신 가능 여부
- VPC, Subnet, Route Table, NAT Gateway 구성 상태 확인

---

### 7️⃣ **부하 테스트 전 확인 및 중지 안내**

- 테스트 또는 부하 생성 스크립트가 실행되고 있다면 과제 종료 전 반드시 중지
- CloudWatch 경보 설정이 과도하게 부하를 유발하지 않는지 확인

---

## ✅ 마무리 체크리스트 (Cloud Map 이후)

| 항목 | 확인 여부 |
| --- | --- |
| ECS 서비스와 Cloud Map이 연결되어 있음 | 🔲 |
| ALB를 통해 서비스에 접근 가능함 | 🔲 |
| 내부 DNS (`web-svc.internal`) 응답 정상 | 🔲 |
| CloudWatch 로그 정상 수집 중 | 🔲 |
| DynamoDB 연동 성공 여부 확인됨 | 🔲 |
| 모든 리소스에 태그 부여 완료 | 🔲 |
| 보안 그룹/서브넷 구성 정상 | 🔲 |
| 테스트 스크립트 중지 및 리소스 상태 안정적 | 🔲 |