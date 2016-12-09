module ApplicationHelper
  def application_reference_date
    @application_reference_date ||=
      if Doubtfire::Application.config.respond_to?(:application_reference_date)
        Time.zone.parse(Doubtfire::Application.config.reference_date)
      else
        Time.zone.now
      end
  end

  def lesc(text)
    LatexToPdf.escape_latex(text)
  end
end
