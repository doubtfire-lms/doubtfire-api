class TeachingPeriod < ActiveRecord::Base
  has_many :units
  has_many :breaks

  validates :period, length: { minimum: 1, maximum: 20, allow_blank: false }, uniqueness: { scope: :year,
    message: "%{value} already exists in this year" }
  validates :year, length: { is: 4, allow_blank: false }, presence: true, numericality: { only_integer: true },
    inclusion: { in: 2000..2999, message: "%{value} is not a valid year" }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :active_until, presence: true

  validate :validate_end_date_after_start_date, :validate_active_until_after_end_date

  def validate_end_date_after_start_date
    if end_date.present? && start_date.present? && end_date < start_date
      errors.add(:end_date, "should be after the Start date")
    end
  end

  def validate_active_until_after_end_date
    if end_date.present? && active_until.present? && active_until < end_date
      errors.add(:active_until, "date should be after the End date")
    end
  end

  def add_break(start_date, number_of_weeks)
    break_in_teaching_period = Break.new
    break_in_teaching_period.start_date = start_date
    break_in_teaching_period.number_of_weeks = number_of_weeks
    break_in_teaching_period.teaching_period_id = self.id
    break_in_teaching_period.save!
    break_in_teaching_period
  end

  def week_no(date)
    # Calcualte date offset, add 2 so 0-week offset is week 1 not week 0
    result = ((date - start_date) / 1.week).floor + 1

    for a_break in breaks.all do
      if date >= a_break.start_date
        # we are in or after the break, so calculated week needs to
        # be reduced by this break
        if date >= a_break.end_date
          result -= a_break.number_of_weeks
        elsif date == a_break.start_date
          # cant use standard calculation as this give 0 for this exact moment...
          result -= 1
        else
          # in break so partial reduction
          result -= ((date - a_break.start_date) / 1.week).ceil
        end
      end
    end

    result
  end

  def date_for_week(num)
    # start by switching from 1 based to 0 based
    # week 1 is offset 0 weeks from the start
    num -= 1
    for a_break in breaks do
      if num >= week_no(a_break.start_date)
        # we are in or after the break, so calculated date is
        # extended by the break period
        num += a_break.number_of_weeks
      end
    end

    result = start_date + num.weeks
  end

  def date_for_week_and_day(week, day)
    return nil if week.nil? || day.nil?

    week_start = date_for_week(week)

    day_num = Date::ABBR_DAYNAMES.index day.titlecase
    return nil if day_num.nil?

    start_day_num = start_date.wday

    week_start + (day_num - start_day_num).days
  end

  def rollover(rollover_to)
    rollover_to.add_associations(self)
    rollover_to.save!
    rollover_to
  end

  def add_associations(existing_teaching_period)
    duplicate_units_from_existing_teaching_period(existing_teaching_period)
  end

  def duplicate_units_from_existing_teaching_period(existing_teaching_period)
    for unit in existing_teaching_period.units do
      unit.rollover(self.id, nil, nil)
    end
  end
end
