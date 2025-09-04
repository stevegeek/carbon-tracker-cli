module CarbonOffset
  module Models
    class TreeType
      attr_accessor :name, :co2_absorption, :cost, :description

      def initialize(attributes = {})
        @name = attributes["name"] || attributes[:name]
        @co2_absorption = (attributes["co2_absorption"] || attributes[:co2_absorption]).to_f
        @cost = (attributes["cost"] || attributes[:cost]).to_f
        @description = attributes["description"] || attributes[:description] || ""
        validate!
      end

      def efficiency
        return 0 if cost.zero?
        co2_absorption / cost
      end

      def to_h
        {
          "name" => name,
          "co2_absorption" => co2_absorption,
          "cost" => cost,
          "description" => description,
          "efficiency" => efficiency
        }
      end

      def to_s
        "#{name}: #{co2_absorption} kg CO2 / #{formatted_cost}"
      end

      def formatted_cost
        (CarbonOffset.configuration.currency == "EUR") ? "€#{cost}" : "$#{cost}"
      end

      def ==(other)
        other.is_a?(TreeType) && name == other.name
      end

      private

      def validate!
        raise ValidationError, "Tree name is required" if name.nil? || name.empty?
        raise ValidationError, "CO2 absorption must be positive" if co2_absorption <= 0
        raise ValidationError, "Cost must be positive" if cost <= 0
      end
    end
  end
end
