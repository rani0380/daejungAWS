resource "aws_instance" "bastion" {
  ami                         = "ami-0c55b159cbfafe1f0" # Amazon Linux 2
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.hub_public.id
  associate_public_ip_address = true
  key_name                    = "your-key"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  tags = { Name = "Bastion-Host" }
}
