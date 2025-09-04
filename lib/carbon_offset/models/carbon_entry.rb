module CarbonOffset
  module Models
    class CarbonEntry
      attr_accessor :amount, :description, :date, :category, :activity_type, :quantity, :unit

      CATEGORIES = ["manual", "recurring", "activity", "transport", "energy", "food", "waste", "shopping"].freeze

      def initialize(attributes = {})
        @amount = (attributes["amount"] || attributes[:amount]).to_f
        @description = attributes["description"] || attributes[:description] || ""
        @date = parse_date(attributes["date"] || attributes[:date] || Date.today)
        @category = attributes["category"] || attributes[:category] || "manual"
        @activity_type = attributes["activity_type"] || attributes[:activity_type]
        @quantity = attributes["quantity"] || attributes[:quantity]
        @unit = attributes["unit"] || attributes[:unit]
        validate!
      end

      def month_key
        date.strftime("%Y-%m")
      end

      def to_h
        h = {
          "amount" => amount,
          "description" => description,
          "date" => date.to_s,
          "category" => category
        }
        h["activity_type"] = activity_type if activity_type
        h["quantity"] = quantity if quantity
        h["unit"] = unit if unit
        h
      end

      def to_s
        desc = description.empty? ? category : description
        "#{date}: #{amount.round(2)} kg - #{desc}"
      end

      def recurring?
        category == "recurring"
      end

      def activity?
        category == "activity" || activity_type
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
        raise ValidationError, "Amount must be non-negative" if amount < 0
        raise ValidationError, "Invalid category: #{category}" unless CATEGORIES.include?(category)
        raise ValidationError, "Date cannot be in the future" if date > Date.today
      end
    end
  end
end
