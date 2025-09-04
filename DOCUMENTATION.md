# Carbon Offset Tracker - Complete Documentation

## Overview

A comprehensive Ruby application for tracking carbon footprint and planning tree-planting offsets with budget optimization, future projections, and diversity management. The system helps you:

1. Track your carbon emissions (one-time and recurring)
2. Manage different tree types with their CO2 absorption rates and costs
3. Optimize monthly tree purchases within budget constraints
4. Project when you'll achieve carbon neutrality
5. Balance cost efficiency with biodiversity

## Installation

```bash
# Install Ruby dependencies
bundle install

# Make the script executable
chmod +x bin/carbon_offset

# Test the installation
ruby bin/carbon_offset version
```

## Quick Start

```bash
# Load example data to explore features
ruby bin/carbon_offset example

# View current status
ruby bin/carbon_offset report

# Generate a monthly planting plan
ruby bin/carbon_offset plan
```

## Core Features

### 1. Budget Management

Set and manage your monthly budget in any currency:

```bash
# Set monthly budget and currency
ruby bin/carbon_offset config --budget 200 --currency USD

# View current configuration
ruby bin/carbon_offset config
```

Supported currencies: USD, EUR, GBP, and others (currency symbol display for USD/EUR/GBP)

### 2. Carbon Tracking

The system tracks carbon emissions in four ways:

#### Activity-Based Tracking (Recommended)
Track activities and let the system calculate CO2 automatically using built-in emission factors:
```bash
# Format: activity category/activity_name quantity [description]
ruby bin/carbon_offset activity transport/flight_short 1 "NYC trip"
ruby bin/carbon_offset activity energy/electricity 350 "Monthly power bill"
ruby bin/carbon_offset activity food/beef 10 "Weekly shopping"
ruby bin/carbon_offset activity shopping/laptop 1 "New work computer"

# The system automatically calculates CO2 based on emission factors
# Example: 1 short flight = 255 kg CO2, 350 kWh electricity = 134.75 kg CO2
```

#### Direct Carbon Entry
Add carbon emissions when you know the exact amount:
```bash
ruby bin/carbon_offset carbon add 300 "Flight to NYC"
ruby bin/carbon_offset carbon add 150 "Monthly electricity"

# With specific date
ruby bin/carbon_offset carbon add 500 "Q1 heating" --date 2024-03-15

# With category
ruby bin/carbon_offset carbon add 200 "Commute" --category transport
```

#### Initial Carbon Debt
Set your starting carbon footprint:
```bash
ruby bin/carbon_offset carbon add 5000 "Initial 2024 carbon footprint"
```

#### Recurring Monthly Carbon
Set automatic monthly carbon additions:
```bash
# Set 150 kg to be added automatically each month
ruby bin/carbon_offset carbon recurring 150
```

The system automatically adds this amount each month from the start date.

### 3. Emission Factors Database

The system includes a comprehensive database of emission factors for common activities:

#### View Available Activities
```bash
# List all categories
ruby bin/carbon_offset factors categories

# List activities in a category
ruby bin/carbon_offset factors list transport
ruby bin/carbon_offset factors list food
ruby bin/carbon_offset factors list energy

# Search for specific activities
ruby bin/carbon_offset factors search flight
ruby bin/carbon_offset factors search electricity
```

#### Built-in Categories
- **Transport**: flights, cars, trains, buses, ferries
- **Energy**: electricity, gas, heating oil, renewable sources
- **Food**: meat, dairy, vegetables, beverages
- **Shopping**: clothing, electronics, furniture
- **Waste**: landfill, recycling, composting
- **Digital**: streaming, cloud storage, video calls
- **Accommodation**: hotels, home heating

#### Add Custom Emission Factors
```bash
# Add your own emission factors
# Format: factors add CATEGORY ACTIVITY UNIT CO2_PER_UNIT [DESCRIPTION]
ruby bin/carbon_offset factors add transport ebike km 0.01 "Electric bicycle"
ruby bin/carbon_offset factors add energy solar kWh 0.048 "Solar panels"
```

Custom factors are stored separately and override default values.

### 4. Tree Type Management

Add and manage different tree types with their specifications:

```bash
# Add a tree type: name, CO2 absorption (kg over 10 years), cost per tree
ruby bin/carbon_offset tree add "Oak" 500 25
ruby bin/carbon_offset tree add "Pine" 300 15 --description "Fast-growing conifer"

# List all tree types
ruby bin/carbon_offset tree list
```

Trees are automatically sorted by efficiency (kg CO2 per dollar).

### 4. Recording Plantings

Track actual tree plantings:

```bash
# Record planting: tree name, quantity
ruby bin/carbon_offset plant "Oak" 5
ruby bin/carbon_offset plant "Pine" 10 --date 2024-06-15 --notes "Spring planting"
```

The system automatically:
- Calculates CO2 offset based on tree type
- Tracks cost
- Updates remaining carbon to offset

### 5. Monthly Planning

Generate optimized monthly planting plans:

```bash
# Generate 12-month plan (default)
ruby bin/carbon_offset plan

# Generate 6-month plan
ruby bin/carbon_offset plan 6

# Use different optimization modes
ruby bin/carbon_offset plan --mode balanced      # Default: balance efficiency and diversity
ruby bin/carbon_offset plan --mode cost_efficient # Maximize CO2 offset per dollar
ruby bin/carbon_offset plan --mode max_diversity  # Maximum tree type diversity
```

The planner:
- Respects your monthly budget
- Ensures tree diversity (allocates 30% of budget to multiple types by default)
- Optimizes for maximum CO2 offset
- Shows month-by-month purchases needed

### 6. Future Projections

Project when you'll achieve carbon neutrality with growth modeling:

```bash
# Basic projection: years, carbon growth %, budget growth %
ruby bin/carbon_offset project 5 --carbon-growth 10 --budget-growth 5

# Run multiple scenarios
ruby bin/carbon_offset scenarios

# Compare optimization modes
ruby bin/carbon_offset compare
```

Projection features:
- **Compound Growth**: Monthly compounding for realistic modeling
- **Carbon Growth**: Model increasing/decreasing emissions over time
- **Budget Growth**: Account for income changes
- **Neutrality Date**: Calculates exact month of carbon neutrality
- **Total Cost**: Shows total investment needed

Built-in scenarios:
- Conservative: 10% carbon growth, 3% budget growth
- Moderate: 5% carbon growth, 5% budget growth  
- Optimistic: 0% carbon growth, 7% budget growth
- Aggressive Reduction: -5% carbon growth, 10% budget growth
- Status Quo: No growth in either

### 7. Reporting

Multiple report types available:

```bash
# Full comprehensive report
ruby bin/carbon_offset report

# Summary table
ruby bin/carbon_offset report --format summary

# Carbon entries details
ruby bin/carbon_offset report --format carbon

# Progress milestones
ruby bin/carbon_offset report --format milestones
```

Reports include:
- Total carbon to offset vs. achieved
- Progress percentage with visual bar
- Carbon breakdown by category and month
- Tree planting history
- Budget utilization
- Recommendations

### 8. Data Management

#### Backup and Restore
```bash
# Create backup
ruby bin/carbon_offset backup

# Restore from backup  
ruby bin/carbon_offset restore .carbon_data/carbon_config_backup_20240915_143022.json
```

#### Export Data
```bash
# Export as JSON
ruby bin/carbon_offset export

# Export as CSV
ruby bin/carbon_offset export --format csv

# Export to file
ruby bin/carbon_offset export --output my_carbon_data.json
```

## How It Works

### Carbon Calculation Formula

```
Total Carbon to Offset = Initial Entries + Recurring Monthly + Manual Additions
Remaining Carbon = Total Carbon - Sum(Trees Planted × CO2 Absorption)
Progress % = (Total Offset / Total Carbon) × 100
```

### Tree Selection Algorithm

The optimizer uses a two-phase approach:

1. **Diversity Phase (30% of budget)**
   - Ensures ecological diversity
   - Spreads budget across 2-3 tree types minimum
   - Prevents monoculture planting

2. **Efficiency Phase (70% of budget)**
   - Maximizes CO2 offset per dollar
   - Prioritizes highest-efficiency trees
   - Respects remaining budget constraints

### Projection Mathematics

- Monthly growth factor = (1 + annual_rate/100)^(1/12) - 1
- Applied monthly for smooth projections
- Recurring carbon grows/shrinks by carbon growth rate
- Budget increases according to budget growth rate

## Data Storage

By default, data is stored locally in the current directory at `./.carbon_data/carbon_config.json`. This directory is automatically excluded from version control via `.gitignore`.

### Storage Locations

You can configure where data is stored in three ways:

1. **Default (Local Directory)**
   ```bash
   # Data stored in ./.carbon_data/ in current working directory
   ruby bin/carbon_offset config
   ```

2. **Custom Directory**
   ```bash
   # Set a custom location
   ruby bin/carbon_offset config --data-dir ~/Documents/carbon_data
   
   # Or use a project-specific directory
   ruby bin/carbon_offset config --data-dir ./my_carbon_tracking
   ```

3. **Environment Variable**
   ```bash
   # Set globally via environment variable
   export CARBON_DATA_DIR=/path/to/carbon/data
   ruby bin/carbon_offset config
   ```

### Data File Structure

The main configuration file `carbon_config.json` contains:

```json
{
  "currency": "USD",
  "monthly_budget": 200,
  "tree_types": [
    {
      "name": "Oak",
      "co2_absorption": 500,
      "cost": 25,
      "efficiency": 20.0
    }
  ],
  "carbon_entries": [
    {
      "amount": 1000,
      "description": "Annual footprint",
      "date": "2024-01-01",
      "category": "manual"
    }
  ],
  "recurring_carbon": {
    "amount": 150,
    "start_date": "2024-01-01"
  },
  "plantings": [
    {
      "tree_type": "Oak",
      "quantity": 5,
      "date": "2024-06-15",
      "co2_offset": 2500,
      "cost": 125
    }
  ]
}
```

## Architecture

The application is organized into modular components:

```
carbon_offset/
├── bin/
│   └── carbon_offset           # Executable entry point
├── lib/
│   ├── carbon_offset.rb        # Main module
│   └── carbon_offset/
│       ├── models/             # Data models
│       │   ├── tree_type.rb    # Tree type model
│       │   ├── carbon_entry.rb # Carbon entry model
│       │   └── planting.rb     # Planting record model
│       ├── services/           # Business logic
│       │   ├── carbon_calculator.rb    # Carbon calculations
│       │   ├── planting_optimizer.rb   # Tree purchase optimization
│       │   └── projection_service.rb   # Future projections
│       ├── storage/            # Data persistence
│       │   └── json_storage.rb # JSON storage layer
│       ├── reports/            # Report generation
│       │   └── report_generator.rb # All report types
│       └── cli.rb              # Command-line interface
└── config/
    └── defaults.yml            # Default configuration
```

## Advanced Usage Examples

### Example 1: Activity-Based Personal Tracking

```bash
# Initial setup
ruby bin/carbon_offset config --budget 200 --currency USD

# Track activities (CO2 calculated automatically)
ruby bin/carbon_offset activity transport/car_petrol 500 "Monthly commute"
ruby bin/carbon_offset activity energy/electricity 250 "January power bill"
ruby bin/carbon_offset activity food/beef 4 "Weekly consumption"
ruby bin/carbon_offset activity shopping/clothing_item 3 "New wardrobe"
ruby bin/carbon_offset activity digital/streaming_4k 20 "Netflix this month"

# Add tree types
ruby bin/carbon_offset tree add "Oak" 500 25
ruby bin/carbon_offset tree add "Pine" 300 15
ruby bin/carbon_offset tree add "Maple" 400 20

# Generate and follow plan
ruby bin/carbon_offset plan 12
ruby bin/carbon_offset plant "Oak" 3

# Check progress
ruby bin/carbon_offset report --format summary
```

### Example 2: Household with Growth Projections

```bash
# Setup for family of 4
ruby bin/carbon_offset config --budget 300
ruby bin/carbon_offset carbon add 8000 "Annual household carbon"
ruby bin/carbon_offset carbon recurring 250

# Project with expected changes
ruby bin/carbon_offset project 5 --carbon-growth -5 --budget-growth 7
# (Planning to reduce emissions by 5% yearly, salary increasing 7%)

# Compare scenarios
ruby bin/carbon_offset scenarios
```

### Example 3: Optimization Comparison

```bash
# Compare different planting strategies
ruby bin/carbon_offset compare

# Try different modes
ruby bin/carbon_offset plan --mode cost_efficient  # Maximum efficiency
ruby bin/carbon_offset plan --mode max_diversity   # Maximum variety
ruby bin/carbon_offset plan --mode balanced        # Balanced approach
```

## Tips and Best Practices

1. **Start with Conservative Estimates**
   - Better to overestimate carbon footprint
   - Use lower estimates for tree survival rates
   - Account for inflation in costs

2. **Regular Updates**
   - Update carbon entries monthly
   - Record plantings as they happen
   - Adjust budget as needed

3. **Diversity Matters**
   - Don't optimize solely for cost
   - Mixed forests are more resilient
   - Consider local tree species

4. **Use Projections**
   - Model different scenarios
   - Plan for lifestyle changes
   - Account for economic factors

5. **Track Categories**
   - Use categories for better insights
   - Identify biggest emission sources
   - Focus reduction efforts

## Troubleshooting

**Q: The plan shows no trees to plant**
- Check that you've added tree types
- Verify your monthly budget is set
- Ensure budget exceeds cheapest tree cost

**Q: Projections show I'll never be carbon neutral**
- Try scenarios with higher budget growth
- Model carbon reduction (negative growth)
- Consider one-time budget increases

**Q: Data not persisting**
- Check write permissions for .carbon_data/ directory
- Verify JSON file isn't corrupted
- Use backup/restore if needed
- Ensure you're in the correct working directory (data is stored locally by default)

## Command Reference

| Command | Description |
|---------|-------------|
| `config` | Configure budget, currency, data directory (default: ./.carbon_data) |
| `tree add NAME CO2 COST` | Add tree type |
| `tree list` | List all tree types |
| `carbon add AMOUNT [DESC]` | Add carbon entry (direct CO2) |
| `carbon recurring AMOUNT` | Set monthly recurring carbon |
| `carbon list` | Show carbon entries details |
| `activity CAT/ACT QTY [DESC]` | Add activity (auto-calculated CO2) |
| `factors list [CATEGORY]` | List emission factors |
| `factors search KEYWORD` | Search emission factors |
| `factors add CAT ACT UNIT CO2` | Add custom emission factor |
| `factors categories` | List factor categories |
| `plant TREE QTY` | Record tree planting |
| `plan [MONTHS]` | Generate planting plan |
| `report` | Generate status report |
| `project [YEARS]` | Project future neutrality |
| `scenarios` | Run projection scenarios |
| `compare` | Compare optimization modes |
| `backup` | Create configuration backup |
| `restore FILE` | Restore from backup |
| `export` | Export data (JSON/CSV) |
| `example` | Load example data |
| `version` | Show version |

## Future Enhancements

Potential improvements for contributors:

- Web interface for easier data entry
- Integration with carbon calculator APIs
- Automatic import from utility bills
- Mobile app for tracking on-the-go
- Team/family shared accounts
- Gamification elements
- Regional tree recommendations
- Seasonal planting adjustments
- Tree survival rate tracking
- Carbon reduction suggestions

## Support

For issues or questions:
1. Check this documentation
2. Review the examples
3. Use `--help` flag with any command
4. Check the generated reports for insights

## License

This tool is provided as-is for personal and commercial use. Please verify carbon calculations with certified assessors and ensure tree-planting partners are legitimate and effective.

---

*Remember: The most effective carbon reduction is not producing it in the first place. Use this tool alongside efforts to reduce your carbon footprint through lifestyle changes.*