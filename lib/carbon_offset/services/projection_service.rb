module CarbonOffset
  module Services
    class ProjectionService
      attr_reader :storage, :calculator, :optimizer

      def initialize(storage = nil)
        @storage = storage || Storage::JSONStorage.new
        @calculator = CarbonCalculator.new(storage)
        @optimizer = PlantingOptimizer.new(storage)
      end

      def project_future(years = 5, carbon_growth_rate = 0, budget_growth_rate = 0)
        data = storage.load
        monthly_budget = data["monthly_budget"]

        raise ValidationError, "No monthly budget set" if monthly_budget.zero?

        projection = {
          years: years,
          carbon_growth_rate: carbon_growth_rate,
          budget_growth_rate: budget_growth_rate,
          starting_carbon: calculator.remaining_to_offset(data),
          starting_budget: monthly_budget,
          monthly_projections: [],
          summary: {}
        }

        current_carbon = projection[:starting_carbon]
        current_budget = monthly_budget
        recurring_carbon = data["recurring_carbon"]["amount"] || 0

        # Monthly growth factors
        monthly_carbon_factor = calculate_monthly_growth_factor(carbon_growth_rate)
        monthly_budget_factor = calculate_monthly_growth_factor(budget_growth_rate)

        neutrality_month = nil
        total_offset = 0
        total_cost = 0

        (years * 12).times do |month|
          # Apply growth
          if month > 0 && month % 12 == 0
            current_budget *= (1 + monthly_budget_factor)**12
            recurring_carbon *= (1 + monthly_carbon_factor)**12 if carbon_growth_rate != 0
          end

          # Add recurring carbon
          current_carbon += recurring_carbon

          # Calculate offset for this month
          month_offset_capacity = optimizer.calculate_monthly_offset_capacity(current_budget, data)
          month_offset = [month_offset_capacity, current_carbon].min

          current_carbon -= month_offset
          total_offset += month_offset
          total_cost += current_budget

          projection[:monthly_projections] << {
            month: month + 1,
            year: (month / 12) + 1,
            carbon_remaining: current_carbon.round(2),
            monthly_offset: month_offset.round(2),
            monthly_budget: current_budget.round(2),
            cumulative_offset: total_offset.round(2)
          }

          if current_carbon <= 0 && neutrality_month.nil?
            neutrality_month = month + 1
          end
        end

        projection[:summary] = {
          final_carbon: current_carbon.round(2),
          total_offset: total_offset.round(2),
          total_cost: total_cost.round(2),
          neutrality_achieved: neutrality_month,
          neutrality_date: neutrality_month ? (Date.today >> neutrality_month) : nil,
          average_monthly_offset: (total_offset / (years * 12)).round(2),
          final_monthly_budget: current_budget.round(2)
        }

        projection
      end

      def run_scenarios
        scenarios = [
          {name: "Conservative", years: 5, carbon_growth: 10, budget_growth: 3},
          {name: "Moderate", years: 5, carbon_growth: 5, budget_growth: 5},
          {name: "Optimistic", years: 5, carbon_growth: 0, budget_growth: 7},
          {name: "Aggressive Reduction", years: 5, carbon_growth: -5, budget_growth: 10},
          {name: "Status Quo", years: 5, carbon_growth: 0, budget_growth: 0}
        ]

        scenarios.map do |scenario|
          projection = project_future(
            scenario[:years],
            scenario[:carbon_growth],
            scenario[:budget_growth]
          )

          {
            name: scenario[:name],
            parameters: scenario,
            neutrality_date: projection[:summary][:neutrality_date],
            total_cost: projection[:summary][:total_cost],
            final_carbon: projection[:summary][:final_carbon],
            success: !projection[:summary][:neutrality_achieved].nil?
          }
        end
      end

      def analyze_sensitivity(base_years = 5)
        data = storage.load
        base_budget = data["monthly_budget"]

        return nil if base_budget.zero?

        analysis = {
          budget_sensitivity: [],
          carbon_sensitivity: [],
          combined_sensitivity: []
        }

        # Test budget changes
        (-20..20).step(5) do |change_pct|
          projection = project_future(base_years, 0, change_pct)
          analysis[:budget_sensitivity] << {
            change_percent: change_pct,
            neutrality_date: projection[:summary][:neutrality_date],
            total_cost: projection[:summary][:total_cost]
          }
        end

        # Test carbon changes
        (-20..20).step(5) do |change_pct|
          projection = project_future(base_years, change_pct, 0)
          analysis[:carbon_sensitivity] << {
            change_percent: change_pct,
            neutrality_date: projection[:summary][:neutrality_date],
            final_carbon: projection[:summary][:final_carbon]
          }
        end

        # Test combined changes
        [[-10, 5], [-5, 5], [0, 5], [5, 5], [10, 5]].each do |carbon, budget|
          projection = project_future(base_years, carbon, budget)
          analysis[:combined_sensitivity] << {
            carbon_change: carbon,
            budget_change: budget,
            neutrality_date: projection[:summary][:neutrality_date],
            success: !projection[:summary][:neutrality_achieved].nil?
          }
        end

        analysis
      end

      def milestone_tracker
        data = storage.load
        calculator.remaining_to_offset(data)
        total_to_offset = calculator.total_carbon_to_offset(data)
        achieved = calculator.total_offset_achieved(data)

        milestones = [
          {name: "25% Offset", target: total_to_offset * 0.25, achieved: achieved >= total_to_offset * 0.25},
          {name: "50% Offset", target: total_to_offset * 0.50, achieved: achieved >= total_to_offset * 0.50},
          {name: "75% Offset", target: total_to_offset * 0.75, achieved: achieved >= total_to_offset * 0.75},
          {name: "Carbon Neutral", target: total_to_offset, achieved: achieved >= total_to_offset}
        ]

        next_milestone = milestones.find { |m| !m[:achieved] }

        if next_milestone && data["monthly_budget"] > 0
          months_to_next = ((next_milestone[:target] - achieved) /
                           optimizer.calculate_monthly_offset_capacity(data["monthly_budget"], data)).ceil
          next_milestone[:estimated_date] = Date.today >> months_to_next
        end

        {
          milestones: milestones,
          next_milestone: next_milestone,
          progress_percentage: calculator.progress_percentage(data)
        }
      end

      private

      def calculate_monthly_growth_factor(annual_rate)
        return 0 if annual_rate.zero?
        ((1 + annual_rate / 100.0)**(1.0 / 12)) - 1
      end
    end
  end
end
