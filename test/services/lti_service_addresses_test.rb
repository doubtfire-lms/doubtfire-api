require 'test_helper'

class LtiServiceAddressesTest < ActiveSupport::TestCase
  test 'matches IPs, CIDR ranges and resolved hostnames' do
    assert LtiServiceAddresses.allowed?('172.20.0.7', %w[172.20.0.7])
    assert LtiServiceAddresses.allowed?('172.20.0.7', %w[172.20.0.0/16])
    assert LtiServiceAddresses.allowed?('127.0.0.1', %w[localhost])
  end

  test 'matches IPv4 peers reported as IPv4-mapped IPv6' do
    assert LtiServiceAddresses.allowed?('::ffff:172.20.0.7', %w[172.20.0.7])
  end

  test 'rejects other, missing and invalid addresses' do
    assert_not LtiServiceAddresses.allowed?('172.20.0.8', %w[172.20.0.7])
    assert_not LtiServiceAddresses.allowed?('10.0.0.1', %w[172.20.0.0/16])
    assert_not LtiServiceAddresses.allowed?(nil, %w[172.20.0.7])
    assert_not LtiServiceAddresses.allowed?('not-an-ip', %w[172.20.0.7])
    assert_not LtiServiceAddresses.allowed?('172.20.0.7', [])
  end

  test 'rejects everything when a hostname does not resolve' do
    assert_not LtiServiceAddresses.allowed?('172.20.0.7', %w[lti-service-that-does-not-exist.invalid])
  end
end
