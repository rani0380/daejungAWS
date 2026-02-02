# 10. CloudWatch 로그 확인 절차 (ECS Task 기준)

## 1. **ECS 콘솔 접속**

- [https://console.aws.amazon.com/ecs](https://console.aws.amazon.com/ecs)
- 왼쪽 메뉴 → **클러스터** → 사용 중인 클러스터 클릭 (예: `golang-cluster2`)

---

### 2. **서비스 > 작업(Task) 클릭**

- 실행 중인 **작업(Task)** 클릭

---

### 3. **컨테이너 탭에서 "로그 보기" 클릭**

- **`app-container`** 라는 이름의 컨테이너 아래에 **"로그 보기" 버튼**이 있습니다.
- 클릭하면 **CloudWatch Logs**로 이동

---

### 4. **CloudWatch 콘솔에서 로그 스트림 확인**

- 로그 그룹 이름: `/ecs/new-golang-task`
- 로그 스트림 예시: `ecs/app-container/0123456789abcdef...`
- 출력 메시지 예시:
    
    ```
    Hello from ECS on Fargate!
    요청처리완료 :/
    ```
    

---

### ✅ 로그가 안 보일 경우 체크리스트

| 항목 | 설명 |
| --- | --- |
| ECS Task Definition에 logConfiguration 설정됨? | ✅ 이미 되어 있음 (JSON 확인 완료) |
| 애플리케이션이 `fmt.Println`, `log.Println` 등으로 로그를 출력하고 있는가? | ✅ `fmt.Println("요청처리완료 :/")` 사용 중 |
| CloudWatch 로그 그룹이 존재하는가? | ECS가 자동 생성하도록 설정되어 있음 (`awslogs-create-group: true`) |

---

### 🛠 로그가 비어 있다면?

- 애플리케이션 코드에 `log.Fatal(err)` 또는 `log.Println("서버 시작")` 같은 로그 추가 추천
- 로그 스트림이 뜨지 않으면 ECS Task를 재시작하면 로그 그룹이 자동 생성됨