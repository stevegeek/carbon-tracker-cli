require "fileutils"

module CarbonOffset
  module Storage
    class JSONStorage
      attr_reader :data_dir, :config_file

      def initialize(data_dir = nil)
        @data_dir = data_dir || CarbonOffset.configuration.data_dir
        @config_file = File.join(@data_dir, "carbon_config.json")
        ensure_data_dir!
      end

      def load
        return default_data unless File.exist?(config_file)

        data = JSON.parse(File.read(config_file))
        {
          "currency" => data["currency"] || "USD",
          "monthly_budget" => data["monthly_budget"] || 0,
          "tree_types" => (data["tree_types"] || []).map { |t| Models::TreeType.new(t) },
          "carbon_entries" => (data["carbon_entries"] || []).map { |e| Models::CarbonEntry.new(e) },
          "plantings" => (data["plantings"] || []).map { |p| Models::Planting.new(p) },
          "recurring_carbon" => data["recurring_carbon"] || {"amount" => 0, "start_date" => nil}
        }
      rescue JSON::ParserError => e
        raise Error, "Failed to parse config file: #{e.message}"
      end

      def save(data)
        File.write(config_file, JSON.pretty_generate(serialize_data(data)))
        true
      rescue => e
        raise Error, "Failed to save config: #{e.message}"
      end

      def backup
        return unless File.exist?(config_file)

        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        backup_file = File.join(data_dir, "carbon_config_backup_#{timestamp}.json")
        FileUtils.cp(config_file, backup_file)

        # Keep only last 5 backups
        cleanup_old_backups
        backup_file
      end

      def restore(backup_file)
        unless File.exist?(backup_file)
          raise NotFoundError, "Backup file not found: #{backup_file}"
        end

        FileUtils.cp(backup_file, config_file)
        true
      end

      def export(format = :json)
        data = load
        case format
        when :json
          JSON.pretty_generate(serialize_data(data))
        when :csv
          export_to_csv(data)
        else
          raise ArgumentError, "Unsupported export format: #{format}"
        end
      end

      private

      def ensure_data_dir!
        FileUtils.mkdir_p(data_dir) unless File.directory?(data_dir)
      end

      def default_data
        {
          "currency" => "USD",
          "monthly_budget" => 0,
          "tree_types" => [],
          "carbon_entries" => [],
          "plantings" => [],
          "recurring_carbon" => {"amount" => 0, "start_date" => nil}
        }
      end

      def serialize_data(data)
        {
          "currency" => data["currency"],
          "monthly_budget" => data["monthly_budget"],
          "tree_types" => data["tree_types"].map(&:to_h),
          "carbon_entries" => data["carbon_entries"].map(&:to_h),
          "plantings" => data["plantings"].map(&:to_h),
          "recurring_carbon" => data["recurring_carbon"]
        }
      end

      def cleanup_old_backups
        backup_files = Dir.glob(File.join(data_dir, "carbon_config_backup_*.json"))
        return if backup_files.size <= 5

        backup_files.sort[0...-5].each { |f| File.delete(f) }
      end

      def export_to_csv(data)
        require "csv"

        CSV.generate do |csv|
          csv << ["Carbon Entries"]
          csv << ["Date", "Amount (kg)", "Description", "Category"]
          data["carbon_entries"].each do |entry|
            csv << [entry.date, entry.amount, entry.description, entry.category]
          end

          csv << []
          csv << ["Plantings"]
          csv << ["Date", "Tree Type", "Quantity", "CO2 Offset (kg)", "Cost"]
          data["plantings"].each do |planting|
            csv << [planting.date, planting.tree_type, planting.quantity, planting.co2_offset, planting.cost]
          end
        end
      end
    end
  end
end
