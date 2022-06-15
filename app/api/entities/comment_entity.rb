module Entities
  class CommentEntity < Grape::Entity
    expose :id
    expose :comment
    expose :has_attachment do |data, options|
      ["audio", "image", "pdf"].include?(data.content_type)
    end
    expose :type do |data, options|
      data.content_type || "text"
    end
    expose :is_new do |data, options|
      if data.has_attribute?(:is_new) && data.is_new.present?
        data.is_new != 0
      else
        data.new_for?(options[:current_user])
      end
    end
    expose :reply_to_id
    expose :created_at
    expose :recipient_read_time, safe: true
    expose :author do |data, options|
      if data.has_attribute? :author_id
        {
          id: data.author_id,
          first_name: data.author_first_name,
          last_name: data.author_last_name,
          email: data.author_email
        }
      else
        {
          id: data.user_id,
          first_name: data.user.first_name,
          last_name: data.user.last_name,
          email: data.user.email
        }
      end
    end
    expose :recipient do |data, options|
      if data.has_attribute? :recipient_first_name
        {
          id: data.recipient_id,
          name: "#{data.recipient_first_name} #{data.recipient_last_name}",
          email: data.recipient_email
        }
      else
        {
          id: data.recipient_id,
          name: data.recipient.name,
          email: data.recipient.email
        }
      end
    end
  end
end
