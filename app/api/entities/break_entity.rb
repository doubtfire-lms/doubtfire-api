module Entities
  class BreakEntity < Grape::Entity
    format_with(:date_only) do |date|
      date.strftime('%Y-%m-%d')
    end

    expose :id

    with_options(format_with: :date_only) do
      expose :start_date
    end

    expose :number_of_weeks
  end
end
