require "forwardable"
require_relative "infrastructure"
require_relative "ip_ranges"

module VCloudSdk
  class EdgeGateway
    include Infrastructure

    extend Forwardable
    def_delegator :entity_xml, :name

    def initialize(session, link)
      @session = session
      @link = link
    end

    def public_ip_ranges
      uplink_gateway_interface = entity_xml
                                   .gateway_interfaces
                                   .find { |g| g.interface_type == "uplink" }

      ip_ranges = uplink_gateway_interface.ip_ranges
      return IpRanges.new unless ip_ranges

      ip_ranges
        .ranges
        .reduce(IpRanges.new) do |result, i|
          result + IpRanges.new("#{i.start_address}-#{i.end_address}")
        end
    end
  end
end
