resource "aws_security_group" "this" {
  name   = var.security_group_name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      protocol  = ingress.value.protocol
      from_port = ingress.value.from_port
      to_port   = ingress.value.to_port

      cidr_blocks     = lookup(ingress.value, "cidr_block", null) != null ? [ingress.value.cidr_block] : null
      prefix_list_ids = lookup(ingress.value, "prefix_list_id", null) != null ? [ingress.value.prefix_list_id] : null
      security_groups = lookup(ingress.value, "security_groups", null)
    }
  }

  dynamic "egress" {
    for_each = var.egress_ports
    content {
      protocol  = egress.value.protocol
      from_port = egress.value.from_port
      to_port   = egress.value.to_port

      cidr_blocks     = lookup(egress.value, "cidr_block", null) != null ? [egress.value.cidr_block] : null
      prefix_list_ids = lookup(egress.value, "prefix_list_id", null) != null ? [egress.value.prefix_list_id] : null
      security_groups = lookup(egress.value, "security_groups", null)
    }
  }

  tags = var.security_group_tags
}

data "aws_iam_policy_document" "this_role" {
  dynamic "statement" {
    for_each = var.role_statements
    content {
      sid    = try(statement.value.sid, null)
      effect = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "principals" {
        for_each = statement.value.principals != null ? [statement.value.principals] : []
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.this_role.json
}

data "aws_iam_policy_document" "this_policy" {
  dynamic "statement" {
    for_each = var.policy_statements
    content {
      sid    = try(statement.value.sid, null)
      effect = statement.value.effect

      actions   = statement.value.actions
      resources = statement.value.resources

      dynamic "principals" {
        for_each = statement.value.principals != null ? [statement.value.principals] : []
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_iam_policy" "this" {
  count  = var.enable_custom_policy ? 1 : 0

  name   = var.policy_name
  policy = data.aws_iam_policy_document.this_policy.json
  tags   = var.policy_tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  count      = var.enable_custom_policy ? 1 : 0
  
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

resource "aws_db_proxy" "this" {
  name                   = var.name
  debug_logging          = var.debug_logging
  engine_family          = var.engine_family
  idle_client_timeout    = var.idle_client_timeout
  require_tls            = var.require_tls
  role_arn               = aws_iam_role.this.arn
  vpc_security_group_ids = [aws_security_group.this.id]
  vpc_subnet_ids         = var.protect_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = var.secrets_manager_arn
  }

  tags = var.tags
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name

  connection_pool_config {
    connection_borrow_timeout    = var.connection_borrow_timeout
    max_connections_percent      = var.max_connections_percent
    max_idle_connections_percent = var.max_idle_connections_percent
  }
}

resource "aws_db_proxy_target" "cluster" {
  count = var.enable_db_cluster ? 1 : 0
  db_cluster_identifier  = var.db_cluster_identifier
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this.name
}

resource "aws_db_proxy_target" "instance" {
  count = var.enable_db_instance ? 1 : 0
  db_instance_identifier = var.db_instance_identifier
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this.name
}