# create VPC with subnets, ACLs and SGs
resource ibm_is_vpc vpc {
  name                      = "${var.basename}-vpc"
  resource_group            = ibm_resource_group.cloud_development.id
  address_prefix_management = "manual"
  tags                      = concat(var.tags, ["vpc"])
}

resource ibm_is_vpc_address_prefix subnet_prefix {
  count = "3"

  name = "${var.basename}-prefix-zone-${count.index + 1}"
  zone = "${var.region}-${(count.index % 3) + 1}"
  vpc  = ibm_is_vpc.vpc.id
  cidr = element(var.cidr_blocks, count.index)
}

resource ibm_is_network_acl network_acl {
  name           = "${var.basename}-acl"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = ibm_resource_group.cloud_development.id
  rules {
    name        = "egress"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "outbound"
  }
  rules {
    name        = "ingress"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "inbound"
  }
}

resource ibm_is_subnet subnet {
  count = "3"

  name            = "${var.basename}-subnet-${count.index + 1}"
  vpc             = ibm_is_vpc.vpc.id
  zone            = "${var.region}-${count.index + 1}"
  resource_group  = ibm_resource_group.cloud_development.id
  ipv4_cidr_block = element(ibm_is_vpc_address_prefix.subnet_prefix.*.cidr, count.index)
  network_acl     = ibm_is_network_acl.network_acl.id
}


resource "ibm_is_security_group_rule" "cluster_inbound" {

  group     = ibm_is_vpc.vpc.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 30000
    port_max = 32767
  }
}