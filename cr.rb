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
    @p169 = @client.get("get_cases/69&priority_id=4")
    sleep(0.5)
    @p13 = @client.get("get_cases/3&priority_id=4")
    sleep(0.5)
    compare
    pullECS_SendGrid
    pullECS_PlayGround
  end

  def set_datetime
    "#{DateTime.now.day}.#{DateTime.now.month}.#{DateTime.now.year} @#{DateTime.now.hour}:#{DateTime.now.minute}:#{DateTime.now.second}"
  end

  def url(id)
    "#{ENV['TRURL']}/index.php?/cases/view/#{id}"
  end

  def bad
    @client.get("get_case/6946235")
  end

  def compare
    puts "Running Comparison between Playground and SendGrid - P1 Only"
    p13not69 = Array.new
    p13in69 = Array.new
    @p13.each do |p13|
      found = false
      @p169.each do |p169|
        if p13["title"] == p169["title"] && p13["custom_preconds"] == p169["custom_preconds"] && p13["custom_detailed_description"] == p169["custom_detailed_description"]
          p13in69.push(p169)
          @p169.delete(p169)
          puts "Match Found! ID #{p13["id"]} == #{p169["id"]} #{createdName(p13["created_by"])} - #{createdName(p169["created_by"])}"
          found = true
          break
        end #endif
      end #end inner
      unless found
        puts "!!  Match not found #{p13["id"]} - #{createdName(p13["created_by"])}"
        p13not69.push(p13)
      end
    end
    csvdata("P1_Playground_NOTIN_SendGrid", p13not69)
    csvdata("P1_Playground_IN_SendGrid", p13in69)
  end

  def createdName(id)
    @users.each do |user|
      if user["id"] == id
        return user["name"]
      end
    end
    return "unknown"
  end

  def csvdata(filename, data)
    puts "Generating CSV sorted\\#{filename}.csv...\n"
    CSV.open(CSVS + "#{filename}.csv", "wb") do |csv|
      csv << ["TestCaseID", "ProjectID", "CreatedBy", "TemplateID", "Title", "DescCC", "PreCondCC", "Steps", "CreateDate", "Updated", "link"]
    end
    puts "Writing Data to disk.\n"
    CSV.open(CSVS + "#{filename}.csv", "a") do |csv|
      data.each do |tc|
        desccc = tc["custom_detailed_description"].nil? ? 0 : tc["custom_detailed_description"].size
        precondcc = tc["custom_preconds"].nil? ? 0 : tc["custom_preconds"].size
        steps = tc["custom_steps_separated"].nil? ? 0 : tc["custom_steps_separated"].count
        link = url(tc["id"])
        created = createdName(tc["created_by"])
        cd = DateTime.strptime(tc["created_on"].to_s,'%s')
        createDate = "#{cd.month}-#{cd.day}-#{cd.year}"
        ud = DateTime.strptime(tc["updated_on"].to_s,'%s')
        updateDate = "#{ud.month}-#{ud.day}-#{ud.year}"
        csv << [tc["id"], tc["suite_id"], created, tc["template_id"], tc["title"], desccc, precondcc, steps, createDate, updateDate, link]
      end
      puts "Data Written Successfully!\n"
    end
  end


  def pullECS_SendGrid
    puts "Pulling ECS Tests in SendGrid Project...\n"
    #this is going to go through and sort the P1 cases and write to a CSV File
    ECSUsers.each do |ecsu|
      csvFileName = ecsu["name"].gsub(" ", "_") + "_SendGrid.csv"
      #Go through each P1 and add those fields to an array
      cases = Array.new
      @p169.each do |tc|
        if tc["created_by"].eql? ecsu["id"]
          cases.push(tc)
        end
      end
      puts "Found #{cases.size} P1 DTC for #{ecsu["name"]} in SendGrid\n"
      #write the cases to the ecsusers File
      csvdata(csvFileName, cases)
    end
  end

  def pullECS_PlayGround
    puts "Pulling ECS Tests in Playground project...\n"
    #this is going to go through and sort the P1 cases and write to a CSV File
    ECSUsers.each do |ecsu|
      csvFileName = ecsu["name"].gsub(" ", "_") + "_PlayGround.csv"
      #Go through each P1 and add those fields to an array
      cases = Array.new
      @p13.each do |tc|
        if tc["created_by"].eql? ecsu["id"]
          cases.push(tc)
        end
      end
      puts "Found #{cases.size} P1 DTC for #{ecsu["name"]} in PlayGround\n"
      #write the cases to the ecsusers File
      csvdata(csvFileName, cases)
    end
  end

end

CR.new
