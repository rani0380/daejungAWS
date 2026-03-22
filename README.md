# WorldPay 유저 관리 시스템

고가용성, 보안, 확장성을 고려한 전 세계 결제 서비스 유저 관리 시스템

## 아키텍처 개요

- **고가용성**: Multi-AZ 배포, Auto Scaling, Load Balancer
- **보안**: 암호화, IAM, VPC, WAF
- **확장성**: 마이크로서비스, 컨테이너화, 서버리스

## 디렉토리 구조

```
├── src/                 # 애플리케이션 소스 코드
├── infrastructure/      # AWS 인프라 코드 (Terraform/CloudFormation)
├── config/             # 설정 파일들
└── docs/               # 문서
```