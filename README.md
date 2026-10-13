# Cattle Disease & Milk Quality System

A collaborative research project for cattle disease support and raw milk quality pre-screening.

## Repository structure

```text
.
├── mobile/       # Flutter MedFarm application
├── backend/      # Python FastAPI service
├── ml/           # Model code, preprocessing, and evaluation
├── docs/         # Architecture, API contracts, and research notes
├── .gitignore
└── README.md
```

## Development setup

Each major component should keep its own setup instructions:

- `mobile/README.md`: Flutter SDK, dependencies, run and test commands.
- `backend/README.md`: Python version, virtual environment, dependencies, environment variables, and run commands.
- `ml/README.md`: model artifacts, datasets, training, and evaluation instructions.

## Team workflow

- `main`: stable integration branch. Do not commit directly.
- `develop`: shared integration branch for completed work.
- Feature branches: use names like `feature/backend-api`, `feature/flutter-ui`, `feature/milk-quality-simulator`, or `feature/disease-model`.
- Open pull requests into `develop`; request at least one teammate review before merging.
- Merge `develop` into `main` only for a tested milestone or release.

## Security and data

- Never commit API keys, database URLs, passwords, `.env` files, or private credentials.
- Commit `.env.example` with placeholder values only.
- Do not commit private, personally identifiable, or unapproved research data.
- Do not commit large model weights or raw datasets unless the team has agreed on a storage method.

## Current status

Repository scaffolding and implementation are in progress. Sensor values used by a simulator must be labelled as simulated and must not be reported as real-world validated measurements.