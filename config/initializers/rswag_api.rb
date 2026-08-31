Rswag::Api.configure do |c|
  # Where `rake rswag:specs:swaggerize` writes the generated OpenAPI documents,
  # and where the /api-docs endpoint serves them from.
  c.openapi_root = Rails.root.join("swagger").to_s
end
