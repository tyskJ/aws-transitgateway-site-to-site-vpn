/************************************************************
Customer Gateway
************************************************************/
resource "aws_customer_gateway" "this" {
  for_each = local.cgws

  bgp_asn     = each.value.asn
  ip_address  = aws_eip.this[each.value.eip_key].public_ip
  device_name = each.value.name
  type        = "ipsec.1"
  tags = {
    Name = each.value.name
  }
}

/************************************************************
S2S VPN Connections
************************************************************/
resource "aws_vpn_connection" "this" {
  for_each = local.vpncons
  ### Base
  type                     = "ipsec.1"
  transit_gateway_id       = aws_ec2_transit_gateway.this.id
  customer_gateway_id      = aws_customer_gateway.this[each.key].id
  static_routes_only       = false
  preshared_key_storage    = "Standard"
  tunnel_bandwidth         = "standard"
  tunnel_inside_ip_version = "ipv4"
  enable_acceleration      = false
  local_ipv4_network_cidr  = "0.0.0.0/0"
  remote_ipv4_network_cidr = "0.0.0.0/0"
  outside_ip_address_type  = "PublicIpv4"
  # ### Tunnel 1
  # tunnel1_inside_cidr                     = "169.254.208.48/30"
  # tunnel1_preshared_key                   = null # sensitive
  # tunnel1_log_options {
  #   cloudwatch_log_options {
  #     bgp_log_enabled       = false
  #     bgp_log_group_arn     = null
  #     bgp_log_output_format = null
  #     log_enabled           = false
  #     log_group_arn         = null
  #     log_output_format     = null
  #   }
  # }
  # ##### Advanced
  # tunnel1_phase1_encryption_algorithms    = []
  # tunnel1_phase2_encryption_algorithms    = []
  # tunnel1_phase1_integrity_algorithms     = []
  # tunnel1_phase2_integrity_algorithms     = []
  # tunnel1_phase1_dh_group_numbers         = []
  # tunnel1_phase2_dh_group_numbers         = []
  # tunnel1_ike_versions                    = []
  # tunnel1_phase1_lifetime_seconds         = 0
  # tunnel1_phase2_lifetime_seconds         = 0
  # tunnel1_rekey_margin_time_seconds       = 0
  # tunnel1_rekey_fuzz_percentage           = 0
  # tunnel1_replay_window_size              = 0
  # tunnel1_dpd_timeout_seconds             = 0
  # tunnel1_dpd_timeout_action              = null
  # tunnel1_startup_action                  = null
  # tunnel1_enable_tunnel_lifecycle_control = false
  # ### Tunnel 2
  # tunnel2_inside_cidr                     = "169.254.125.244/30"
  # tunnel2_preshared_key                   = null # sensitive
  # tunnel2_log_options {
  #   cloudwatch_log_options {
  #     bgp_log_enabled       = false
  #     bgp_log_group_arn     = null
  #     bgp_log_output_format = null
  #     log_enabled           = false
  #     log_group_arn         = null
  #     log_output_format     = null
  #   }
  # }
  # ##### Advanced
  # tunnel2_phase1_encryption_algorithms    = []
  # tunnel2_phase2_encryption_algorithms    = []
  # tunnel2_phase1_integrity_algorithms     = []
  # tunnel2_phase2_integrity_algorithms     = []
  # tunnel2_phase1_dh_group_numbers         = []
  # tunnel2_phase2_dh_group_numbers         = []
  # tunnel2_ike_versions                    = []
  # tunnel2_phase1_lifetime_seconds         = 0
  # tunnel2_phase2_lifetime_seconds         = 0
  # tunnel2_rekey_margin_time_seconds       = 0
  # tunnel2_rekey_fuzz_percentage           = 0
  # tunnel2_replay_window_size              = 0
  # tunnel2_dpd_timeout_seconds             = 0
  # tunnel2_dpd_timeout_action              = null
  # tunnel2_startup_action                  = null
  # tunnel2_enable_tunnel_lifecycle_control = false
  tags = {
    Name = each.value.name
  }
}

/************************************************************
S2S VPN Connections PSK
************************************************************/
resource "local_sensitive_file" "tunnel1" {
  for_each = local.vpncons

  filename        = "${path.module}/.key/${each.key}_tunnel1_psk.txt"
  content         = aws_vpn_connection.this[each.key].tunnel1_preshared_key
  file_permission = "0600"
}
resource "local_sensitive_file" "tunnel2" {
  for_each = local.vpncons

  filename        = "${path.module}/.key/${each.key}_tunnel2_psk.txt"
  content         = aws_vpn_connection.this[each.key].tunnel2_preshared_key
  file_permission = "0600"
}