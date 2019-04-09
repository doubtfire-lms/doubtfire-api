class Progress
  include Comparable

  PROGRESS_TYPES = [
    :ahead,
    :on_track,
    :behind,
    :danger,
    :doomed
  ].freeze

  attr_reader :progress, :weight

  def <=>(other)
    weight <=> other.weight
  end

  def initialize(progress_sym)
    @progress = progress_sym
    @weight = case progress
              when :doomed
                0
              when :danger
                1
              when :behind
                2
              when :on_track
                3
              when :ahead
                4
              else
                -1
              end
  end

  def self.types
    PROGRESS_TYPES
  end
end
