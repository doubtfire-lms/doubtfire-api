class Progress
  include Comparable

  attr :progress, :weight

  def <=>(other)
    weight <=> other.weight
  end

  def initialize(progress_sym)
    @progress = progress_sym
    case progress
    when :doomed
      @weight = 0
    when :danger
      @weight = 1
    when :behind
      @weight = 2
    when :on_track
      @weight = 3
    when :ahead
      @weight = 4
    else
      @weight = -1
    end
  end
end