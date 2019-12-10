require 'test_helper'
class LearningOutcomeTest < ActiveSupport::TestCase

  def setup
    data = {
        code: 'COS10001',
        name: 'Testing in Unit Tests',
        description: 'Test unit',
        # teaching_period: TeachingPeriod.find(3)
      }
    @unit = Unit.create(data)
  end

  # Check abbreviation uniqueness
  def test_create_learning_outcome_with_unique_abbrev
    #Create new unit.
    learning_outcome_count = LearningOutcome.count
    unit_1 = {
        unit_id: 'ASD10001',
        ilo_number: learning_outcome_count + 1,
        abbreviation:'AI',
        name:'Artificial Intelligence',
        description:'AI'
    }

    learning_outcome = LearningOutcome.create!(unit_1)

    learning_outcome_count = LearningOutcome.count
    unit_2 = {
        unit_id: 'ASD10002',
        ilo_number: learning_outcome_count + 1,
        abbreviation: 'PR',
        name: 'Programming',
        description: 'Create programming'
    }

    learning_outcome2 = LearningOutcome.create!(unit_2)
    
    #Check the abbreviation is not empty.
    refute_empty learning_outcome.abbreviation    
    refute_empty learning_outcome2.abbreviation

    #Check the abbreviation of the unit is unique.
    refute_equal learning_outcome, learning_outcome2
  end

  #Create from csv
  def test_create_from_csv
    learning_outcome_count = LearningOutcome.count
    #Create unit
    loc = {
      unit_id: 'COS10001',
      ilo_number: learning_outcome_count + 1,
      abbreviation:'AI',
      name:'Artificial Intelligence',
      description:'AI'
    }

    learning_outcome = LearningOutcome.create!(loc)

    #Create result 
    result = {
      success: [],
      errors: [],
      ignored: []
    }

    #Test Unit Code
    file = File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
      CSV.parse(file,                 headers: true,             
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      #Test Unit id
      row[0] = "ASD10001"       
      LearningOutcome.create_from_csv(@unit, row, result)

      refute_equal row[0], learning_outcome.unit_id
    end
    #record result 'ignored' 
    assert_equal result[:ignored].count, 4

    #Test Abbreviation
    file = File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
      CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      row[2] = "AI"
      LearningOutcome.create_from_csv(@unit, row, result)  

      assert_equal row[2], learning_outcome.abbreviation            
    end 

    #record result 'success' 
    assert_equal result[:success].count, 4

    #Test Name
    file = File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
      CSV.parse(file,                 headers: true,
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/   
      row[3] = "Artificial Intelligence"
      LearningOutcome.create_from_csv(@unit, row, result)  

      assert_equal row[3], learning_outcome.name              
    end        
    assert_equal result[:success].count, 8

    #Test Description
    file = File.open(Rails.root.join('test_files',"#{@unit.code}-Outcomes.csv"))
      CSV.parse(file,                 headers: true,                
                                    header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
                                    converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line 
      next if row[0] =~ /unit_code/
      row[4] = nil
      LearningOutcome.create_from_csv(@unit, row, result)

      refute_equal row[4], learning_outcome.description
    end
    
    #record result 'errors' 
    assert_equal result[:errors].count, 4

    #Check header
    assert_equal LearningOutcome.csv_header, ["unit_code", "ilo_number", "abbreviation", "name", "description"]
  end
end 