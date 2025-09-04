module CarbonOffset
  module Services
    class EmissionFactors
      attr_reader :factors_file, :custom_factors_file

      def initialize
        @factors_file = File.join(File.dirname(__FILE__), "..", "data", "emission_factors.json")
        @custom_factors_file = File.join(CarbonOffset.configuration.data_dir, "custom_emission_factors.json")
        load_factors
      end

      def load_factors
        # Load default factors
        @factors = if File.exist?(@factors_file)
          JSON.parse(File.read(@factors_file))
        else
          {}
        end

        # Load and merge custom factors
        if File.exist?(@custom_factors_file)
          custom = JSON.parse(File.read(@custom_factors_file))
          @factors = deep_merge(@factors, custom)
        end
      end

      def get_factor(category, activity)
        return nil unless @factors[category]
        @factors[category][activity]
      end

      def calculate_emissions(category, activity, quantity)
        factor = get_factor(category, activity)
        return nil unless factor

        quantity.to_f * factor["co2_per_unit"]
      end

      def add_custom_factor(category, activity, unit, co2_per_unit, description = "")
        # Ensure custom factors file exists
        custom = File.exist?(@custom_factors_file) ?
          JSON.parse(File.read(@custom_factors_file)) : {}

        custom[category] ||= {}
        custom[category][activity] = {
          "unit" => unit,
          "co2_per_unit" => co2_per_unit,
          "description" => description
        }

        File.write(@custom_factors_file, JSON.pretty_generate(custom))
        load_factors  # Reload to include new factor

        custom[category][activity]
      end

      def list_categories
        @factors.keys.sort
      end

      def list_activities(category = nil)
        if category
          return {} unless @factors[category]
          @factors[category]
        else
          @factors
        end
      end

      def search_activities(keyword)
        results = {}

        @factors.each do |category, activities|
          activities.each do |activity, data|
            if activity.include?(keyword.downcase) ||
                data["description"].downcase.include?(keyword.downcase)
              results["#{category}/#{activity}"] = data
            end
          end
        end

        results
      end

      def format_activity_list(category = nil)
        output = []

        if category
          if @factors[category]
            output << "#{category.upcase}:".colorize(:cyan)
            @factors[category].each do |activity, data|
              output << "  #{activity}:".colorize(:green)
              output << "    Unit: #{data["unit"]}"
              output << "    CO2: #{data["co2_per_unit"]} kg/#{data["unit"]}"
              output << "    Description: #{data["description"]}"
            end
          else
            output << "Category '#{category}' not found".colorize(:red)
          end
        else
          @factors.each do |cat, activities|
            output << "\n#{cat.upcase}:".colorize(:cyan)
            activities.each do |activity, data|
              output << "  #{cat}/#{activity}: #{data["co2_per_unit"]} kg CO2/#{data["unit"]} - #{data["description"]}"
            end
          end
        end

        output.join("\n")
      end

      def validate_activity(category, activity)
        return false unless @factors[category]
        return false unless @factors[category][activity]
        true
      end

      private

      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end
    end
  end
end
