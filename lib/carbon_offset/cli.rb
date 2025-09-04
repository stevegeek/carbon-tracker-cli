require "thor"

module CarbonOffset
  class CLI < Thor
    def initialize(*args)
      super
      CarbonOffset.configure
      @storage = Storage::JSONStorage.new
      @calculator = Services::CarbonCalculator.new(@storage)
      @optimizer = Services::PlantingOptimizer.new(@storage)
      @projector = Services::ProjectionService.new(@storage)
      @reporter = Reports::ReportGenerator.new(@storage)
    end

    desc "config", "Configure carbon offset tracker"
    option :budget, type: :numeric, desc: "Set monthly budget"
    option :currency, type: :string, desc: "Set currency (USD, EUR, GBP)"
    option :data_dir, type: :string, desc: "Set data directory (default: ./.carbon_data)"
    def config
      data = @storage.load

      if options[:budget]
        data["monthly_budget"] = options[:budget]
        puts "Set monthly budget: #{format_currency(options[:budget], data["currency"])}".colorize(:green)
      end

      if options[:currency]
        data["currency"] = options[:currency]
        CarbonOffset.configuration.currency = options[:currency]
        puts "Set currency to: #{options[:currency]}".colorize(:green)
      end

      if options[:data_dir]
        new_dir = File.expand_path(options[:data_dir])
        CarbonOffset.configuration.data_dir = new_dir
        @storage = Storage::JSONStorage.new(new_dir)
        puts "Set data directory to: #{new_dir}".colorize(:green)
      end

      @storage.save(data) if options.any?

      unless options.any?
        puts "Current configuration:".colorize(:cyan)
        puts "  Currency: #{data["currency"]}"
        puts "  Monthly budget: #{format_currency(data["monthly_budget"], data["currency"])}"
        puts "  Data directory: #{CarbonOffset.configuration.data_dir}"
        puts "\nNote: Data is stored locally in .carbon_data/ by default".colorize(:yellow)
        puts "Use --data-dir to change location (e.g., --data-dir ~/Documents/carbon)".colorize(:yellow)
      end
    end

    desc "tree add NAME CO2_ABSORPTION COST", "Add a tree type"
    option :description, type: :string, desc: "Tree description"
    def tree(action, *args)
      case action
      when "add"
        name, co2, cost = args
        data = @storage.load

        tree = Models::TreeType.new(
          "name" => name,
          "co2_absorption" => co2.to_f,
          "cost" => cost.to_f,
          "description" => options[:description] || ""
        )

        data["tree_types"] << tree
        data["tree_types"].sort_by! { |t| -t.efficiency }
        @storage.save(data)

        puts "Added tree type: #{tree}".colorize(:green)
        puts "  Efficiency: #{tree.efficiency.round(2)} kg CO2/#{data["currency"]}".colorize(:cyan)
      when "list"
        data = @storage.load
        if data["tree_types"].empty?
          puts "No tree types configured. Use 'carbon_offset tree add' to add some.".colorize(:yellow)
        else
          puts "\nTree Types (sorted by efficiency):".colorize(:cyan)
          data["tree_types"].each do |tree|
            puts "  #{tree.name}:".colorize(:green)
            puts "    CO2: #{tree.co2_absorption} kg | Cost: #{format_currency(tree.cost, data["currency"])}"
            puts "    Efficiency: #{tree.efficiency.round(2)} kg/#{data["currency"]}"
          end
        end
      end
    end

    desc "carbon add AMOUNT [DESCRIPTION]", "Add carbon to offset"
    option :date, type: :string, desc: "Entry date (YYYY-MM-DD)"
    option :category, type: :string, default: "manual", desc: "Category"
    def carbon(action, *args)
      case action
      when "add"
        amount = args[0].to_f
        description = args[1] || ""
        date = options[:date] ? Date.parse(options[:date]) : Date.today

        entry = @calculator.add_carbon_entry(amount, description, date, options[:category])
        puts "Added carbon entry: #{entry}".colorize(:green)
      when "recurring"
        amount = args[0].to_f
        @calculator.add_recurring_carbon(amount)
        puts "Set recurring carbon: #{amount} kg/month starting today".colorize(:green)
      when "list"
        puts @reporter.generate_carbon_details_report
      end
    end

    desc "activity CATEGORY/ACTIVITY QUANTITY [DESCRIPTION]", "Add activity that generates carbon"
    option :date, type: :string, desc: "Activity date (YYYY-MM-DD)"
    def activity(activity_spec, quantity, description = "")
      parts = activity_spec.split("/")
      if parts.length != 2
        puts "Error: Activity must be in format 'category/activity'".colorize(:red)
        puts "Example: activity transport/flight_short 1 'NYC trip'".colorize(:yellow)
        return
      end

      category, activity_name = parts
      date = options[:date] ? Date.parse(options[:date]) : Date.today

      begin
        entry = @calculator.add_activity(category, activity_name, quantity.to_f, description, date)
        puts "Added activity: #{entry}".colorize(:green)
        puts "CO2 calculated: #{entry.amount.round(2)} kg".colorize(:cyan)
      rescue ValidationError => e
        puts e.message.colorize(:red)
        puts "Use 'carbon_offset factors list' to see available activities".colorize(:yellow)
      end
    end

    desc "factors SUBCOMMAND ...ARGS", "Manage emission factors"
    def factors(subcommand = "list", *args)
      @emission_factors = Services::EmissionFactors.new

      case subcommand
      when "list"
        category = args[0]
        puts @emission_factors.format_activity_list(category)
      when "search"
        keyword = args[0]
        unless keyword
          puts "Please provide a search keyword".colorize(:red)
          return
        end

        results = @emission_factors.search_activities(keyword)
        if results.empty?
          puts "No activities found matching '#{keyword}'".colorize(:yellow)
        else
          puts "Activities matching '#{keyword}':".colorize(:cyan)
          results.each do |activity, data|
            puts "  #{activity}: #{data["co2_per_unit"]} kg CO2/#{data["unit"]} - #{data["description"]}".colorize(:green)
          end
        end
      when "add"
        if args.length < 4
          puts "Usage: factors add CATEGORY ACTIVITY UNIT CO2_PER_UNIT [DESCRIPTION]".colorize(:red)
          return
        end

        category, activity, unit, co2 = args[0..3]
        description = args[4] || ""

        @emission_factors.add_custom_factor(
          category, activity, unit, co2.to_f, description
        )
        puts "Added custom emission factor:".colorize(:green)
        puts "  #{category}/#{activity}: #{co2} kg CO2/#{unit}".colorize(:cyan)
      when "categories"
        puts "Available categories:".colorize(:cyan)
        @emission_factors.list_categories.each do |cat|
          count = @emission_factors.list_activities(cat).size
          puts "  - #{cat} (#{count} activities)".colorize(:green)
        end
      else
        puts "Unknown factors subcommand: #{subcommand}".colorize(:red)
        puts "Available: list, search, add, categories".colorize(:yellow)
      end
    end

    desc "plant TREE_NAME QUANTITY", "Record tree planting"
    option :date, type: :string, desc: "Planting date (YYYY-MM-DD)"
    option :notes, type: :string, desc: "Additional notes"
    def plant(tree_name, quantity)
      date = options[:date] ? Date.parse(options[:date]) : Date.today

      begin
        planting = @optimizer.record_planting(tree_name, quantity.to_i, date)
        puts "Recorded planting: #{planting}".colorize(:green)
        puts "CO2 offset: #{planting.co2_offset.round(2)} kg | Cost: #{planting.formatted_cost}".colorize(:cyan)
      rescue NotFoundError => e
        puts e.message.colorize(:red)
        puts "Available tree types: #{@storage.load["tree_types"].map(&:name).join(", ")}"
      end
    end

    desc "plan [MONTHS]", "Generate monthly planting plan"
    option :mode, type: :string, default: "balanced", desc: "Optimization mode (balanced, cost_efficient, max_diversity)"
    option :budget, type: :numeric, desc: "Override monthly budget"
    def plan(months = 12)
      mode = options[:mode].to_sym
      puts @reporter.generate_monthly_plan_report(months.to_i, mode)
    end

    desc "report", "Generate status report"
    option :format, type: :string, default: "full", desc: "Report format (full, summary, carbon, milestones)"
    def report
      case options[:format]
      when "summary"
        puts @reporter.generate_summary_report
      when "carbon"
        puts @reporter.generate_carbon_details_report
      when "milestones"
        tracker = @projector.milestone_tracker
        puts "\nMILESTONES:".colorize(:cyan)
        tracker[:milestones].each do |m|
          status = m[:achieved] ? "✓".colorize(:green) : "○"
          puts "  #{status} #{m[:name]}: #{m[:target].round(2)} kg"
        end
        if tracker[:next_milestone]
          puts "\nNext: #{tracker[:next_milestone][:name]}".colorize(:yellow)
          puts "Est. date: #{tracker[:next_milestone][:estimated_date]}" if tracker[:next_milestone][:estimated_date]
        end
      else
        puts @reporter.generate_full_report
      end
    end

    desc "project [YEARS]", "Project future carbon neutrality"
    option :carbon_growth, type: :numeric, default: 0, desc: "Annual carbon growth rate %"
    option :budget_growth, type: :numeric, default: 0, desc: "Annual budget growth rate %"
    def project(years = 5)
      projection = @projector.project_future(years.to_i, options[:carbon_growth], options[:budget_growth])

      puts "\nPROJECTION RESULTS".colorize(:cyan)
      puts "=" * 60
      puts "Parameters:"
      puts "  Years: #{years}"
      puts "  Carbon growth: #{options[:carbon_growth]}% annually"
      puts "  Budget growth: #{options[:budget_growth]}% annually"
      puts "\nResults:"

      summary = projection[:summary]
      if summary[:neutrality_achieved]
        puts "  ✓ Carbon neutrality achieved in month #{summary[:neutrality_achieved]}".colorize(:green)
        puts "  Date: #{summary[:neutrality_date].strftime("%B %Y")}".colorize(:green)
      else
        puts "  ✗ Carbon neutrality not achieved within projection period".colorize(:red)
      end

      puts "  Final carbon: #{summary[:final_carbon]} kg"
      puts "  Total offset: #{summary[:total_offset]} kg"
      puts "  Total cost: #{format_currency(summary[:total_cost], @storage.load["currency"])}"
    end

    desc "scenarios", "Run multiple projection scenarios"
    def scenarios
      puts @reporter.generate_projection_report
    end

    desc "compare", "Compare optimization modes"
    def compare
      puts @reporter.generate_comparison_report
    end

    desc "backup", "Backup configuration"
    def backup
      backup_file = @storage.backup
      puts "Configuration backed up to: #{backup_file}".colorize(:green) if backup_file
    end

    desc "restore BACKUP_FILE", "Restore from backup"
    def restore(backup_file)
      @storage.restore(backup_file)
      puts "Configuration restored from: #{backup_file}".colorize(:green)
    rescue NotFoundError => e
      puts e.message.colorize(:red)
    end

    desc "export", "Export data"
    option :format, type: :string, default: "json", desc: "Export format (json, csv)"
    option :output, type: :string, desc: "Output file path"
    def export
      content = @storage.export(options[:format].to_sym)

      if options[:output]
        File.write(options[:output], content)
        puts "Data exported to: #{options[:output]}".colorize(:green)
      else
        puts content
      end
    end

    desc "example", "Load example data for testing"
    def example
      data = @storage.load

      # Set currency and budget
      data["currency"] = "USD"
      data["monthly_budget"] = 150

      # Add tree types
      trees = [
        {name: "Oak", co2: 500, cost: 25, desc: "Strong hardwood, long-lived"},
        {name: "Pine", co2: 300, cost: 15, desc: "Fast-growing conifer"},
        {name: "Maple", co2: 400, cost: 20, desc: "Beautiful deciduous tree"},
        {name: "Birch", co2: 250, cost: 12, desc: "Hardy and adaptable"},
        {name: "Willow", co2: 450, cost: 30, desc: "Water-loving, fast growth"}
      ]

      data["tree_types"] = trees.map do |t|
        Models::TreeType.new(
          "name" => t[:name],
          "co2_absorption" => t[:co2],
          "cost" => t[:cost],
          "description" => t[:desc]
        )
      end

      # Add carbon entries
      data["carbon_entries"] = [
        Models::CarbonEntry.new(
          "amount" => 1200,
          "description" => "Annual electricity usage",
          "date" => Date.today - 30,
          "category" => "energy"
        ),
        Models::CarbonEntry.new(
          "amount" => 800,
          "description" => "Car commute Q1",
          "date" => Date.today - 15,
          "category" => "transport"
        ),
        Models::CarbonEntry.new(
          "amount" => 300,
          "description" => "Flight to conference",
          "date" => Date.today - 5,
          "category" => "transport"
        )
      ]

      # Set recurring carbon
      data["recurring_carbon"] = {
        "amount" => 100,
        "start_date" => (Date.today - 60).to_s
      }

      # Add sample planting
      data["plantings"] = [
        Models::Planting.new(
          "tree_type" => "Oak",
          "quantity" => 3,
          "date" => Date.today - 10,
          "co2_offset" => 1500,
          "cost" => 75
        )
      ]

      @storage.save(data)

      puts "Loaded example data:".colorize(:green)
      puts "  ✓ 5 tree types"
      puts "  ✓ Monthly budget: $150"
      puts "  ✓ Sample carbon entries (2300 kg total)"
      puts "  ✓ Recurring carbon: 100 kg/month"
      puts "  ✓ Sample planting: 3 Oak trees"
      puts "\nRun 'carbon_offset report' to see your status!".colorize(:cyan)
    end

    desc "version", "Show version"
    def version
      puts "Carbon Offset Tracker v#{CarbonOffset::VERSION}".colorize(:cyan)
    end

    private

    def format_currency(amount, currency = "USD")
      case currency
      when "EUR" then "€#{amount.round(2)}"
      when "GBP" then "£#{amount.round(2)}"
      else "$#{amount.round(2)}"
      end
    end
  end
end
