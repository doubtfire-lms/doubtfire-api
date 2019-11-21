# frozen_string_literal: true

def receive(_subscriber_instance, channel, _results_publisher, delivery_info, _properties, params)
  # Do something meaningful here :)
  puts params
  channel.ack(delivery_info.delivery_tag)
end
