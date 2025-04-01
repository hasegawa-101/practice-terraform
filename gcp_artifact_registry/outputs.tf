# 出力値
output "npm_repository_url" {
  description = "The URL of the NPM repository for package.json configuration"
  value       = "${google_artifact_registry_repository.npm_repo.location}-npm.pkg.dev/${google_artifact_registry_repository.npm_repo.project}/${google_artifact_registry_repository.npm_repo.repository_id}"
}