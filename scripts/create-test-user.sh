#!/usr/bin/env bash
#
# create-test-user.sh — create/confirm a Cognito test user and print an IdToken.
#
# Usage:
#   ./create-test-user.sh <user-pool-id> <app-client-id> [username] [password]
#
# The password is generated if not supplied and always satisfies the pool policy
# (upper, lower, number, >= 8 chars).
#
set -euo pipefail

POOL_ID="${1:?usage: $0 <user-pool-id> <app-client-id> [username] [password]}"
CLIENT_ID="${2:?usage: $0 <user-pool-id> <app-client-id> [username] [password]}"
USERNAME="${3:-testuser}"
PASSWORD="${4:-Cloud$(openssl rand -hex 4)X9}"

aws cognito-idp admin-create-user \
  --user-pool-id "$POOL_ID" \
  --username "$USERNAME" \
  --message-action SUPPRESS \
  --user-attributes Name=email,Value=test@example.com Name=email_verified,Value=true \
  >/dev/null 2>&1 || true

aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username "$USERNAME" \
  --password "$PASSWORD" \
  --permanent

echo "username: $USERNAME"
echo "password: $PASSWORD"
echo
echo "== IdToken =="
aws cognito-idp admin-initiate-auth \
  --user-pool-id "$POOL_ID" \
  --client-id "$CLIENT_ID" \
  --auth-flow ADMIN_USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$USERNAME",PASSWORD="$PASSWORD" \
  --query 'AuthenticationResult.IdToken' --output text
