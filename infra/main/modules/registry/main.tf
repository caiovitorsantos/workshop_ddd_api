# Private image registry for the API (the worker and the migration Job use the
# same image).
resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE" # a tag is a commit SHA; it never moves

  image_scanning_configuration {
    scan_on_push = true
  }

  # `terraform destroy` at the end of a lab day must not stall on images.
  force_delete = true
}

# Keep the last N images: enough to roll back, not enough to pile up storage.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep the last ${var.keep_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_images
      }
      action = { type = "expire" }
    }]
  })
}
