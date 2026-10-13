# MedFarm: Cattle Disease Detection and Milk Quality Analysis System

Research group **J26-IT-413**.

MedFarm is a collaborative four-component research project intended to support cattle health inquiry and raw milk quality pre-screening.

## Shared foundation

The project uses:

- **Mobile application:** Flutter and Dart
- **Backend/API:** Python and FastAPI
- **Integration:** versioned REST APIs with documented request and response contracts

Component-specific models, libraries, databases, and feature implementations will be added on their own feature branches after the group agrees on shared integration requirements. This repository README intentionally stays at the project level.

## Repository workflow

- `main`: stable base and releases. Do not commit directly during normal feature development.
- `dev`: shared integration branch.
- Each member creates a feature branch from `dev` when they begin their assigned implementation.
- Integrate changes into `dev` through reviewed pull requests. Promote tested milestones to `main`.

## Security

Never commit secrets, database credentials, private participant information, raw consented recordings, or restricted research datasets. Use ignored local environment files and approved data storage.

## Status

The shared repository is being established incrementally. Component code and database choices are not defined by this README and should not be assumed until agreed by the group.
