# AWS Client VPN Endpoint 생성

## ✅ 1. **Terraform에서 필요한 값 확인 및 설정**

### [필요한 값 정리]

- ✅ ACM에 업로드한 인증서의 ARN → **서버 인증서 ARN**
- ✅ VPC ID
- ✅ 서브넷 ID (하나 이상)
- ✅ 보안 그룹 ID

---

## ✅ 2. **Terraform 구성 예시**

```hcl
provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_ec2_client_vpn_endpoint" "vpn" {
  client_cidr_block       = "10.0.0.0/22"
  server_certificate_arn  = "arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  }
  connection_log_options {
    enabled = false
  }
  dns_servers         = ["8.8.8.8", "8.8.4.4"]
  split_tunnel        = true
  transport_protocol  = "udp"
  description         = "My Client VPN Endpoint"
  vpn_port            = 443
  security_group_ids  = ["sg-0abc12345def67890"]
  vpc_id              = "vpc-0abc12345def67890"
  tags = {
    Name = "terraform-client-vpn"
  }
}

resource "aws_ec2_client_vpn_network_association" "assoc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = "subnet-0abc12345def67890"
}

resource "aws_ec2_client_vpn_authorization_rule" "auth" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = "0.0.0.0/0"
  authorize_all_groups   = true
}

```

---

### ✅ 예시 : 사용자 정보 정리

![image.png](AWS%20Client%20VPN%20Endpoint%20%EC%83%9D%EC%84%B1/image.png)

| 항목 | 값 |
| --- | --- |
| **VPC ID** | `vpc-08525e5f9bb0671bc` |
| **Subnet ID** | `subnet-04bc020fadb38a865` |
| **EC2 인스턴스 ID** | `i-0bf6e55b977b62462` |
| **퍼블릭 IP** | `43.203.210.189` |
| **프라이빗 IP** | `10.0.1.89` |

---

### ✅ 다음으로 할 일

Terraform 코드로 `aws_ec2_client_vpn_endpoint` 리소스를 생성할 수 있습니다. 아래 예시를 바탕으로 `main.tf`를 작성하세요:

```hcl
hcl
복사편집
resource "aws_ec2_client_vpn_endpoint" "vpn" {
  description           = "Client VPN Endpoint"
  server_certificate_arn = "arn:aws:acm:ap-northeast-2:343218185676:certificate/801f0f55-58b4-42a8-b71c-b3bccee1c058"
  client_cidr_block     = "10.0.0.0/22"
  split_tunnel          = true
  transport_protocol    = "udp"
  vpn_port              = 443

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:ap-northeast-2:343218185676:certificate/801f0f55-58b4-42a8-b71c-b3bccee1c058"
  }

  connection_log_options {
    enabled = false
  }

  dns_servers = ["8.8.8.8", "8.8.4.4"]

  tags = {
    Name = "TerraformClientVPN"
  }
}

resource "aws_ec2_client_vpn_network_association" "vpn_subnet_assoc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  subnet_id              = "subnet-04bc020fadb38a865"
  vpc_id                 = "vpc-08525e5f9bb0671bc"
}

resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
  target_network_cidr    = "10.0.0.0/16"
  authorize_all_groups   = true
  description            = "Allow access to entire VPC"
}

```

## ✅ 3. **Terraform 적용**

```bash
terraform init
terraform apply

```

---

## ✅ 4. 생성 후 해야 할 것

| 항목 | 설명 |
| --- | --- |
| 클라이언트 구성 파일 다운로드 | AWS 콘솔 → Client VPN → 엔드포인트 선택 → "클라이언트 구성 다운로드" |
| OpenVPN 또는 AWS VPN Client 사용 | 구성 파일과 client 인증서, key 파일을 함께 사용 |