function get_ssm_parameter() {
  aws ssm get-parameter --name "$1" --with-decryption --query 'Parameter.Value' --output text
}

function get_elasti_cache_endpoint() {
  aws elasticache describe-cache-clusters --show-cache-node-info --cache-cluster-id $1 --query "CacheClusters[].CacheNodes[].Endpoint.Address | [0]" --output text
}

function ssm-tunnel() {
    aws ssm start-session --target $BASTION_ID --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host=$1,portNumber=$2,localPortNumber=$3
}

fetch_aws_data () {
        BASTION_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=MC Bastion" --query "Reservations[].Instances[].InstanceId | [0]" --output text)
        RDS_STAGING_HOST=$(get_ssm_parameter "/Staging/DB_HOST")
        RDS_STRAPI_STAGING_HOST=$(get_ssm_parameter "/Staging/Strapi/DBHost")
        EC_API_V2_PRODUCTION_ENDPOINT=$(get_elasti_cache_endpoint "mobileclub-production-redis-api-v2-001")
        EC_JOBS_PRODUCTION_ENDPOINT=$(get_elasti_cache_endpoint "mobileclub-production-redis")
        EC_API_V2_STAGING_ENDPOINT=$(get_elasti_cache_endpoint "mobileclub-staging-redis-api-v2")
        EC_JOBS_STAGING_ENDPOINT=$(get_elasti_cache_endpoint "mobileclub-staging-redis")
}

alias rds-production='ssm-tunnel production.mobileclub.internal "5432" "6000"'
alias rds-ro='ssm-tunnel production.mobileclub.internal "5432" "6000"'
alias rds-strapi-production='ssm-tunnel "$RDS_STRAPI_PRODUCTION_HOST" "5432" "7000"'

alias rds-staging='ssm-tunnel "$RDS_STAGING_HOST" "5432" "6001"'
alias rds-strapi-staging='ssm-tunnel "$RDS_STRAPI_STAGING_HOST" "5432" "7001"'

alias ec-api-v2-production='ssm-tunnel "$EC_API_V2_PRODUCTION_ENDPOINT" "6379" "8000"'
alias ec-jobs-production='ssm-tunnel "$EC_JOBS_PRODUCTION_ENDPOINT" "6379" "9000"'

alias ec-api-v2-staging='ssm-tunnel "$EC_API_V2_STAGING_ENDPOINT" "6379" "8001"'
alias ec-jobs-staging='ssm-tunnel "$EC_JOBS_STAGING_ENDPOINT" "6379" "9001"'
