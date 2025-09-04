# Carbon Tracking and Offset Planning

A comprehensive Ruby tool for tracking your carbon footprint and planning quality carbon removal and tree-planting offsets with budget optimization and future projections.

## Overview

This tool helps individuals and organizations track their carbon emissions from daily activities and plan cost-effective tree-planting strategies to achieve carbon neutrality. It combines activity-based emission tracking with intelligent offset planning that balances cost efficiency with ecological diversity.

## Key Features

- **🌍 Activity-Based Tracking**: Track emissions from transport, energy, food, shopping, and more using built-in emission factors
- **🌳 Smart Tree Planning**: Optimize tree purchases across multiple species for biodiversity while maximizing CO2 offset per dollar
- **📊 Future Projections**: Model different scenarios to see when you'll achieve carbon neutrality
- **💰 Budget Management**: Set monthly budgets and get personalized planting plans
- **📈 Progress Tracking**: Monitor your offset journey with detailed reports and milestones
- **💾 Local Storage**: Data stored locally in your project directory, not in the cloud

## Quick Start

```bash
# Install dependencies
bundle install

# Load example data to explore
ruby bin/carbon_offset example

# Track some activities (CO2 calculated automatically)
ruby bin/carbon_offset activity transport/flight_short 1 "NYC trip"
ruby bin/carbon_offset activity energy/electricity 350 "Monthly bill"

# Generate a monthly planting plan
ruby bin/carbon_offset plan

# Check your progress
ruby bin/carbon_offset report
```

## How It Works

1. **Track Carbon**: Log activities (flights, driving, electricity use) or direct CO2 amounts
2. **Set Budget**: Define how much you can spend monthly on offsets
3. **Add Trees**: Configure available tree types with their CO2 absorption and costs
4. **Generate Plan**: Get an optimized monthly purchasing schedule
5. **Record Progress**: Log actual plantings and monitor your journey to carbon neutrality

## Why This Tool?

Most carbon calculators stop at telling you your footprint. This tool goes further by:

- **Automating the math** between activities and CO2 emissions
- **Optimizing your offset budget** for maximum impact
- **Ensuring biodiversity** by mixing tree species
- **Projecting realistic timelines** based on your lifestyle and budget
- **Tracking actual progress** vs. plans

## Installation

Requirements:
- Ruby 2.7+ 
- Bundler

```bash
git clone <repository>
cd carbon-offset
bundle install
```

## Documentation

For complete documentation including:
- Command reference
- Emission factors database
- Advanced usage examples
- API details

See [DOCUMENTATION.md](DOCUMENTATION.md)

## Data Privacy

Your carbon tracking data is stored locally in `.carbon_data/` (gitignored by default). No data is sent to external servers. You control where your data lives and can easily backup or move it.

## Contributing

This tool is designed to be extended. Potential enhancements:
- Additional emission factor databases
- Integration with carbon offset providers
- Web interface
- Mobile app
- Team/family sharing features

## License

This tool is provided as-is for personal and commercial use. Please verify all carbon calculations with certified assessors and ensure tree-planting partners are legitimate and effective.

---

*Remember: The most effective carbon reduction is not producing it in the first place. Use this tool alongside efforts to reduce your carbon footprint through lifestyle changes.*