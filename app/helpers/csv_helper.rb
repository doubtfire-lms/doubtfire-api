module CsvHelper
  def csv_date_to_date(date)
    return if date.blank?

    date = date.strip

    if date !~ /20\d\d\-\d{1,2}\-\d{1,2}$/ # Matches YYYY-mm-dd by default
      if date =~ /\d{1,2}\-\d{1,2}\-20\d\d/ # Matches dd-mm-YYYY
        date = date.split('-').reverse.join('-')
      elsif date =~ /\d{1,2}\/\d{1,2}\/20\d\d$/ # Matches dd/mm/YYYY
        date = date.split('/').reverse.join('-')
      elsif date =~ /\d{1,2}\/\d{1,2}\/\d\d$/ # Matches dd/mm/YY
        date = "20#{date.split('/').reverse.join('-')}"
      elsif date =~ /\d{1,2}\-\d{1,2}\-\d\d$/ # Matches dd-mm-YY
        date = "20#{date.split('-').reverse.join('-')}"
      elsif date =~ /\d{1,2}\-\d{1,2}\-\d\d \d\d:\d\d:\d\d$/ # Matches dd-mm-YY hh:mm:ss
        date = date.split.first
        date = "20#{date.split('-').reverse.join('-')}"
      elsif date =~ /\d{1,2}\/\d{1,2}\/\d\d [\d:]+$/ # Matches dd/mm/YY 00:00:00
        date = date.split.first
        date = "20#{date.split('/').reverse.join('-')}"
      end
    end

    Date.parse(date)
  end

  def missing_headers(row, headers)
    headers - row.to_hash.keys
  end

  module_function :csv_date_to_date
  module_function :missing_headers
end
