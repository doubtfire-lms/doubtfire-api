class TeachingPeriod < ApplicationRecord
  # Relationships
  has_many :units, dependent: :restrict_with_exception
  has_many :breaks, dependent: :delete_all

  # Callbacks - methods called are private
  before_destroy :can_destroy?

  # Validations - methods called are private
  validates :period, length: { minimum: 1, maximum: 20, allow_blank: false }, uniqueness: { scope: :year,
                                                                                            message: "%{value} already exists in this year" }
  validates :year, length: { is: 4, allow_blank: false }, presence: true, numericality: { only_integer: true },
                   inclusion: { in: 2000..2999, message: "%{value} is not a valid year" }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :active_until, presence: true

  validate :validate_end_date_after_start_date, :validate_active_until_after_end_date

  after_update :propogate_date_changes

  # Public methods

  def add_break(start_date, number_of_weeks)
    break_in_teaching_period = Break.new
    break_in_teaching_period.start_date = start_date
    break_in_teaching_period.number_of_weeks = number_of_weeks
    break_in_teaching_period.teaching_period = self

    break_in_teaching_period.save!
    # add after save to ensure valid break
    self.breaks << break_in_teaching_period

    break_in_teaching_period
  end

  def update_break(id, start_date, number_of_weeks)
    break_in_teaching_period = breaks.find(id)

    if start_date.present?
      break_in_teaching_period.start_date = start_date
    end

    if number_of_weeks.present?
      break_in_teaching_period.number_of_weeks = number_of_weeks
    end

    break_in_teaching_period.save!
    break_in_teaching_period
  end

  def week_number(date)
    # Calcualte date offset, add 2 so 0-week offset is week 1 not week 0
    result = ((date - start_date) / 1.week).floor + 1

    for a_break in breaks.all do
      if date >= a_break.start_date
        # we are in or after the break, so calculated week needs to
        # be reduced by this break

        if date >= a_break.end_date
          # past the end of the break...
          result -= a_break.number_of_weeks
        elsif date == a_break.start_date
          # cant use standard calculation as this give 0 for this exact moment...
          result -= 1 if date >= a_break.first_monday
        elsif date >= a_break.first_monday
          # in break so partial reduction
          result -= ((date - a_break.first_monday) / 1.week).ceil
        end

        # for times just past the break but before start of next week...
        if date >= a_break.end_date && date < a_break.monday_after_break
          # Need to add 1 as we are now in a new week!
          result += 1
        end
      end
    end

    result
  end

  def date_for_week(num)
    num = num.floor

    # start by switching from 1 based to 0 based
    # week 1 is offset 0 weeks from the start
    num -= 1

    result = start_date + num.weeks

    # check breaks
    for a_break in breaks do
      if result >= a_break.start_date
        # we are in or after the break, so calculated date is
        # extended by the break period
        result += a_break.number_of_weeks.weeks
      end
    end

    result
  end

  def date_for_week_and_day(week, day)
    return nil if week.nil? || day.nil?

    week_start = date_for_week(week)

    day_num = Date::ABBR_DAYNAMES.index day.titlecase
    return nil if day_num.nil?

    start_day_num = start_date.wday

    result = week_start + (day_num - start_day_num).days

    for a_break in breaks do
      if result >= a_break.start_date && result < a_break.end_date
        # we are in or after the break, so calculated date is
        # extended by the break period
        result += a_break.number_of_weeks.weeks
      end
    end

    result
  end

  def future_teaching_periods
    TeachingPeriod.where("start_date > :end_date", end_date: end_date)
  end

  def rollover(rollover_to, search_forward = true, rollover_inactive = false)
    if rollover_to.start_date < Time.zone.now || rollover_to.start_date <= start_date
      self.errors.add(:base, "Units can only be rolled over to future teaching periods")

      false
    else
      units_to_rollover = units

      unless rollover_inactive
        units_to_rollover = units_to_rollover.where(active: true)
      end

      if search_forward
        ftp = future_teaching_periods.where("start_date < :date", date: rollover_to.start_date).order(start_date: "desc")

        units_to_rollover = units_to_rollover.map do |u|
          ftp.map { |tp| tp.units.where(code: u.code).first }.select { |u| u.present? }.first || u
        end
      end

      for unit in units_to_rollover do
        # skip if the unit already exists in the teaching period
        next if rollover_to.units.where(code: unit.code).count > 0

        unit.rollover(rollover_to, nil, nil)
      end

      true
    end
  end

  private

  def can_destroy?
    return true if units.count == 0

    errors.add :base, "Cannot delete teaching period with units"
    throw :abort
  end

  def validate_active_until_after_end_date
    if end_date.present? && active_until.present? && active_until < end_date
      errors.add(:active_until, "date should be after the End date")
    end
  end

  def validate_end_date_after_start_date
    if end_date.present? && start_date.present? && end_date < start_date
      errors.add(:end_date, "should be after the Start date")
    end
  end

  def propogate_date_changes
    return unless saved_change_to_start_date? || saved_change_to_end_date?

    units.each do |u|
      u.update(start_date: self.start_date, end_date: self.end_date)
    end
  end
end
