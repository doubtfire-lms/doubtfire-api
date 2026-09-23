# frozen_string_literal: true

require 'ipaddr'
require 'resolv'

#
# Recognises the LTI service by the address a request connects from. Entries are IPs, CIDR ranges
# or hostnames, and hostnames are resolved on every check because container IPs change on restart.
#
module LtiServiceAddresses
  module_function

  def allowed?(remote_addr, entries = Doubtfire::Application.config.lti_service_hosts)
    address = normalise(remote_addr)
    return false if address.nil?

    Array(entries).any? { |entry| addresses_for(entry).any? { |allowed| allowed.include?(address) } }
  end

  def addresses_for(entry)
    [IPAddr.new(entry)]
  rescue IPAddr::Error
    Resolv.getaddresses(entry).filter_map { |ip| normalise(ip) }
  end

  def normalise(ip)
    address = IPAddr.new(ip.to_s)
    address.ipv4_mapped? ? address.native : address
  rescue IPAddr::Error
    nil
  end
end
