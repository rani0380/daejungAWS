@echo off
setlocal enabledelayedexpansion

REM AWS 계정 ID 가져오기
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%i
set REGION=ap-northeast-2

echo Account ID: %ACCOUNT_ID%

REM ECR 로그인
for /f "tokens=*" %%i in ('aws ecr get-login-password --region %REGION%') do (
    echo %%i | docker login --username AWS --password-stdin %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com
)

REM 서비스별 이미지 빌드 및 푸시
set SERVICES=user product stress

for %%s in (%SERVICES%) do (
    echo Building and pushing %%s service...
    
    REM 이미지 빌드
    docker build -t skills-task3-competition-%%s ./services/%%s/
    
    REM 태그 지정
    docker tag skills-task3-competition-%%s:latest %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/skills-task3-competition-%%s:latest
    
    REM ECR에 푸시
    docker push %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/skills-task3-competition-%%s:latest
    
    echo %%s service pushed successfully!
)

echo All services pushed to ECR!
pause