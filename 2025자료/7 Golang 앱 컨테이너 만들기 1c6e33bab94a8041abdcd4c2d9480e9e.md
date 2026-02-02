# 7. Golang 앱 컨테이너 만들기

### ✅ 개념 이해

- **Golang 웹서버**는 최소 코드로 HTTP 요청을 처리할 수 있어 교육용으로 적합
- **Dockerfile**은 애플리케이션 실행 환경을 정의하는 파일
- 이 과정을 통해 **애플리케이션을 컨테이너화**하는 전체 흐름을 경험하게 됨

### 🛠️ 실습 절차

### ① 작업 디렉토리 만들기

```bash
mkdir ~/golang-app && cd ~/golang-app
```

### ② `main.go` 작성 (Golang 웹서버)

```bash
package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello from ECS on Fargate!")
}

func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":8080", nil)    # 대소문자 구분 확실
}
```

### Go 모듈 초기화

```bash
go mod init golang-app
```

### ③ `Dockerfile` 작성

```bash
# ===============================
# Build Stage
# ===============================
FROM golang:1.21 AS builder

WORKDIR /app

# 의존성 캐시 최적화
COPY go.mod go.sum ./
RUN go mod download

# 애플리케이션 소스 복사
COPY . .

# 빌드 설정 (리눅스/amd64, CGO 비활성화 → static binary)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -o app .

# ===============================
# Runtime Stage (Distroless)
# ===============================
FROM gcr.io/distroless/base-debian12

WORKDIR /app

COPY --from=builder /app/app ./app

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/app/app"]
```

### ④ Docker 이미지 빌드

```bash
docker build -t golang-app .
```

### 컨테이너 실행 및 확인

```bash
docker run -d -p 8080:8080 golang-app
curl localhost:8080
```

## ✅ `d` : **detach mode (백그라운드 실행)**

- 의미: 컨테이너를 **백그라운드에서 실행**합니다.
- 효과: 터미널을 점유하지 않고, 컨테이너가 계속 실행되도록 합니다.

## ✅ `p` : **포트 포워딩 (host:container)**

- 의미: **호스트(EC2) 포트와 컨테이너 포트를 연결**합니다.
- 형식: `p [호스트포트]:[컨테이너포트]`

| 옵션 | 설명 |
| --- | --- |
| `-d` | 컨테이너를 백그라운드에서 실행 |
| `-p` | EC2 8080 포트를 컨테이너 8080에 연결 |
| `golang-app` | 이미지 이름 (실행 대상) |

### 🔍 기능 요약

| 기능 | 설명 |
| --- | --- |
| `http.HandleFunc("/", handler)` | 루트 경로(`/`)로 들어오는 모든 요청을 `handler` 함수에 연결 |
| `fmt.Fprintf(w, "...")` | 브라우저(또는 curl)에 문자열 응답 |
| `fmt.Println(...)` | 서버 로그에 요청 처리 메시지 출력 |
| `http.ListenAndServe(":80", nil)` | 포트 80에서 HTTP 서버 실행 |

### ⑤ 테스트 (EC2 내부 또는 외부에서)

```bash
# EC2 내부에서 테스트
curl localhost:8080

# 로컬 PC에서 테스트 (퍼블릭 IP 사용)
curl http://<퍼블릭IP>:8080
```

출력 결과:

```csharp
Hello from ECS on Fargate!
```

### 💡 자주 발생하는 실수

| 현상 | 원인 | 해결 |
| --- | --- | --- |
| 브라우저 연결 안 됨 | 8080 포트 미허용 | 보안 그룹 인바운드 규칙 추가 |
| Docker build 실패 | 코드나 Dockerfile 오타 | `.go` 코드 문법 확인, 파일 이름 확인 |
| curl 응답 없음 | 컨테이너 실행 안 됨 | `docker ps`로 실행 상태 확인 |

다음 언어로 충분히 대체해도 됩니다:

| 언어 | 간단한 웹서버 예시 | 비고 |
| --- | --- | --- |
| **Python** | Flask or http.server | 쉬움, 설치 필요 |
| **Node.js** | Express or http 모듈 | 실시간 처리에 강함 |
| **JavaScript (Deno)** | 기본 내장 http 서버 | 설치 가볍고 빠름 |
| **Nginx 정적 서버** | HTML + Nginx | 웹서버만 보여줄 때 |
| **Golang** | `net/http` 표준 패키지 | 대회 실습용 기준 언어 |

오류 발생시 대처법

![image.png](7%20Golang%20%EC%95%B1%20%EC%BB%A8%ED%85%8C%EC%9D%B4%EB%84%88%20%EB%A7%8C%EB%93%A4%EA%B8%B0/image.png)

## ❗ 오류 메시지 요약

```
go: go.mod file not found in current directory or any parent directory
```

즉, **Go 모듈 초기화 (`go.mod`)가 없어서 `go build`에 실패**한 상황입니다.

### 1️⃣ 현재 디렉토리에서 go 모듈 초기화

```bash
go mod init golang-app
```

- 이 명령은 현재 폴더를 하나의 Go 모듈로 등록하며,
- `go.mod` 파일이 생성됩니다.

## `go.mod`는 왜 필요할까?

Go 1.13 이후부터는 **모듈 기반 빌드가 기본값**이 되었기 때문에,

직접 컴파일하거나 Docker에서 빌드할 때도 `go.mod`가 반드시 필요해요.

## ❗ 오류 메시지 요약

```
Unable to find image 'golang-app:latest' locally
docker: Error response from daemon: pull access denied for golang-app...
```

1. `golang-app` 이미지를 **로컬에서 못 찾음**
2. 그래서 **Docker Hub에서 pull 시도**
3. 하지만 Docker Hub에 `golang-app`이 없으므로 **access denied**

👉 **Docker 이미지를 다시 빌드하고 run 명령을 실행하세요**

### 1️⃣ 프로젝트 폴더로 이동

```bash
cd ~/golang-app
```

### 2️⃣ 이미지 다시 빌드

### Go 모듈 초기화 (필수!)

```bash
go mod init golang-app
```

```bash
docker build -t golang-app .
```

✅ 이 명령으로 `golang-app:latest` 이미지가 **로컬에 저장**됩니다.

### 3️⃣ 이미지 목록 확인

```bash
docker images
```

출력 예시:

```
REPOSITORY     TAG       IMAGE ID       CREATED         SIZE
golang-app     latest    abcdef123456   5 seconds ago   800MB
```

### 4️⃣ 실행

```bash
docker run -d -p 8080:8080 golang-app
```

## ✅ 성공 확인

```bash
curl localhost:8080
```

또는 브라우저에서

`http://<EC2 퍼블릭 IP>:8080`

출력:

```
Hello from ECS on Fargate!
```

## main.go 수정

### ① `main.go` 파일 열기

```bash
nano main.go
```

### 저장하고 나가기 (nano 에디터 기준)

- **Ctrl + O** → 저장
- **Enter** → 파일명 확인
- **Ctrl + X** → 종료

### 이전 Go 설치 흔적 제거 (정리용)

```bash
sudo rm -rf /usr/local/go
```

 오류 메시지:

```
gzip: stdin: not in gzip format
tar: Error is not recoverable: exiting now
```

은 다운로드한 파일이 `.tar.gz`처럼 보이지만 실제로는 **압축 형식이 잘못됐거나 손상된 경우**에 발생합니다.

---

## ✅ 해결 방법: 잘못된 tar.gz 삭제 후 재다운로드

1. **기존 파일 삭제**

```bash
rm go1.21.5.linux-amd64.tar.g
```

1. **정상 다운로드 다시 시도**

```bash
curl -LO https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
```

> ✅ -L 옵션이 중요합니다! (리다이렉션 따라가도록 설정)
> 

🔑-L = 리다이렉션 따라가기

🔑-O = 서버 파일명을 그대로 저장

1. **다시 압축 해제 및 설치**

```bash
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
```

1. **환경변수 등록**

```bash
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

1. **설치 확인**

```bash
go version
```

---

> 참고: .tar.gz는 압축 파일이지만, 리다이렉션이 제대로 되지 않으면 HTML 페이지가 저장될 수 있어요.
> 
> 
> 위의 `-L` 옵션은 그런 상황을 해결해줍니다!
> 

## 🧠 참고: 주요 오류 원인

| 증상 | 원인 | 해결 방법 |
| --- | --- | --- |
| `go: command not found` | Go 설치 안 됨 | 위 설치 절차 진행 |
| `not in gzip format` | 잘못된 파일 받음 (HTML 등) | 공식 미러에서 다시 받기 |
| `No such file or directory` | 파일 이름 오타 or 없음 | `ls -lh`로 존재 확인 |

| 항목 | 상태 |
| --- | --- |
| `docker build` 성공 | ✅ |
| `docker run -d -p 8080:8080 golang-app` | ✅ |
| `curl localhost:8080` → `Hello from ECS on Fargate!` | ✅ 정상 동작 |

## 📦 다음 단계 추천: ECS Fargate에 배포

이제 아래 단계를 따라 `AWS ECS`에 배포하실 수 있어요: