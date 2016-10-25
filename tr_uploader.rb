require 'dotenv'
require 'json'
require 'csv'
require 'date'
require_relative 'testrail.rb'

CSVS = File.join(File.dirname(__FILE__), 'logical_test_cases/')

class TRUploader

  def initialize(argv)
    Dotenv.load ".env"
    @date = set_datetime
    @csv_file = argv[0]
    @parent_id = argv[1].to_i
    #puts "Args #{argv[0]}, #{argv[1]}"
    @client = TestRail::APIClient.new(ENV['TRURL'])
    @client.user = ENV['TRUSER']
    @client.password = ENV['TRPASS']
    @sections = @client.get("get_sections/#{ENV['TRPID']}")
    init_csv
  end

  def init_csv
    @csv = CSV.read(CSVS + @csv_file)
    @csv_head = @csv[0] #save the head
    @csv.delete_at(0) #remove header

    create_section
  end

  def set_datetime
    "#{DateTime.now.day}.#{DateTime.now.month}.#{DateTime.now.year} @#{DateTime.now.hour}:#{DateTime.now.minute}:#{DateTime.now.second}"
  end

  def create_section
    # csv is array of arrays
    # for each row do
    @csv.each do |row|
      #does sub-section exist in csv = csv[5].nil?
      if row[5].nil?
        #check that there isn't already a section matching the title row[0]
        if get_title_id(row[0], @parent_id).nil? #duplicate check
          #build the request and save id
          row[4] = url(@client.post("add_section/#{ENV['TRPID']}", build_new_ltc(row, @parent_id))["id"])
          sleep 1
        else
          row[4] = url(get_title_id(row[0], @parent_id))
        end
      else
        # build hierarchy for sub-section
        parent_id = build_heirarchy(row[5], @parent_id)
        if get_title_id(row[0], parent_id).nil?
          row[4] = url(@client.post("add_section/#{ENV['TRPID']}", build_new_ltc(row, parent_id))["id"])
          sleep 1
        else
          row[4] = url(get_title_id(row[0], parent_id))
        end
      end
    end
    write_out_updated_csv
  end

  def url(id)
    "https://sendgrid.testrail.net/index.php?/suites/view/71&group_by=cases:section_id&group_order=asc&group_id=#{id}"
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

  def build_new_ltc(row, parent_id)
    #row = title, description, update_date, user, sectionurl, sub-section
    # this must return a hash

    new_desctription = "Created on: #{row[2]}\nCreated by:#{row[3]}\nDescription: #{row[1]}\nUploaded via SethScript #{@date}"
    new_ltc = {:name => row[0], :description => new_desctription, :parent_id => parent_id}
    @sections.push(new_ltc) #add onto array = reduces API calls
    new_ltc
  end

  def build_heirarchy(string, parent_id)
    # this returns the id of the last item
    items = string.split('/')
    created_items = []
    items.each do |item|
      if created_items.last.nil?
        pid = parent_id
      else
        pid = created_items.last["id"]
      end
      parent_items = @sections.select {|hash| hash["parent_id"] == pid}
      child = parent_items.select {|hash| hash["name"] == item}
      if child.empty?
        created_items.push(@client.post("add_section/#{ENV['TRPID']}", {:parent_id => pid, :name => item}))
        @sections.push(created_items.last)
      else
        created_items.push(child.first)
      end
    end

    created_items.last["id"]
  end

  def write_out_updated_csv
    CSV.open(CSVS + "uploaded_#{@csv_file}", "wb") do |csv|
      csv << @csv_head
    end
    CSV.open(CSVS + "uploaded_#{@csv_file}", "a") do |csv|
      @csv.each do |row|
        csv << row
      end
    end
  end

end

TRUploader.new(ARGV)