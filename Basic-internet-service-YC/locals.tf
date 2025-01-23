locals {
    vms_ssh_root_key = sensitive(file("~/.ssh/id_ed25519.pub"))
}