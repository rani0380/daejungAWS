# 8. ECR Fargate에 배포(Docker 이미지 푸시)

Amazon ECR(Elastic Container Registry)은 AWS에서 제공하는 **컨테이너 이미지 저장소** 입니다.

우리가 만든 golang-app 이미지를 여기에 푸시해두고, 이후 ECS에서 사용할 수 있어요.

### 🧭 전체 흐름 요약

1. ECR 리포지토리 생성
2. AWS CLI로 로그인
3. Docker 이미지에 태그 붙이기
4. ECR로 이미지 푸시

AWS 콘솔 → **ECR → 리포지토리 생성**

## ECR에 로그인 (1회만 필요)

```bash
aws ecr get-login-password \
  | docker login --username AWS \
  --password-stdin <계정번호>.dkr.ecr.ap-northeast-2.amazonaws.com
```

```bash
aws ecr get-login-password --region ap-northeast-2 \
| docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com
```

※ 위의 `<계정번호>`는 본인의 AWS 계정 ID로 교체해주세요

(리포지터리 URI에서 확인 가능)

![image.png](8%20ECR%20Fargate%EC%97%90%20%EB%B0%B0%ED%8F%AC(Docker%20%EC%9D%B4%EB%AF%B8%EC%A7%80%20%ED%91%B8%EC%8B%9C)/image.png)

## ✅ 로그인 성공 메시지: `Login Succeeded`

### ① ECR 리포지토리 생성

```bash
aws ecr create-repository --repository-name golang-app
```

- **이름**: `golang-app`
- **가시성**: 비공개
- 다른 설정은 기본값 유지
- 생성 후 → 리포지토리 URI 확인 (예: `123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/golang-app`)

> 복사해두세요! 태깅할 때 사용됩니다.
> 

![image.png](8%20ECR%20Fargate%EC%97%90%20%EB%B0%B0%ED%8F%AC(Docker%20%EC%9D%B4%EB%AF%B8%EC%A7%80%20%ED%91%B8%EC%8B%9C)/image%201.png)

### 📌 참고

- 실행 후 출력되는 `repositoryUri`는 다음 단계에서 사용됩니다.

예시:

```
"repositoryUri": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/golang-app"
```

## Docker 이미지 태깅

```bash
docker tag golang-app:latest <repository-uri>:latest
```

예시:

```bash
docker tag golang-app:latest 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/golang-app:latestd
```

---

※ `123456789012` → 본인 AWS 계정 ID로 바꿔주세요

(리포지토리 URI 복사해두신 거 사용하면 됩니다)

### ④ ECR로 푸시

```bash
docker push <repository-uri>:latest
```

```bash
docker push 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/golang-app:latest
```

✅ 성공 시, 이미지 레이어가 업로드되며 완료 메시지가 출력됩니다.

## ✅ 확인

AWS 콘솔 > ECR > golang-app > "이미지 탭"에서

방금 푸시된 `latest` 태그가 보이면 성공입니다!

![image.png](8%20ECR%20Fargate%EC%97%90%20%EB%B0%B0%ED%8F%AC(Docker%20%EC%9D%B4%EB%AF%B8%EC%A7%80%20%ED%91%B8%EC%8B%9C)/image%202.png)

## 🎯 성공하면?

이제 ECR에 이미지가 저장되었고, **다음 단계: ECS + Fargate로 서비스 배포**로 이어질 수 있습니다!

### 1️⃣ 먼저 로컬에 이미지가 존재하는지 확인

```bash
docker images
```

여기서 `REPOSITORY`가 `golang-app`이고, `TAG`가 `latest`인 항목이 있는지 확인해보세요.

---

### 2️⃣ 이미지가 없다면 빌드 먼저!

이미지가 없다면 아래 명령으로 도커 이미지부터 빌드:

```bash
docker build -t golang-app:latest .
```

> Dockerfile이 있는 디렉토리에서 실행해야 해요.
> 

---

### 3️⃣ 태그 지정

정상적으로 이미지가 빌드되었으면 아래와 같이 태깅:

```bash
docker tag golang-app:latest 415927637238.dkr.ecr.ap-northeast-2.amazonaws.com/golang-app:latest
```

---

### 4️⃣ ECR에 푸시

```bash
docker push 415927637238.dkr.ecr.ap-northeast-2.amazonaws.com/golang-app:latest
```

---

## ✅ 요약

1. `docker images`로 이미지 존재 확인
2. 없으면 `docker build -t golang-app:latest .`
3. `docker tag ...`
4. `docker push ...`

## ✅ 대체 가능한 애플리케이션 예시

| 언어/환경 | 대체 앱 이름 예시 | 설명 |
| --- | --- | --- |
| **Node.js** | `node-app` | Express로 만든 간단한 웹 서버 |
| **Python** | `flask-app` | Flask 기반 REST API 또는 웹서버 |
| **Java** | `spring-app` | Spring Boot 애플리케이션 |
| **HTML+Nginx** | `static-web` | 정적 사이트를 Nginx로 호스팅 |
| **React/Vue** | `frontend-app` | 정적 SPA + 백엔드 연동 가능 |
| **Python FastAPI** | `fastapi-app` | Swagger UI까지 제공되는 API 백엔드 |
| **Next.js** | `nextjs-app` | SSR(서버 사이드 렌더링) 프레임워크 |

![image.png](8%20ECR%20Fargate%EC%97%90%20%EB%B0%B0%ED%8F%AC(Docker%20%EC%9D%B4%EB%AF%B8%EC%A7%80%20%ED%91%B8%EC%8B%9C)/image%203.png)

### 📄 파일 목록 및 용도

| 파일 이름 | 설명 |
| --- | --- |
| `Dockerfile` | Go 애플리케이션을 Docker 이미지로 빌드하기 위한 명세 파일 |
| `app` | `main.go`를 `go build`로 컴파일한 실행 파일 |
| `go.mod` | Go 모듈 설정 파일 (의존성 및 모듈 이름 정의) |
| `go1.21.5.linux-amd64.tar.gz` | Go 언어 설치용 압축 파일 |
| `main.go` | 메인 애플리케이션 코드 파일 |