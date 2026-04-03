output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "pub_sub_1a_id" {
  value = aws_subnet.pub_sub_1a.id
}
output "pub_sub_2b_id" {
  value = aws_subnet.pub_sub_2b.id
}