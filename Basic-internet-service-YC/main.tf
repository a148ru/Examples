# основная сеть и подсети
resource "yandex_vpc_network" "network" {
  name = var.vpc_name
}
resource "yandex_vpc_subnet" "network" {
  for_each = var.default_zone
  name           = "subnet-${each.key}"
  zone           = "${each.value}"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = var.network_cidr["${each.key}"]
# Вызовет цикл
# Error: Cycle: yandex_compute_instance.ipsec-instance, yandex_vpc_route_table.vpn-route, yandex_vpc_subnet.network
#  route_table_id = yandex_vpc_route_table.vpn-route.id
}
# удалеенная сеть и подсеть для тестовой вм
resource "yandex_vpc_network" "remote-net" {
  name = "remote-net"
}
resource "yandex_vpc_subnet" "remote-net" {
  name           = "subnet-1"
  zone           = var.default_zone.b
  network_id     = yandex_vpc_network.remote-net.id
  v4_cidr_blocks = var.remote-net_cidr.b
}
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts-oslogin"
}
data "yandex_compute_image" "drupal" {
  family = "drupal"
}
data "yandex_compute_image" "ipsec-instance" {
  family = "ipsec-instance-ubuntu"
}
# удаленная вм
resource "yandex_compute_disk" "remote-wm-disk" {
  name     = "remote-wm-disk"
  type     = "network-hdd"
  zone     = var.default_zone.b
  size     = "20"
  image_id = data.yandex_compute_image.ubuntu.id
}
resource "yandex_compute_instance" "remote-vm" {
  name                      = "remote-vm"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"
  zone                      = var.default_zone.b
  resources {
    cores  = "2"
    memory = "4"

  }

    scheduling_policy {
    preemptible = true
  }

  boot_disk {
    disk_id = yandex_compute_disk.remote-wm-disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.remote-net.id
    nat       = true
  #  security_group_ids = [yandex_vpc_security_group.test-backup-sg.id]
  }

  metadata = {
    ssh-keys = "linux:${local.vms_ssh_root_key}"
  }
}
resource "yandex_vpc_security_group" "vpn-sg" {
  name        = "vpn-sg"
  description = "Description for security group"
  network_id  = yandex_vpc_network.network.id
  depends_on  = [ yandex_compute_instance.remote-vm,]

  ingress {
    protocol       = "UDP"
    description    = "udp500"
    v4_cidr_blocks = ["${yandex_compute_instance.remote-vm.network_interface.0.nat_ip_address}/32",]
    port           = 500
  }
  ingress {
    protocol       = "UDP"
    description    = "udp4500"
    v4_cidr_blocks = ["${yandex_compute_instance.remote-vm.network_interface.0.nat_ip_address}/32",]
    port           = 4500
  }
  ingress {
    protocol       = "ANY"
    description    = "internal"
    v4_cidr_blocks = [ "${var.network_cidr.a.0}", "${var.network_cidr.b.0}", "${var.network_cidr.d.0}" ]
  }

  egress {
    protocol       = "UDP"
    description    = "udp500"
    v4_cidr_blocks = ["${yandex_compute_instance.remote-vm.network_interface.0.nat_ip_address}/32",]
    port           = 500
  }
  ingress {
    protocol       = "UDP"
    description    = "udp4500"
    v4_cidr_blocks = ["${yandex_compute_instance.remote-vm.network_interface.0.nat_ip_address}/32",]
    port           = 4500
  }
  ingress {
    protocol       = "ANY"
    description    = "internal"
    v4_cidr_blocks = [ "${var.network_cidr.a.0}", "${var.network_cidr.b.0}", "${var.network_cidr.d.0}" ]
  }
}
resource "yandex_vpc_security_group" "web-service-sg" {
  name        = "web-service-sg"
  description = "Description for security group"
  network_id  = yandex_vpc_network.network.id
  depends_on  = [ yandex_compute_instance.remote-vm,]

  ingress {
    protocol       = "TCP"
    description    = "ssh"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  ingress {
    description = "anyself"
    protocol = "ANY"
    predefined_target = "self_security_group"
  }
   ingress {
    description = "healthchcks"
    protocol = "TCP"
    port = 80
    predefined_target = "loadbalancer_healthchecks"
  }
  egress {
    description = "self"
    protocol = "ANY"
    predefined_target = "self_security_group"
  }
}
resource "yandex_compute_instance" "web-node" {
  for_each = var.default_zone
  name                      = "web-node-${each.key}"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"
  zone                      = each.value
  resources {
    cores  = "2"
    memory = "4"

  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.drupal.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.network[each.key].id
    nat       = false
    security_group_ids = [yandex_vpc_security_group.web-service-sg.id]
  }

  metadata = {
    ssh-keys = "linux:${local.vms_ssh_root_key}"
  }
}
resource "yandex_compute_instance" "ipsec-instance" {
  name                      = "vpn"
  allow_stopping_for_update = true
  platform_id               = "standard-v3"
  zone                      = var.default_zone.a
  resources {
    cores  = "2"
    memory = "4"

  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ipsec-instance.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.network["a"].id
    nat       = true
    security_group_ids = [yandex_vpc_security_group.vpn-sg.id]
  }

  metadata = {
    ssh-keys = "linux:${local.vms_ssh_root_key}"
  }
}
resource "yandex_vpc_route_table" "vpn-route" {
  name = "vpn-route"
  network_id = yandex_vpc_network.network.id
  static_route {
    destination_prefix = yandex_vpc_subnet.remote-net.v4_cidr_blocks[0]
    next_hop_address   = yandex_compute_instance.ipsec-instance.network_interface[0].ip_address
  }
}

resource "yandex_lb_target_group" "web-tg" {
  name      = "web-tg"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.network["a"].id
    address   = yandex_compute_instance.web-node["a"].network_interface.0.ip_address
  }
    target {
    subnet_id = yandex_vpc_subnet.network["b"].id
    address   = yandex_compute_instance.web-node["b"].network_interface.0.ip_address
  }
    target {
    subnet_id = yandex_vpc_subnet.network["d"].id
    address   = yandex_compute_instance.web-node["d"].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "web-lb" {
  name = "web-lb"

  listener {
    name = "web-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web-tg.id

    healthcheck {
      name = "tcp"
      tcp_options {
        port = 80
      }
    }
  }
}
