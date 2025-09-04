require "terminal-table"

module CarbonOffset
  module Reports
    class ReportGenerator
      attr_reader :storage, :calculator, :optimizer, :projection_service

      def initialize(storage = nil)
        @storage = storage || Storage::JSONStorage.new
        @calculator = Services::CarbonCalculator.new(storage)
        @optimizer = Services::PlantingOptimizer.new(storage)
        @projection_service = Services::ProjectionService.new(storage)
      end

      def generate_full_report
        data = storage.load

        sections = []
        sections << header_section
        sections << budget_section(data)
        sections << carbon_tracking_section(data)
        sections << tree_types_section(data)
        sections << plantings_section(data)
        sections << milestones_section
        sections << recommendations_section(data)

        sections.compact.join("\n\n")
      end

      def generate_summary_report
        data = storage.load

        table = Terminal::Table.new do |t|
          t.headings = ["Metric", "Value"]
          t.add_row ["Total Carbon to Offset", "#{calculator.total_carbon_to_offset(data).round(2)} kg"]
          t.add_row ["Total Offset Achieved", "#{calculator.total_offset_achieved(data).round(2)} kg"]
          t.add_row ["Remaining to Offset", "#{calculator.remaining_to_offset(data).round(2)} kg"]
          t.add_row ["Progress", "#{calculator.progress_percentage(data)}%"]
          t.add_separator
          t.add_row ["Monthly Budget", format_currency(data["monthly_budget"])]
          t.add_row ["Trees Planted", data["plantings"].sum { |p| p.quantity }]
          t.add_row ["Tree Types Available", data["tree_types"].size]
        end

        table.to_s
      end

      def generate_monthly_plan_report(months = 12, optimization_mode = :balanced)
        data = storage.load
        plan = optimizer.generate_monthly_plan(months, nil, optimization_mode)

        return "Cannot generate plan. Please set budget and add tree types." if plan.empty?

        output = []
        output << "MONTHLY PLANTING PLAN (#{optimization_mode.to_s.capitalize} Mode)".colorize(:cyan)
        output << "Budget: #{format_currency(data["monthly_budget"])}/month"
        output << "=" * 70

        table = Terminal::Table.new do |t|
          t.headings = ["Month", "Trees to Plant", "Cost", "CO2 Offset", "Remaining"]

          plan.each do |month_plan|
            trees_list = month_plan[:purchases].map { |tree, qty| "#{qty}x #{tree}" }.join(", ")
            t.add_row [
              month_plan[:date],
              trees_list,
              format_currency(month_plan[:total_cost]),
              "#{month_plan[:total_offset].round(2)} kg",
              "#{month_plan[:remaining_after].round(2)} kg"
            ]
          end

          t.add_separator
          t.add_row [
            "TOTAL",
            "",
            format_currency(plan.sum { |m| m[:total_cost] }),
            "#{plan.sum { |m| m[:total_offset] }.round(2)} kg",
            plan.last ? "#{plan.last[:remaining_after].round(2)} kg" : "0 kg"
          ]
        end

        output << table.to_s

        if plan.last && plan.last[:remaining_after] > 0
          output << "\n⚠️  This plan doesn't fully offset your carbon.".colorize(:yellow)
          output << "Consider extending the plan or increasing your budget."
        else
          output << "\n✓ This plan will fully offset your carbon!".colorize(:green)
        end

        output.join("\n")
      end

      def generate_carbon_details_report
        data = storage.load
        carbon_by_month = calculator.carbon_by_month(data)
        carbon_by_category = calculator.carbon_by_category(data)

        output = []
        output << "CARBON ENTRIES DETAILS".colorize(:cyan)
        output << "=" * 60

        # By Category
        output << "\nBy Category:"
        table = Terminal::Table.new do |t|
          t.headings = ["Category", "Count", "Total CO2 (kg)"]
          carbon_by_category.each do |category, stats|
            t.add_row [category.capitalize, stats[:count], stats[:total]]
          end
        end
        output << table.to_s

        # By Month
        output << "\nBy Month:"
        table = Terminal::Table.new do |t|
          t.headings = ["Month", "CO2 (kg)"]
          carbon_by_month.first(12).each do |month, amount|
            formatted_month = Date.parse("#{month}-01").strftime("%B %Y")
            t.add_row [formatted_month, amount]
          end
        end
        output << table.to_s

        # Recent Entries
        output << "\nRecent Entries:"
        recent_entries = data["carbon_entries"].sort_by(&:date).last(10).reverse

        table = Terminal::Table.new do |t|
          t.headings = ["Date", "Amount", "Description", "Category"]
          recent_entries.each do |entry|
            t.add_row [
              entry.date.to_s,
              "#{entry.amount.round(2)} kg",
              entry.description[0..30],
              entry.category
            ]
          end
        end
        output << table.to_s

        output.join("\n")
      end

      def generate_projection_report(years = 5)
        scenarios = projection_service.run_scenarios

        output = []
        output << "FUTURE PROJECTIONS".colorize(:cyan)
        output << "=" * 70

        table = Terminal::Table.new do |t|
          t.headings = ["Scenario", "Carbon Growth", "Budget Growth", "Neutrality Date", "Total Cost"]

          scenarios.each do |scenario|
            status = scenario[:success] ? "✓" : "✗"
            date = scenario[:neutrality_date] ? scenario[:neutrality_date].strftime("%b %Y") : "Not achieved"

            t.add_row [
              "#{status} #{scenario[:name]}",
              "#{scenario[:parameters][:carbon_growth]}%/yr",
              "#{scenario[:parameters][:budget_growth]}%/yr",
              date,
              format_currency(scenario[:total_cost])
            ]
          end
        end

        output << table.to_s
        output.join("\n")
      end

      def generate_comparison_report
        data = storage.load
        budget = data["monthly_budget"]
        max_offset = calculator.remaining_to_offset(data)

        return "Cannot generate comparison. Set budget and add tree types." if budget.zero? || data["tree_types"].empty?

        comparisons = optimizer.compare_optimization_modes(budget, max_offset)

        output = []
        output << "OPTIMIZATION MODE COMPARISON".colorize(:cyan)
        output << "Budget: #{format_currency(budget)} | Target: #{max_offset.round(2)} kg CO2"
        output << "=" * 70

        table = Terminal::Table.new do |t|
          t.headings = ["Mode", "Cost", "CO2 Offset", "Diversity", "Efficiency"]

          comparisons.each do |comp|
            t.add_row [
              comp[:mode].to_s.capitalize,
              format_currency(comp[:total_cost]),
              "#{comp[:total_offset].round(2)} kg",
              "#{comp[:tree_diversity]} types",
              "#{comp[:efficiency].round(2)} kg/$"
            ]
          end
        end

        output << table.to_s

        best = comparisons.max_by { |c| c[:efficiency] }
        output << "\n💡 Recommendation: Use #{best[:mode]} mode for best efficiency".colorize(:green)

        output.join("\n")
      end

      private

      def header_section
        [
          "=" * 70,
          "CARBON OFFSET TRACKING REPORT".center(70).colorize(:cyan),
          "Generated: #{Date.today}".center(70),
          "=" * 70
        ].join("\n")
      end

      def budget_section(data)
        return nil if data["monthly_budget"].zero?

        [
          "BUDGET:".colorize(:yellow),
          "  Monthly budget: #{format_currency(data["monthly_budget"])}",
          "  Currency: #{data["currency"]}",
          "  Annual budget: #{format_currency(data["monthly_budget"] * 12)}"
        ].join("\n")
      end

      def carbon_tracking_section(data)
        total = calculator.total_carbon_to_offset(data)
        offset = calculator.total_offset_achieved(data)
        remaining = calculator.remaining_to_offset(data)
        progress = calculator.progress_percentage(data)

        lines = [
          "CARBON TRACKING:".colorize(:yellow),
          "  Total CO2 to offset: #{total.round(2)} kg",
          "  Total offset achieved: #{offset.round(2)} kg",
          "  Remaining to offset: #{remaining.round(2)} kg"
        ]

        if total > 0
          progress_bar = generate_progress_bar(progress)
          lines << "  Progress: #{progress_bar} #{progress}%"
        end

        if data["recurring_carbon"]["amount"] && data["recurring_carbon"]["amount"] > 0
          lines << ""
          lines << "  Recurring monthly carbon: #{data["recurring_carbon"]["amount"]} kg/month"
          lines << "  Started: #{data["recurring_carbon"]["start_date"]}"
        end

        lines.join("\n")
      end

      def tree_types_section(data)
        return nil if data["tree_types"].empty?

        lines = ["TREE TYPES (sorted by efficiency):".colorize(:yellow)]

        data["tree_types"].sort_by { |t| -t.efficiency }.each do |tree|
          lines << "  #{tree.name}:".colorize(:green)
          lines << "    CO2 absorption: #{tree.co2_absorption} kg/tree (10 years)"
          lines << "    Cost: #{format_currency(tree.cost)}/tree"
          lines << "    Efficiency: #{tree.efficiency.round(2)} kg CO2/#{data["currency"]}"
        end

        lines.join("\n")
      end

      def plantings_section(data)
        return nil if data["plantings"].empty?

        total_trees = data["plantings"].sum { |p| p.quantity }
        total_spent = data["plantings"].sum { |p| p.cost }

        lines = [
          "PLANTING HISTORY:".colorize(:yellow),
          "  Total trees planted: #{total_trees}",
          "  Total spent: #{format_currency(total_spent)}"
        ]

        # By tree type
        by_type = data["plantings"].group_by(&:tree_type)
        lines << ""
        lines << "  By Tree Type:"

        by_type.each do |type, plantings|
          count = plantings.sum(&:quantity)
          co2 = plantings.sum(&:co2_offset)
          cost = plantings.sum(&:cost)
          lines << "    #{type}: #{count} trees, #{co2.round(2)} kg CO2, #{format_currency(cost)}"
        end

        lines.join("\n")
      end

      def milestones_section
        tracker = projection_service.milestone_tracker

        lines = ["MILESTONES:".colorize(:yellow)]

        tracker[:milestones].each do |milestone|
          status = milestone[:achieved] ? "✓".colorize(:green) : "○"
          lines << "  #{status} #{milestone[:name]}: #{milestone[:target].round(2)} kg"
        end

        if tracker[:next_milestone] && tracker[:next_milestone][:estimated_date]
          lines << ""
          lines << "  Next milestone: #{tracker[:next_milestone][:name]}"
          lines << "  Estimated date: #{tracker[:next_milestone][:estimated_date].strftime("%B %Y")}"
        end

        lines.join("\n")
      end

      def recommendations_section(data)
        recommendations = []

        if data["monthly_budget"].zero?
          recommendations << "• Set a monthly budget to start planning tree purchases"
        end

        if data["tree_types"].empty?
          recommendations << "• Add tree types to enable planting plans"
        elsif data["tree_types"].size < 3
          recommendations << "• Add more tree types for better biodiversity"
        end

        if data["recurring_carbon"]["amount"].nil? || data["recurring_carbon"]["amount"].zero?
          recommendations << "• Set recurring monthly carbon to track ongoing emissions"
        end

        progress = calculator.progress_percentage(data)
        if progress < 25
          recommendations << "• Consider increasing your monthly budget to accelerate progress"
        elsif progress > 75
          recommendations << "• You're close to carbon neutrality! Keep up the great work!"
        end

        return nil if recommendations.empty?

        [
          "RECOMMENDATIONS:".colorize(:yellow),
          recommendations.join("\n")
        ].join("\n")
      end

      def generate_progress_bar(percentage, width = 30)
        filled = (percentage / 100.0 * width).round
        empty = width - filled
        bar = "█" * filled + "░" * empty
        (percentage >= 50) ? bar.colorize(:green) : bar.colorize(:yellow)
      end

      def format_currency(amount)
        return "$0.00" if amount.nil? || amount.zero?

        currency = CarbonOffset.configuration.currency
        case currency
        when "EUR" then "€#{amount.round(2)}"
        when "GBP" then "£#{amount.round(2)}"
        else "$#{amount.round(2)}"
        end
      end
    end
  end
end
