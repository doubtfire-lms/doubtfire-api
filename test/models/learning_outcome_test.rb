require 'test_helper'
class LearningOutcomeTest < ActiveSupport::TestCase

  def setup
    data = {
        code: 'COS10001',
        name: 'Testing in Unit Tests',
        description: 'Test unit',
        teaching_period: TeachingPeriod.find(3)
      }
    @unit = Unit.create(data)
 end

  # Check abbreviation uniqueness
  def test_create_learning_outcome_with_not_unique_abbrev  
    learning_outcome_count = LearningOutcome.count	
    LearningOutcome.create!(
      unit_id: @unit.id,
      name: 'Functional Decomposition',
      description: 'desc',
      abbreviation: 'DECOMP',
      ilo_number: learning_outcome_count+1
    )
	learning_outcome_count = LearningOutcome.count

  assert_raises ActiveRecord::RecordInvalid do
      learning_outcome = LearningOutcome.create!(
      unit_id: @unit.id,
      name: 'Program',
      description: 'desc',
      abbreviation: 'DECOMP',
      ilo_number: learning_outcome_count+1
    )  
    end 
  end 
  def test_create_from_csv
  learning_outcome_count = LearningOutcome.count  
  loC = LearningOutcome.create!(
      unit_id: @unit.id,
      name: 'Functional Decomposition',
      description: 'desc',
      abbreviation: 'DECOMP',
      ilo_number: learning_outcome_count+1
    )

   

    #assert_equal loC, ["unit_code", "ilo_number", "abbreviation", "name", "description"]
    result = {
        success: [],
        errors: [],
        ignored: []
    } 
    file =  File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
     CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      row[0] = "COS10002"       
      LearningOutcome.create_from_csv(@unit, row, result)                
    end    
    assert_equal result[:ignored].count, 4 # 4 records

    #test abbreviation
    file =  File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
     CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      row[2] = nil
      LearningOutcome.create_from_csv(@unit, row, result)                
    end        
    #test name
    file =  File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
     CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
    # Make sure we're not looking at the header or an empty line
     next if row[0] =~ /unit_code/   
      row[3] = nil
      LearningOutcome.create_from_csv(@unit, row, result)                
    end        
    assert_equal result[:errors].count, 8 # 4 records

    #test description
    file =  File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
     CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      row[4] = nil
      LearningOutcome.create_from_csv(@unit, row, result)                
    end        
    assert_equal result[:errors].count, 12 # 4 records

     #test update learning
    file =  File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
     CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      row[2] = 'PROG'
      LearningOutcome.create_from_csv(@unit, row, result)                
    end        
    # check header
    assert_equal LearningOutcome.csv_header, ["unit_code", "ilo_number", "abbreviation", "name", "description"]
    
    # check add row 
    #assert_equal loC, ["unit_code", "ilo_number", "abbreviation", "name", "description"]
    #assert_equal loC.add_csv_row() 
    end   
end