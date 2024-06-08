module ApplicationHelper
  def application_reference_date
    @application_reference_date ||=
      if Doubtfire::Application.config.respond_to?(:application_reference_date)
        Time.zone.parse(Doubtfire::Application.config.reference_date)
      else
        Time.zone.now
      end
  end

  # Escape text for inclusion in Latex documents
  def lesc(text)
    # Convert to latex text, then use gsub to remove any characters that are not printable
    # rubocop:disable Rails/OutputSafety
    raw(LatexToPdf.escape_latex(text).gsub(/[^[:print:]]/, ''))
    # rubocop:enable Rails/OutputSafety
  end
end
