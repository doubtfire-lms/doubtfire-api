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

  test "scrubs student details from unit-labelled LaTeX work directories" do
    task_path = "tmp/rails-latex/task-20260724-1100-COURSE1234-student-name-task-1-2/file.tex"
    portfolio_path = "tmp/rails-latex/portfolio-20260724-1100-COURSE1234-student-name-1-2/file.tex"

    assert_equal(
      "tmp/rails-latex/task-20260724-1100-[username]-task-1-2/file.tex",
      OnTrackSentryRedaction.scrub_string(task_path)
    )
    assert_equal(
      "tmp/rails-latex/portfolio-20260724-1100-[username]-1-2/file.tex",
      OnTrackSentryRedaction.scrub_string(portfolio_path)
    )
  end

  test "scrubs student details from portfolio PDF failure exceptions" do
    exception_value = Sentry::SingleExceptionInterface.new(
      exception: PdfGeneration::ProjectCompilePortfolioModule::LatexError.new(
        "Failed to convert portfolio to PDF - 1234 - Test Example (example1234) COURSE123"
      ),
      mechanism: nil
    )
    exception = Sentry::ExceptionInterface.new(exceptions: [exception_value])

    OnTrackSentryRedaction.scrub_exception(exception)

    assert_equal(
      "Failed to convert portfolio to PDF - 1234 - [Filtered] ([username]) COURSE123 (PdfGeneration::ProjectCompilePortfolioModule::LatexError)",
      exception_value.value
    )
  end
end
