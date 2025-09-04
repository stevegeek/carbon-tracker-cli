module CarbonOffset
  module Services
    class CarbonCalculator
      attr_reader :storage, :emission_factors

      def initialize(storage = nil)
        @storage = storage || Storage::JSONStorage.new
        @emission_factors = EmissionFactors.new
      end

      def total_carbon_to_offset(data = nil)
        data ||= storage.load
        process_recurring_carbon(data)
        data["carbon_entries"].sum { |entry| entry.amount }
      end

      def total_offset_achieved(data = nil)
        data ||= storage.load
        data["plantings"].sum { |planting| planting.co2_offset }
      end

      def remaining_to_offset(data = nil)
        data ||= storage.load
        [total_carbon_to_offset(data) - total_offset_achieved(data), 0].max
      end

      def progress_percentage(data = nil)
        data ||= storage.load
        total_carbon = total_carbon_to_offset(data)
        return 0 if total_carbon.zero?

        ((total_offset_achieved(data) / total_carbon) * 100).round(1)
      end

      def add_carbon_entry(amount, description = "", date = Date.today, category = "manual", activity_type = nil, quantity = nil, unit = nil)
        data = storage.load
        entry = Models::CarbonEntry.new(
          "amount" => amount,
          "description" => description,
          "date" => date,
          "category" => category,
          "activity_type" => activity_type,
          "quantity" => quantity,
          "unit" => unit
        )
        data["carbon_entries"] << entry
        storage.save(data)
        entry
      end

      def add_activity(category, activity, quantity, description = "", date = Date.today)
        # Calculate CO2 from activity
        co2_amount = @emission_factors.calculate_emissions(category, activity, quantity)

        raise ValidationError, "Unknown activity: #{category}/#{activity}" unless co2_amount

        factor = @emission_factors.get_factor(category, activity)

        # Build description with activity details
        full_description = description.empty? ?
          "#{factor["description"]} (#{quantity} #{factor["unit"]})" :
          "#{description} (#{quantity} #{factor["unit"]})"

        # Add entry with activity metadata
        add_carbon_entry(
          co2_amount,
          full_description,
          date,
          "activity",
          "#{category}/#{activity}",
          quantity,
          factor["unit"]
        )
      end

      def add_recurring_carbon(monthly_amount, start_date = Date.today)
        data = storage.load
        data["recurring_carbon"] = {
          "amount" => monthly_amount,
          "start_date" => start_date.to_s
        }
        storage.save(data)
        process_recurring_carbon(data)
      end

      def carbon_by_category(data = nil)
        data ||= storage.load
        data["carbon_entries"].group_by(&:category).transform_values do |entries|
          {
            count: entries.size,
            total: entries.sum(&:amount).round(2)
          }
        end
      end

      def carbon_by_month(data = nil)
        data ||= storage.load
        data["carbon_entries"].group_by(&:month_key).transform_values do |entries|
          entries.sum(&:amount).round(2)
        end.sort.reverse.to_h
      end

      def monthly_carbon_trend(months = 6)
        data = storage.load
        end_date = Date.today
        start_date = end_date << months

        trend = {}
        current_date = start_date

        while current_date <= end_date
          month_key = current_date.strftime("%Y-%m")
          month_entries = data["carbon_entries"].select do |entry|
            entry.month_key == month_key
          end
          trend[month_key] = month_entries.sum(&:amount).round(2)
          current_date >>= 1
        end

        trend
      end

      def projected_neutrality_date(monthly_budget = nil)
        data = storage.load
        monthly_budget ||= data["monthly_budget"] || 0
        return nil if monthly_budget.zero?

        remaining = remaining_to_offset(data)
        recurring_monthly = data["recurring_carbon"]["amount"] || 0

        # Calculate average monthly offset capacity
        optimizer = PlantingOptimizer.new(storage)
        monthly_offset = optimizer.calculate_monthly_offset_capacity(monthly_budget, data)

        return nil if monthly_offset <= recurring_monthly

        net_monthly_reduction = monthly_offset - recurring_monthly
        months_needed = (remaining / net_monthly_reduction).ceil

        Date.today >> months_needed
      end

      private

      def process_recurring_carbon(data)
        recurring = data["recurring_carbon"]
        return if recurring["amount"].nil? || recurring["amount"].zero? || recurring["start_date"].nil?

        start_date = Date.parse(recurring["start_date"])
        today = Date.today
        return if today < start_date

        # Find the last recurring entry
        recurring_entries = data["carbon_entries"].select(&:recurring?)
        last_date = recurring_entries.map(&:date).max

        # Add missing recurring entries
        current_date = last_date ? last_date.next_month : start_date

        while current_date <= today
          if current_date.day == start_date.day || current_date == current_date.end_of_month
            entry = Models::CarbonEntry.new(
              "amount" => recurring["amount"],
              "description" => "Monthly recurring carbon",
              "date" => current_date,
              "category" => "recurring"
            )
            data["carbon_entries"] << entry
          end
          current_date = current_date.next_month
        end

        storage.save(data) if last_date != current_date
      end
    end
  end
end
