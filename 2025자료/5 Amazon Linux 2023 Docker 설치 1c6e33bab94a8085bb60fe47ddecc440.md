# 5. Amazon Linux 2023 Docker 설치

### 필수 도구 설치

```bash
sudo yum update -y
sudo yum install -y docker git
sudo service docker start
sudo usermod -aG docker ec2-user
newgrp docker  # 권한 반영

```

아래 방법으로 Docker를 설치하세요:

```bash
# 1. 도커 엔진 설치
sudo dnf install docker -y

# 2. 도커 서비스 실행 및 부팅 시 자동 시작 설정
sudo systemctl start docker
sudo systemctl enable docker

# 3. 현재 사용자(ec2-user)를 docker 그룹에 추가
sudo usermod -aG docker ec2-user
# usermod -aG docker ec2-user 명령은 현재 로그인된 ec2-user 계정에 도커 그룹 권한을 부여하지만, 적용은 다음 로그인 세션부터 반영되기 때문에 “한 번 나갔다가 다시 접속” 해야 합니다.
# 4. 세션에 그룹 적용
newgrp docker
```

## ✅ 설치 확인

```bash
docker version
docker run hello-world #테스트용 이미지 작성
```

## ✅ 재접속 후 확인

```bash
docker ps
→ 에러 없이 실행된다면, `docker` 그룹 권한이 제대로 적용된 것입니다!
```

![image.png](5%20Amazon%20Linux%202023%20Docker%20%EC%84%A4%EC%B9%98/image.png)

## ❗ Amazon Linux 버전 확인 팁

```bash
cat /etc/os-release
```

- 출력에 `Amazon Linux 2`면 extras 사용 가능
- `Amazon Linux 2023`이면 `dnf` 방식만 지원

### 🧠 요약 정리

| 버전 | Docker 설치 방식 |
| --- | --- |
| Amazon Linux 2 | `amazon-linux-extras enable docker` + `yum` |
| Amazon Linux 2023 | `dnf install docker` |