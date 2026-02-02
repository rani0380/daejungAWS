# Docker 빌드/배포

## **배포 순서**

1. EC2 인스턴스(t2.medium) 생성 및 보안설정
2. Docker 및 Docker Compose 설치
3. Docker Compose를 이용한 웹 애플리케이션 컨테이너 배포
4. Route 53을 사용한 도메인 연결(nest-dev.click) 및 외부 접속 설정

> 먼저 AWS 콘솔에서 로그인 후 ec2 인스턴스를 시작하여 생성해 주었다.
> 

*여기서 aws 아이디는 같이 최종 프로젝트를 진행 중인 팀원들과 함께 배포를 진행하고 있기 때문에 관리자 권한을 받은 IAM유저로 로그인을 진행하였다.*

*참고로 현재 설정 중인 인스턴스 유형은 유료이다.*

*프리티어인 유형은  최종 전 프로젝트 때 사용했지만, 너무 잦은 서버 에러 때문에 불편을 겪어 최종 프로젝트에서는 유료를 사용하기로 했다...(돈이 좋다 역시..🙃)*

**✅ 인스턴스 기본 설정**

| 이름 | 원하는 이름 지정 (예: docker-app-instance) |
| --- | --- |
| AMI | Ubuntu Server 22.04 LTS |
| 아키텍처 | amd64 (x86_64) |
| 인스턴스 유형 | t2.medium |

*키 페어는 SSH 보안을 위한 것으로, 실제 운영 환경에서는 필수 설정이다. 테스트 목적이라면 생략 가능하지만, 보안상 SSH 키 페어 생성을 권장한다.*

**✅ 인스턴스 네트워크 설정**

아래는 현재 설정한 EC2 인스턴스의 보안 그룹 설정한 캡처 사진이다.

![](https://blog.kakaocdn.net/dna/baHdcM/btsOMeonkr0/AAAAAAAAAAAAAAAAAAAAAAQKO4cY5CWzKj-7Gd5Tk6wbw1GPadVg9BdK0TOGp2nc/img.png?credential=yqXZFxpELC7KVnFOS48ylbz2pIh7yKj8&expires=1759244399&allow_ip=&allow_referer=&signature=Th34Vt%2FK3sh8Epb7Za6oxwzvmq8%3D)

- **SSH (22)** 접근:원격 터미널 접속을 위한 필수 설정이며, 실무 환경에서는 접근 가능한 IP를 특정 IP로 제한하는 것이 권장된다.
- **HTTP (80)** 접근:웹 애플리케이션이 80 포트를 사용할 경우 필수 설정이다. 일반적으로 HTTP 웹 서비스 접근을 위한 기본 포트다.
- **Docker 컨테이너 앱 (8080)** 접근:Docker로 구동한 앱 서비스의 기본 접근 포트로, 설정한 컨테이너의 포트(예: 8080)에 맞춰 설정한다.

# EC2에서 Docker Build & Push 실전 가이드 (ECR 기준)

목표: **로컬 PC를 거치지 않고** EC2에서 바로 Docker 이미지를 빌드하고 **Amazon ECR**로 Push하여, 이후 ECS/EKS/쿠버네티스 배포에 즉시 활용할 수 있도록 함.

---

## 0. 사전 준비 체크

- EC2 OS: Amazon Linux 2023 (권장)
- IAM: EC2 인스턴스 프로파일에 **ECR 권한**, **S3(선택)**, **CloudWatch(선택)** 포함
- 네트워크: 인터넷 통신 또는 프록시 경유 가능 (VPC 엔드포인트로 ecr.dkr, ecr.api, s3 사용 시 프라이빗 빌드 가능)
- 리전: **ap-northeast-2 (서울)** 기준 예시, 필요 시 바꿔서 사용

---

## 1) EC2에 Docker 설치 및 기본 설정

```bash
# 기본 패키지 업데이트 및 도커 설치
sudo dnf -y update
sudo dnf -y install docker git tar gzip jq

# 도커 서비스 기동 및 부팅 자동 시작
sudo systemctl enable --now docker

# ec2-user가 sudo 없이 docker 명령 사용 가능하도록 권한 추가
sudo usermod -aG docker ec2-user
# 현재 쉘에 그룹 변경 반영 (새 세션 열어도 OK)
newgrp docker

# (선택) BuildKit 활성화로 빌드 속도/캐시 최적화
export DOCKER_BUILDKIT=1

```

> ⚠️ 문제 해결: Got permission denied while trying to connect to the Docker daemon socket → 도커 그룹 재로그인(newgrp) 또는 EC2 재접속 후 해결.
> 

---

## 2) ECR 로그인 & 리포지토리 준비

```bash
# 공통 환경변수 세팅
REGION=ap-northeast-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# ECR 로그인 (세션마다 12시간 내외 유효)
aws ecr get-login-password --region "$REGION" \
| docker login --username AWS --password-stdin "$REGISTRY"

# 리포지토리 생성 (이미 있으면 생성 스킵)
for repo in skills-green-repo skills-red-repo; do
  aws ecr describe-repositories --repository-names "$repo" --region "$REGION" >/dev/null 2>&1 \
  || aws ecr create-repository \
       --repository-name "$repo" \
       --image-tag-mutability IMMUTABLE \
       --encryption-configuration encryptionType=KMS \
       --image-scanning-configuration scanOnPush=true \
       --region "$REGION"
  echo "ECR repo ready: $repo"
done

```

> ✅ Immutable 태그와 취약점 스캔, KMS 암호화 활성화는 대회 채점 및 보안 모범사례에 부합.
> 

---

## 3) 빌드 자원 준비 (소스/바이너리/도커파일)

### A. GitHub/압축파일로 가져오기

```bash
# 예: 저장소 클론
mkdir -p ~/images && cd ~/images
# git clone https://github.com/<YOUR>/<REPO>.git  # 필요 시

```

### B. S3에서 내려받기 (경기 자료 제공 방식 대응)

```bash
# 예: S3에서 제공된 바이너리/도커파일 다운로드 (버킷/키는 상황에 맞게 대체)
BUCKET_NAME=skills-chart-bucket-ABCD
mkdir -p ~/images/green ~/images/red
aws s3 cp s3://$BUCKET_NAME/images/green_1.0.1 ~/images/green
aws s3 cp s3://$BUCKET_NAME/images/red_1.0.1   ~/images/red

```

### C. 최소 예시 Dockerfile (바이너리 실행형, curl 포함)

> 컨테이너 내부에서 curl 사용 요구가 잦으므로 apk add curl 포함 예시를 제공합니다.
> 

```
# ~/images/green/Dockerfile (red도 유사)
FROM alpine:3.20
WORKDIR /app
# 바이너리 파일을 컨테이너에 복사 (권한 부여)
COPY green_1.0.1 /usr/local/bin/app
RUN chmod +x /usr/local/bin/app \
    && apk add --no-cache curl
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]

```

### D. .dockerignore (빌드 컨텍스트 최적화)

```
# ~/images/green/.dockerignore
*.log
*.tmp
.git
.gitignore
__pycache__
node_modules
*.zip
*.tgz

```

---

## 4) Docker Build & Tag & Push (EC2에서 직접)

### Green 이미지

```bash
cd ~/images/green
IMG_G="$REGISTRY/skills-green-repo:v1.0.1"

# 빌드 (BuildKit 활성화 시 더 빠르고 캐시 효율적)
docker build -t "$IMG_G" .

# 푸시
docker push "$IMG_G"

```

### Red 이미지

```bash
cd ~/images/red
IMG_R="$REGISTRY/skills-red-repo:v1.0.1"

docker build -t "$IMG_R" .
docker push "$IMG_R"

```

### Push 검증

```bash
aws ecr describe-images \
  --repository-name skills-green-repo \
  --image-ids imageTag=v1.0.1 \
  --query 'imageDetails[0].[imageDigest,imagePushedAt]' \
  --output table --region "$REGION"

```

> 💡 태그는 대회 지시에 맞춰 v1.0.0 → v1.0.1로 승급하는 경우가 많습니다. Immutable 설정 시 기존 태그 재사용 불가.
> 

---

## 5) (선택) 멀티 아키텍처/플랫폼 주의

- EC2 인스턴스가 x86_64(t3, m5 등)인 경우: 기본 `linux/amd64` 이미지 빌드 → EKS/ECS 노드 타입과 일치 필요
- Graviton(ARM, c7g 등)에서 **amd64 대상** 이미지를 빌드하려면 **buildx**를 사용해 교차 빌드

```bash
# buildx 준비
docker buildx create --use --name ec2builder

# 예: amd64 이미지를 ARM EC2에서 빌드 & 즉시 푸시
cd ~/images/green
docker buildx build \
  --platform linux/amd64 \
  -t "$IMG_G" \
  --push .

```

> ⚠️ exec format error 발생 시 플랫폼/아키텍처 불일치를 의심하세요.
> 

---

## 6) 속도·안정성 향상 팁

- **BuildKit 캐시**: 반복 빌드 시 큰 효과. 멀티스테이지 빌드로 의존성 계층 분리
- **.dockerignore**로 빌드 컨텍스트 최소화 (특히 `.git`, `node_modules` 제외)
- **레이어 순서 최적화**: 자주 바뀌는 `COPY . .`를 하단으로 내려 캐시 적중률↑
- **ECR 로그인 유지**: 세션 만료 시 빌드 직전 재로그인 습관화
- **S3→EC2 직접 다운로드**: 로컬 전송 단계 제거 (대회 시간 절약 핵심)

---

## 7) 자주 만나는 오류와 해결

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `permission denied /var/run/docker.sock` | 도커 소켓 권한 | `usermod -aG docker ec2-user` 후 `newgrp docker` or 재로그인 |
| `no basic auth credentials` | ECR 로그인 만료/미실행 | `aws ecr get-login-password |
| `manifest unknown` | 태그 오타/이미지 미존재 | 태그/리포지토리명 점검, `describe-images`로 확인 |
| `exec format error` | 바이너리와 플랫폼 불일치 | buildx로 `--platform` 지정 빌드, 또는 노드 아키 맞추기 |
| `docker build` 느림 | 컨텍스트 과대/캐시 미활용 | `.dockerignore`, 레이어 순서 최적화, BuildKit 사용 |
| `The repository with name ... does not exist` | ECR 리포 미생성 | `create-repository`로 사전 생성 |

---

## 8) (부록) 간단 Go 바이너리 빌드 → 컨테이너화 예시

> 소스가 있을 때 EC2에서 바로 빌드 후 컨테이너화
> 

```bash
# 1) Go 설치(필요 시) & 바이너리 빌드
sudo dnf -y install golang
mkdir -p ~/app && cd ~/app
cat > main.go <<'GO'
package main
import (
  "fmt"
  "net/http"
)
func main(){
  http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request){
    w.Write([]byte("ok"))
  })
  http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request){
    fmt.Fprintf(w, "hello")
  })
  http.ListenAndServe(":8080", nil)
}
GO
GOOS=linux GOARCH=amd64 go build -o app

# 2) Dockerfile 작성
cat > Dockerfile <<'DOCKER'
FROM alpine:3.20
WORKDIR /app
COPY app /usr/local/bin/app
RUN chmod +x /usr/local/bin/app && apk add --no-cache curl
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]
DOCKER

# 3) 빌드 & 푸시
IMG="$REGISTRY/skills-green-repo:v1.0.1"
docker build -t "$IMG" .
docker push "$IMG"

```

---

## 9) 빠른 레시피 (복붙용)

```bash
# ===== 0. 변수 =====
REGION=ap-northeast-2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
export DOCKER_BUILDKIT=1

# ===== 1. 도커 설치 =====
sudo dnf -y update && sudo dnf -y install docker jq tar gzip
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user && newgrp docker

# ===== 2. ECR 로그인/리포 생성 =====
aws ecr get-login-password --region "$REGION" \
| docker login --username AWS --password-stdin "$REGISTRY"
for repo in skills-green-repo skills-red-repo; do
  aws ecr describe-repositories --repository-names "$repo" --region "$REGION" >/dev/null 2>&1 \
  || aws ecr create-repository \
       --repository-name "$repo" \
       --image-tag-mutability IMMUTABLE \
       --encryption-configuration encryptionType=KMS \
       --image-scanning-configuration scanOnPush=true \
       --region "$REGION"
done

# ===== 3. 예시: green 빌드 & 푸시 =====
mkdir -p ~/images/green && cd ~/images/green
cat > Dockerfile <<'DOCKER'
FROM alpine:3.20
WORKDIR /app
COPY green_1.0.1 /usr/local/bin/app
RUN chmod +x /usr/local/bin/app && apk add --no-cache curl
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]
DOCKER
# (필요 시) green_1.0.1 바이너리 배치
# aws s3 cp s3://<YOUR_BUCKET>/images/green_1.0.1 .  # 예시
IMG_G="$REGISTRY/skills-green-repo:v1.0.1"
docker build -t "$IMG_G" . && docker push "$IMG_G"

# ===== 4. 예시: red 빌드 & 푸시 =====
mkdir -p ~/images/red && cd ~/images/red
cat > Dockerfile <<'DOCKER'
FROM alpine:3.20
WORKDIR /app
COPY red_1.0.1 /usr/local/bin/app
RUN chmod +x /usr/local/bin/app && apk add --no-cache curl
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]
DOCKER
# (필요 시) red_1.0.1 바이너리 배치
# aws s3 cp s3://<YOUR_BUCKET>/images/red_1.0.1 .
IMG_R="$REGISTRY/skills-red-repo:v1.0.1"
docker build -t "$IMG_R" . && docker push "$IMG_R"

```

---

### 마무리

이 문서의 흐름대로 수행하면 **로컬 전송 없이** EC2에서 바로 Docker 이미지를 빌드·푸시할 수 있습니다. 이후 ECS/EKS에 배포하거나 ArgoCD/CodePipeline과 연계하여 자동 배포 파이프라인을 검증하세요.