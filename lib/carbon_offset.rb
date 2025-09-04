require "json"
require "date"
require "colorize"
require "terminal-table"

module CarbonOffset
  VERSION = "2.0.0"

  class Error < StandardError; end

  class ValidationError < Error; end

  class NotFoundError < Error; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def root
      File.expand_path("../..", __FILE__)
    end
  end

  class Configuration
    attr_accessor :data_dir, :currency, :monthly_budget, :diversity_factor

    def initialize
      # Allow environment variable override, otherwise use local directory
      @data_dir = ENV["CARBON_DATA_DIR"] || File.join(Dir.pwd, ".carbon_data")
      @currency = "USD"
      @monthly_budget = 0
      @diversity_factor = 0.3
    end
  end
end

# Autoload all components
require_relative "carbon_offset/models/tree_type"
require_relative "carbon_offset/models/carbon_entry"
require_relative "carbon_offset/models/planting"
require_relative "carbon_offset/services/emission_factors"
require_relative "carbon_offset/services/carbon_calculator"
require_relative "carbon_offset/services/planting_optimizer"
require_relative "carbon_offset/services/projection_service"
require_relative "carbon_offset/storage/json_storage"
require_relative "carbon_offset/reports/report_generator"
require_relative "carbon_offset/cli"
