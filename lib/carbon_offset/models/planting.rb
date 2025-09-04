module CarbonOffset
  module Models
    class Planting
      attr_accessor :tree_type, :quantity, :date, :co2_offset, :cost, :notes

      def initialize(attributes = {})
        @tree_type = attributes["tree_type"] || attributes[:tree_type]
        @quantity = (attributes["quantity"] || attributes[:quantity]).to_i
        @date = parse_date(attributes["date"] || attributes[:date] || Date.today)
        @co2_offset = (attributes["co2_offset"] || attributes[:co2_offset]).to_f
        @cost = (attributes["cost"] || attributes[:cost]).to_f
        @notes = attributes["notes"] || attributes[:notes] || ""
        validate!
      end

      def month_key
        date.strftime("%Y-%m")
      end

      def to_h
        {
          "tree_type" => tree_type,
          "quantity" => quantity,
          "date" => date.to_s,
          "co2_offset" => co2_offset,
          "cost" => cost,
          "notes" => notes
        }
      end

      def to_s
        "#{date}: #{quantity} × #{tree_type} (#{co2_offset.round(2)} kg CO2)"
      end

      def formatted_cost
        currency = CarbonOffset.configuration.currency
        case currency
        when "EUR" then "€#{cost.round(2)}"
        when "GBP" then "£#{cost.round(2)}"
        else "$#{cost.round(2)}"
        end
      end

      private

      def parse_date(date_value)
        case date_value
        when Date then date_value
        when String then Date.parse(date_value)
        when Time then date_value.to_date
        else Date.today
        end
      end

      def validate!
        raise ValidationError, "Tree type is required" if tree_type.nil? || tree_type.empty?
        raise ValidationError, "Quantity must be positive" if quantity <= 0
        raise ValidationError, "CO2 offset must be non-negative" if co2_offset < 0
        raise ValidationError, "Cost must be non-negative" if cost < 0
      end
    end
  end
end
