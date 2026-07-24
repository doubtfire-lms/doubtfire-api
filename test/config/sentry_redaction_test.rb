require "test_helper"

class SentryRedactionTest < ActiveSupport::TestCase
  test "scrubs exception values from Sentry's exception interface" do
    exception_value = Sentry::SingleExceptionInterface.new(
      exception: RuntimeError.new("tmp/rails-latex/task-20260724-1100-student-name-task-1-2/file.tex"),
      mechanism: nil
    )
    exception = Sentry::ExceptionInterface.new(exceptions: [exception_value])

    OnTrackSentryRedaction.scrub_exception(exception)

    assert_equal(
      "tmp/rails-latex/task-20260724-1100-[username]-task-1-2/file.tex (RuntimeError)",
      exception_value.value
    )
  end
end
