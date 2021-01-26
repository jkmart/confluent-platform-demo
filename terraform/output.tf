output "data-connections" {
  value = [for instance in aws_instance.data_blade : format("%s: %s", lookup(instance.tags, "Name", "?"), instance.public_dns)]
}

output "util-connections" {
  value = [for instance in aws_instance.util_blade : format("%s: %s", lookup(instance.tags, "Name", "?"), instance.public_dns)]
}

output "brokers" {
  value = formatlist("%s:9092", [
      aws_instance.data_blade[0].public_dns,
      aws_instance.data_blade[2].public_dns,
      aws_instance.data_blade[3].public_dns,
      aws_instance.data_blade[5].public_dns,
      aws_instance.data_blade[6].public_dns
    ])
}

output "repo-connections" {
  value = [for instance in aws_instance.satellite : format("%s: %s", lookup(instance.tags, "Name", "?"), instance.public_dns)]
}

output "connect_rest_endpoint" {
  value = [
    length(aws_instance.util_blade.*) >= 2 ?  format("http://%s:8083", aws_instance.util_blade[0].public_dns) : null]
}

output "schema_registry_endpoint" {
  value = [
    length(aws_instance.util_blade.*) >= 2 ?  format("http://%s:8081 ", aws_instance.util_blade[1].public_dns) : null]
}

output "c3_endpoint" {
  value = [
    length(aws_instance.util_blade.*) >= 2 ?  format("http://%s:9021", aws_instance.data_blade[8].public_dns) : null]
}