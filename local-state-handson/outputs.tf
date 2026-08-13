output "bucket_name" {
  value = aws_s3_bucket.handson.id
}

output "bucket_arn" {
  value = aws_s3_bucket.handson.arn
}
