###cloud vars
variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "default_zone" {
  type        = map(string)
  default     = {
    "a" = "ru-central1-a",
    "b" = "ru-central1-b",
    "d" = "ru-central1-d",
  }
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}
variable "network_cidr" {
  type        = map(list(string))
  default     = {
    a = ["192.168.5.0/24"],
    b = ["192.168.15.0/24"],
    d = ["192.168.25.0/24"],
  }
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}
variable "remote-net_cidr" {
  type        = map(list(string))
  default     = {
    a = ["10.129.0.0/24"],
    b = ["10.129.10.0/24"],
    d = ["10.129.20.0/24"],
  }
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}
variable "vpc_name" {
  type = string
  default = "network"
  description = "Name for virtual network"
}