variable "vpc_id" {
  type = string
}

variable "protect_subnet_ids" {
  type = list(string)
}

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "debug_logging" {
  type = bool
}

variable "engine_family" {
  type = string
}

variable "idle_client_timeout" {
  type = number
}

variable "require_tls" {
  type = bool
}

variable "secrets_manager_arn" {
  type = string
}

variable "connection_borrow_timeout" {
  type    = number
}

variable "max_connections_percent" {
  type    = number
}

variable "max_idle_connections_percent" {
  type    = number
}

variable "enable_db_cluster" {
  type    = bool
  default = false
}

variable "db_cluster_identifier" {
  type    = string
}

variable "enable_db_instance" {
  type    = bool
  default = false
}

variable "db_instance_identifier" {
  type    = string
}

variable "role_name" {
  type = string
}

variable "role_tags" {
  type    = map(string)
}

variable "role_statements" {
  type = list(object({
    sid    = optional(string)
    effect = string

    principals = optional(object({
      type        = string
      identifiers = list(string)
    }))

    actions   = list(string)
    resources = list(string)

    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
}

variable "policy_statements" {
  type = list(object({
    sid    = optional(string)
    effect = string

    principals = optional(object({
      type        = string
      identifiers = list(string)
    }))

    actions   = list(string)
    resources = list(string)

    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
}

variable "enable_custom_policy" {
  type    = bool
}

variable "policy_name" {
  type    = string
}

variable "policy_tags" {
  type    = map(string)
}

variable "enable_managed_policy" {
  type    = bool
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "security_group_name" {
  type  = string
}

variable "security_group_tags" {
  type = map(string)
}

variable "ingress_ports" {
  type = list(object({
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_block       = optional(string)
    prefix_list_id   = optional(string)
    security_groups = optional(list(string))
  }))
}

variable "egress_ports" {
  type = list(object({
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_block       = optional(string)
    prefix_list_id   = optional(string)
    security_groups = optional(list(string))
  }))
}