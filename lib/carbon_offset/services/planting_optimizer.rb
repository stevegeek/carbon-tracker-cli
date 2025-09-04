module CarbonOffset
  module Services
    class PlantingOptimizer
      OPTIMIZATION_MODES = [:balanced, :cost_efficient, :max_diversity].freeze

      attr_reader :storage, :diversity_factor

      def initialize(storage = nil, diversity_factor = 0.3)
        @storage = storage || Storage::JSONStorage.new
        @diversity_factor = diversity_factor.clamp(0.1, 0.5)
      end

      def generate_monthly_plan(months = 12, budget = nil, mode = :balanced)
        data = storage.load
        budget ||= data["monthly_budget"]

        raise ValidationError, "No monthly budget set" if budget.zero?
        raise ValidationError, "No tree types available" if data["tree_types"].empty?

        calculator = CarbonCalculator.new(storage)
        remaining = calculator.remaining_to_offset(data)

        plan = []
        current_date = Date.today

        months.times do |month_num|
          break if remaining <= 0

          month_date = current_date >> month_num
          month_purchase = optimize_month_purchase(budget, remaining, data["tree_types"], mode)

          if month_purchase[:total_offset] > 0
            plan << {
              month: month_num + 1,
              date: month_date.strftime("%B %Y"),
              purchases: month_purchase[:purchases],
              total_cost: month_purchase[:total_cost],
              total_offset: month_purchase[:total_offset],
              cumulative_offset: plan.sum { |p| p[:total_offset] } + month_purchase[:total_offset],
              remaining_after: [remaining - month_purchase[:total_offset], 0].max
            }
            remaining -= month_purchase[:total_offset]
          end
        end

        plan
      end

      def optimize_month_purchase(budget, max_offset_needed, tree_types, mode = :balanced)
        tree_types = Array(tree_types).map do |t|
          t.is_a?(Models::TreeType) ? t : Models::TreeType.new(t)
        end.sort_by { |t| -t.efficiency }

        case mode
        when :cost_efficient
          optimize_for_efficiency(budget, max_offset_needed, tree_types)
        when :max_diversity
          optimize_for_diversity(budget, max_offset_needed, tree_types)
        else
          optimize_balanced(budget, max_offset_needed, tree_types)
        end
      end

      def record_planting(tree_name, quantity, date = Date.today)
        data = storage.load
        tree = data["tree_types"].find { |t| t.name == tree_name }

        raise NotFoundError, "Tree type not found: #{tree_name}" unless tree

        planting = Models::Planting.new(
          "tree_type" => tree_name,
          "quantity" => quantity,
          "date" => date,
          "co2_offset" => quantity * tree.co2_absorption,
          "cost" => quantity * tree.cost
        )

        data["plantings"] << planting
        storage.save(data)
        planting
      end

      def calculate_monthly_offset_capacity(budget, data = nil)
        data ||= storage.load
        return 0 if data["tree_types"].empty? || budget.zero?

        # Use most efficient tree to estimate capacity
        most_efficient = data["tree_types"].max_by(&:efficiency)
        (budget / most_efficient.cost).floor * most_efficient.co2_absorption
      end

      def compare_optimization_modes(budget, max_offset)
        data = storage.load
        tree_types = data["tree_types"]

        OPTIMIZATION_MODES.map do |mode|
          result = optimize_month_purchase(budget, max_offset, tree_types, mode)
          {
            mode: mode,
            total_cost: result[:total_cost],
            total_offset: result[:total_offset],
            tree_diversity: result[:purchases].keys.size,
            efficiency: result[:total_offset] / result[:total_cost].to_f,
            purchases: result[:purchases]
          }
        end
      end

      private

      def optimize_balanced(budget, max_offset, tree_types)
        purchases = {}
        total_cost = 0
        total_offset = 0

        # Phase 1: Ensure diversity (use diversity_factor of budget)
        if tree_types.size > 1
          diversity_budget = budget * diversity_factor
          min_types = [tree_types.size, 3].min
          base_allocation = diversity_budget / min_types

          tree_types.first(min_types).each do |tree|
            if base_allocation >= tree.cost
              quantity = (base_allocation / tree.cost).floor
              if quantity > 0
                purchases[tree.name] = quantity
                total_cost += quantity * tree.cost
                total_offset += quantity * tree.co2_absorption
              end
            end
          end
        end

        # Phase 2: Optimize remaining budget for efficiency
        remaining_budget = budget - total_cost

        tree_types.each do |tree|
          break if remaining_budget < tree.cost
          break if total_offset >= max_offset

          max_quantity = (remaining_budget / tree.cost).floor
          needed_quantity = ((max_offset - total_offset) / tree.co2_absorption).ceil
          quantity = [max_quantity, needed_quantity].min

          if quantity > 0
            purchases[tree.name] = (purchases[tree.name] || 0) + quantity
            total_cost += quantity * tree.cost
            total_offset += quantity * tree.co2_absorption
            remaining_budget -= quantity * tree.cost
          end
        end

        {
          purchases: purchases,
          total_cost: total_cost.round(2),
          total_offset: total_offset.round(2)
        }
      end

      def optimize_for_efficiency(budget, max_offset, tree_types)
        purchases = {}
        total_cost = 0
        total_offset = 0
        remaining_budget = budget

        # Buy most efficient trees first
        tree_types.each do |tree|
          break if remaining_budget < tree.cost
          break if total_offset >= max_offset

          max_quantity = (remaining_budget / tree.cost).floor
          needed_quantity = ((max_offset - total_offset) / tree.co2_absorption).ceil
          quantity = [max_quantity, needed_quantity].min

          if quantity > 0
            purchases[tree.name] = quantity
            total_cost += quantity * tree.cost
            total_offset += quantity * tree.co2_absorption
            remaining_budget -= quantity * tree.cost
          end
        end

        {
          purchases: purchases,
          total_cost: total_cost.round(2),
          total_offset: total_offset.round(2)
        }
      end

      def optimize_for_diversity(budget, max_offset, tree_types)
        purchases = {}
        total_cost = 0
        total_offset = 0

        # Distribute budget equally among all tree types
        types_to_use = tree_types.select { |t| t.cost <= budget }
        return {purchases: {}, total_cost: 0, total_offset: 0} if types_to_use.empty?

        allocation_per_type = budget / types_to_use.size

        types_to_use.each do |tree|
          quantity = (allocation_per_type / tree.cost).floor
          if quantity > 0
            purchases[tree.name] = quantity
            total_cost += quantity * tree.cost
            total_offset += quantity * tree.co2_absorption
          end
        end

        # Use remaining budget on most efficient tree
        remaining_budget = budget - total_cost
        if remaining_budget > 0 && total_offset < max_offset
          most_efficient = tree_types.first
          if remaining_budget >= most_efficient.cost
            extra = (remaining_budget / most_efficient.cost).floor
            purchases[most_efficient.name] = (purchases[most_efficient.name] || 0) + extra
            total_cost += extra * most_efficient.cost
            total_offset += extra * most_efficient.co2_absorption
          end
        end

        {
          purchases: purchases,
          total_cost: total_cost.round(2),
          total_offset: total_offset.round(2)
        }
      end
    end
  end
end
