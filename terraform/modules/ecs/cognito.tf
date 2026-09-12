# =====================================================
# COGNITO USER POOL (managed authentication)
#
# The api-gateway validates the JWT (RS256, via the pool JWKS) on every
# request under /api/. The test user is created by scripts/create-test-user.sh
# (permanent password) rather than Terraform so the password is not kept in
# state.
# =====================================================

resource "aws_cognito_user_pool" "main" {
  name = "cloud-design-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  auto_verified_attributes = ["email"]

  tags = {
    Name = "cloud-design-user-pool"
  }
}

resource "aws_cognito_user_pool_client" "app" {
  name         = "cloud-design-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Allow CLI/API auth so we can obtain tokens for testing.
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # OAuth settings (hosted UI / OIDC).
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  callback_urls = ["https://${var.lb_dns_name}/oauth2/idpresponse"]
  logout_urls   = ["https://${var.lb_dns_name}/"]
}
