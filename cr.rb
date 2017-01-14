require 'dotenv'
require 'json'
require 'csv'
require 'date'
require 'pry'
require_relative 'testrail.rb'

CSVS = File.join(File.dirname(__FILE__), 'sorted/')

class CR

  ECSUsers = [
      {"id"=>42, "name"=>"Donna Trunz (ECS)", "is_active"=>true},
      {"id"=>82, "name"=>"Marge Tigges (ECS)", "is_active"=>true},
      {"id"=>90, "name"=>"Meenakshi Kapur (ECS)", "is_active"=>true},
      {"id"=>41, "name"=>"Nancy Parker (ECS)", "is_active"=>true},
      {"id"=>46, "name"=>"Sean Kelsey (ECS)", "is_active"=>false}
    ]

  def initialize()
    Dotenv.load ".env"
    @date = set_datetime

    #puts "Args #{argv[0]}, #{argv[1]}"
    @client = TestRail::APIClient.new(ENV['TRURL'])
    @client.user = ENV['TRUSER']
    @client.password = ENV['TRPASS']
    # #get data
    # @templates = @client.get("get_templates/#{ENV['TRPID']}")
    # sleep(0.5)
    @users = @client.get("get_users")
    sleep(0.5)
    @priority1 = @client.get("get_cases/#{ENV['TRPID']}&priority_id=4")
    sleep(0.5)

  end

  def set_datetime
    "#{DateTime.now.day}.#{DateTime.now.month}.#{DateTime.now.year} @#{DateTime.now.hour}:#{DateTime.now.minute}:#{DateTime.now.second}"
  end

  def url(id)
    "https://#{ENV['TRURL']}/index.php?/cases/view/#{id}"
  end

  def bad
    @client.get("get_case/6662687")
  end

  def sortECS
    #this is going to go through and sort the P1 cases and write to a CSV File
    ECSUsers.each do |ecsu|
      csvFileName = ecsu["name"].gsub(" ", "_") + ".csv"
      #write the file and headerrow
      CSV.open(CSVS + csvFileName, "wb") do |csv|
        csv << ["TestCaseID", "TemplateID", "Title", "DescCC", "PreCondCC", "Steps", "CreateDate", "Updated", "link"]
      end
      #Go through each P1 and add those fields to an array
      cases = Array.new
      @priority1.each do |tc|
        if tc["created_by"].eql? ecsu["id"]
          if tc["template_id"].eql? 2
            steps = tc["custom_steps_separated"].count
          else
            steps = "UNKOWN"
          end
          desccc = tc["custom_detailed_description"].nil? ? 0 : tc["custom_detailed_description"].size
          precondcc = tc["custom_preconds"].nil? ? 0 : tc["custom_preconds"].size
          cd = DateTime.strptime(tc["created_on"].to_s,'%s')
          createDate = "#{cd.month}-#{cd.day}-#{cd.year}"
          ud = DateTime.strptime(tc["updated_on"].to_s,'%s')
          updateDate = "#{ud.month}-#{ud.day}-#{ud.year}"
          cd = [tc["id"], tc["template_id"], tc["title"], desccc, precondcc, steps, createDate, updateDate, url(tc["id"])]
          cases.push(cd)
        end
      end
      #write the cases to the ecsusers File
      CSV.open(CSVS + csvFileName, "a") do |csv|
        cases.each do |row|
          csv << row
        end
      end
    end
  end




end
