# CloudWatch Logs 연동 (ECS Task → 로그 수집)

1. IAM 역할 확인/수정 (`ecsTaskExecutionRole`)
2. Task 정의 수정 → 로그 드라이버 설정
3. ECS 서비스 재배포
4. CloudWatch Logs에서 로그 확인

### ① IAM 역할 권한 확인

1. IAM → 역할 → `ecsTaskExecutionRole` 클릭
2. 연결된 정책 확인:
    
    ✅ 반드시 아래 정책이 포함되어야 함:
    
    ```
    AmazonECSTaskExecutionRolePolicy
    ```
    

> 없으면 추가:
> 
> 
> → 정책 추가 → `AmazonECSTaskExecutionRolePolicy` 검색 → 연결
> 

### ② ECS Task 정의 수정 (또는 새로 생성)

1. ECS → Task 정의 → 기존 Task 선택 → 새로 개정(Revision)
2. 컨테이너 설정 부분 → **[스토리지 및 로깅] 섹션**
3. 로그 설정:
    - **로그 드라이버**: `awslogs`
    - **로그 그룹**: `/ecs/golang-app` (또는 원하는 이름)
    - **영역(region)**: `ap-northeast-2`
    - **스트림 Prefix**: `ecs`

✅ 예시 설정:

| 필드 | 값 |
| --- | --- |
| 로그 드라이버 | awslogs |
| awslogs-group | /ecs/golang-app |
| awslogs-region | ap-northeast-2 |
| awslogs-stream-prefix | ecs |

### ③ ECS 서비스 수정 → 새 Task 정의로 재배포

- ECS → 클러스터 → 서비스 → 수정
- 새 Task 정의 Revision 선택
- 서비스 업데이트 완료 → Task 재시작

### ④ CloudWatch Logs 확인

1. CloudWatch → 로그 그룹 → `/ecs/golang-app`
2. 스트림 열기 (자동 생성됨, 예: `ecs/golang-container/…`)
3. `fmt.Fprintf()` 출력 확인 가능

## 🎯 테스트용 main.go 로그 출력 코드 예시

```go
func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello from ECS on Fargate!")
    fmt.Println(">> 요청 처리 완료: /")
}
```

이렇게 하면 `fmt.Println(...)` 메시지가 로그로 찍혀서

CloudWatch에서 바로 확인할 수 있어요!

## ✅ 성공 확인

| 항목 | 확인 여부 |
| --- | --- |
| `/ecs/golang-app` 로그 그룹 생성됨 | ✅ |
| 로그 스트림 자동 생성됨 | ✅ |
| 웹 요청 시 로그에 출력 발생 | ✅ |