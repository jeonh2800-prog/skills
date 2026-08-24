module "file" {
  source = "./modules/file"
}

module "vpc" {
  source = "./modules/vpc"

  for_each = local.vpcs

  az_override      = local.az_override
  azs              = local.azs
  enable_igw       = each.value.enable_igw
  enable_natgw     = each.value.enable_natgw

  default_rtb_tags = each.value.default_rtb_tags
  default_sg_tags  = each.value.default_sg_tags
  vpc_name         = each.key
  vpc_cidr         = each.value.vpc_cidr
  vpc_tags         = each.value.vpc_tags
  types            = each.value.types
}

module "security_group" {
  depends_on = [ module.vpc ]
  source = "./modules/security_group"

  for_each = local.security_groups

  vpc_id                = module.vpc[each.value.vpc_name].vpc_id

  security_group_name   = each.value.security_group_name
  security_group_tags   = each.value.security_group_tags
  ingress_ports         = each.value.ingress_ports
  egress_ports          = each.value.egress_ports
}

module "ec2" {
  depends_on = [ module.vpc, module.rds, module.secrets_manager_rds, module.rds_proxy, module.secrets_manager_rds_proxy, module.file, module.security_group, module.ecr, module.s3 ]

  source = "./modules/ec2"

  for_each = local.ec2s

  vpc_id                = module.vpc[each.value.vpc_name].vpc_id
  subnet_id             = module.vpc[each.value.vpc_name].subnet_ids[each.value.subnet_name]
  player_number         = local.player_number
  name                  = each.key

  instance_type         = each.value.instance_type
  userdata              = each.value.userdata
  instance_tags         = each.value.instance_tags

  enable_public_ip      = each.value.enable_public_ip
  enable_eip            = each.value.enable_eip
  eip_tags              = each.value.eip_tags

  root_block_device     = each.value.root_block_device

  security_group_name   = each.value.security_group_name
  security_group_tags   = each.value.security_group_tags
  ingress_ports         = each.value.ingress_ports
  egress_ports          = each.value.egress_ports

  enable_create_keypair = each.value.enable_create_keypair
  keypair_name          = each.value.keypair_name
  keypair_file_path     = each.value.keypair_file_path

  enable_create_iam_role = each.value.enable_create_iam_role
  iam_role_name         = each.value.iam_role_name
  instance_profile_name = each.value.instance_profile_name
  iam_policies          = each.value.iam_policies
}

module "ecr" {
  source = "./modules/ecr"

  for_each = local.ecrs

  name                     = each.key
  tags                     = each.value.tags
  image_tag_mutability     = each.value.image_tag_mutability
  force_delete             = each.value.force_delete
  scan_images_on_push      = each.value.scan_images_on_push

  encryption_configuration = each.value.enable_kms ? {
    encryption_type = each.value.encryption_type
    kms_key = null
  } : null
  image_tag_mutability_exclusion_filter = each.value.enable_image_tag_exclusion_filter ? each.value.image_tag_exclusion_filter : []
}

module "rds" {
  depends_on = [ module.vpc ]
  
  source = "./modules/rds"

  for_each = local.rdss

  vpc_id                        = module.vpc[each.value.vpc_name].vpc_id
  protect_subnet_ids            = module.vpc[each.value.vpc_name].protect_subnet_ids
  name                          = each.key
  instance_tags                 = each.value.instance_tags

  db_name                       = each.value.db_name
  class                         = each.value.class
  storage_type                  = each.value.storage_type
  engine                        = each.value.engine
  engine_version                = each.value.engine_version
  user_name                     = each.value.user_name
  user_password                 = each.value.user_password
  port                          = each.value.port
  allocated_storage             = each.value.allocated_storage
  skip_final_snapshot           = each.value.skip_final_snapshot
  multi_az                      = each.value.multi_az
  storage_encrypted             = each.value.storage_encrypted
  publicly_accessible           = each.value.publicly_accessible

  subnet_group_name             = each.value.subnet_group_name
  subnet_group_tags             = each.value.subnet_group_tags

  option_group_name             = each.value.option_group_name
  option_group_engine           = each.value.option_group_engine
  option_group_engine_version   = each.value.option_group_engine_version
  option_group_tags             = each.value.option_group_tags

  parameter_group_name          = each.value.parameter_group_name
  parameter_group_family        = each.value.parameter_group_family
  parameter_group_tags          = each.value.parameter_group_tags

  security_group_name           = each.value.security_group_name
  security_group_tags           = each.value.security_group_tags
  ingress_ports                 = each.value.ingress_ports
  egress_ports                  = each.value.egress_ports
}

module "rds_proxy" {
  depends_on = [ module.rds, module.secrets_manager_rds ]
  
  source = "./modules/rds-proxy"

  for_each = local.rds_proxys

  vpc_id                       = module.vpc[each.value.vpc_name].vpc_id
  protect_subnet_ids           = module.vpc[each.value.vpc_name].protect_subnet_ids

  name                         = each.key
  tags                         = each.value.tags

  debug_logging                = each.value.debug_logging
  engine_family                = each.value.engine_family
  idle_client_timeout          = each.value.idle_client_timeout
  require_tls                  = each.value.require_tls
  secrets_manager_arn          = module.secrets_manager_rds[each.value.secrets_manager_name].secrets_manager_arn
  connection_borrow_timeout    = each.value.connection_borrow_timeout
  max_connections_percent      = each.value.max_connections_percent
  max_idle_connections_percent = each.value.max_idle_connections_percent

  enable_db_cluster            = each.value.enable_db_cluster
  db_cluster_identifier        = each.value.enable_db_cluster ? module.rds[each.value.db_cluster_name].rds_identifier : null

  enable_db_instance           = each.value.enable_db_instance
  db_instance_identifier       = each.value.enable_db_instance ? module.rds[each.value.db_instance_name].rds_identifier : null

  security_group_name          = each.value.security_group_name
  security_group_tags          = each.value.security_group_tags
  ingress_ports                = each.value.ingress_ports
  egress_ports                 = each.value.egress_ports

  role_name                    = each.key
  role_tags                    = each.value.role_tags
  role_statements              = each.value.role_statements
  policy_statements            = each.value.policy_statements
  enable_custom_policy         = each.value.enable_custom_policy
  policy_name                  = each.value.policy_name
  policy_tags                  = each.value.policy_tags
  enable_managed_policy        = each.value.enable_managed_policy
  managed_policy_arns          = each.value.managed_policy_arns
}

module "secrets_manager_rds" {
  depends_on = [ module.rds ]
  
  source = "./modules/secrets-manager"

  for_each = {for k, v in local.secrets_managers : k => v if k == "${local.parameter}-rds-secrets"}

  name = each.key
  tags = each.value.tags

  secret_values = (
    can(each.value.enable_values) ? {
      username     = module.rds[each.value.rds_name].rds_user_name
      password = module.rds[each.value.rds_name].rds_user_password
      host     = module.rds[each.value.rds_name].rds_address
      port     = module.rds[each.value.rds_name].rds_port
      database = module.rds[each.value.rds_name].rds_db_name
    }
    : {}
  )
}

module "secrets_manager_rds_proxy" {
  depends_on = [ module.rds, module.secrets_manager_rds ,module.rds_proxy ]
  
  source = "./modules/secrets-manager"

  for_each = {for k, v in local.secrets_managers : k => v if k == "${local.parameter}-rds-proxy-secrets"}


  name = each.key
  tags = each.value.tags

  secret_values = (
    can(each.value.enable_values) ? {
      MYSQL_USER     = module.rds[each.value.rds_name].rds_user_name
      MYSQL_PASSWORD = module.rds[each.value.rds_name].rds_user_password
      MYSQL_HOST     = module.rds_proxy[each.value.rds_proxy_name].rds_proxy_address
      MYSQL_PORT     = module.rds[each.value.rds_name].rds_port
      MYSQL_DATABASE = module.rds[each.value.rds_name].rds_db_name
    }
    : {}
  )
}

module "s3" {
  source = "./modules/s3"

  for_each = local.s3s

  name                    = each.key
  tags                    = each.value.tags
  enable_objects          = each.value.enable_objects
  objects                 = each.value.objects
  enable_object_kms       = each.value.enable_object_kms
  kms_arn                 = null
  block_public_access     = each.value.block_public_access
  block_public_acls       = each.value.block_public_acls
  block_public_policy     = each.value.block_public_policy
  ignore_public_acls      = each.value.ignore_public_acls
  restrict_public_buckets = each.value.restrict_public_buckets
  enable_versioning       = each.value.enable_versioning
}

module "cloudfront" {
  depends_on = [ module.s3, module.waf ]

  source = "./modules/cloudfront"

  for_each = local.cloudfronts
  
  tags                           = each.value.tags
  origin_path                    = each.value.origin_path
  default_root_object            = each.value.default_root_object
  
  enable_cloudfront_function     = each.value.enable_cloudfront_function
  cloudfront_function_name       = each.value.cloudfront_function_name
  cloudfront_function_runtime    = each.value.cloudfront_function_runtime
  cloudfront_function_publish    = each.value.cloudfront_function_publish
  cloudfront_function_code_path  = each.value.cloudfront_function_code_path
  enable_access_logs             = each.value.enable_access_logs
  logging_config                 = each.value.logging_config
  s3_log_bucket_id               = module.s3[each.value.logging_config.s3_bucket_name].s3_bucket_id

  s3_bucket_id                   = module.s3[each.value.s3_bucket_name].s3_bucket_id
  s3_bucket_arn                  = module.s3[each.value.s3_bucket_name].s3_bucket_arn
  s3_bucket_regional_domain_name = module.s3[each.value.logging_config.s3_bucket_name].s3_bucket_regional_domain_name
  
  enable_waf                     = each.value.enable_waf
  waf_id                         = module.waf[each.value.waf_name].waf_arn
}

module "waf" {
  source = "./modules/waf"

  providers = { aws = aws.us_east_1 }

  for_each = local.wafs

  name                   = each.key
  tags                   = each.value.tags
  metric_name            = each.value.metric_name
  enable_cloudfront      = each.value.enable_cloudfront
  alb_arn                = null
  enable_managed         = each.value.enable_managed
  managed_rules          = each.value.managed_rules
  enable_custom          = each.value.enable_custom
  custom_rules           = each.value.custom_rules
  enable_logging         = each.value.enable_logging
  log_destination_arns   = null

  default_action         = each.value.default_action
  default_block_response = each.value.default_block_response
  custom_response_key    = each.value.custom_response_key
  custom_response_body   = each.value.custom_response_body
}