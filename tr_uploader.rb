require 'dotenv'
require 'json'
require 'csv'
require 'date'
require_relative 'testrail.rb'

CSVS = File.join(File.dirname(__FILE__), 'logical_test_cases/')

class TRUploader

  def initialize(argv)
    Dotenv.load ".env"
    @csv_file = argv[0]
    @parent_id = 304265
    #puts "Args #{argv[0]}, #{argv[1]}"
    @client = TestRail::APIClient.new(ENV['TRURL'])
    @client.user = ENV['TRUSER']
    @client.password = ENV['TRPASS']
    @sections = get_sections
    init_csv
  end

  def init_csv
    @csv = CSV.read(CSVS + '571_bounced.csv')
    @csv.delete_at(0) #remove header
    get_sections
    create_section
  end

  def create_section
    # csv is array of arrays
    # for each row do
    @csv.each do |row|
      #does sub-section exist in csv = csv[5].nil?
      if row[5].nil?
        #check that there isn't already a section matching the title row[0]
        if get_title_id(row[0], @parent_id).nil?
          #build the request and save id
          row[4] = @client.post("add_section/#{ENV['TRPID']}", build_new_ltc(row, @parent_id))
        end
      else
        # build hierarchy for sub-section
        parent_id = build_heirarchy(row[5])
        row[4] = @client.post("add_section/#{ENV['TRPID']}", build_new_ltc(row, parent_id))
      end
    end
  end

  def get_title_id(title, parent_id)
    parent = @sections.select {|hash| hash["parent_id"] == parent_id}
    exists = parent.select {|hash| hash["name"] == title}
    if exists.count > 0
      exists.first["id"]
    else
      nil
    end
  end

  def get_sections
    @client.get("get_sections/#{ENV['TRPID']}")

    #children = sections.select {|hash| hash["parent_id"] == @parent_id}
    #childs = children.select {|hash| hash["name"].include?("_0")}
    #childs
  end

  def build_new_ltc(row, parent_id)
    #row = title, description, update_date, user, sectionurl, sub-section
    # this must return a hash
    new_desctription = "Created on: #{row[2]}\nCreated by:#{row[3]}\nDescription:#{row[2]}\nUploaded via SethScript #{DateTime.now.month}.#{DateTime.now.day}.#{DateTime.now.year}"
    {:name => row[0], :description => new_desctription, :parent_id => parent_id}
  end

  def build_heirarchy(row)
    #split this row into sub sections
    #TODO this
  end

end

TRUploader.new(ARGV)