## [Unreleased]

## [0.9.1] - 2025-06-12

- The simulation tracer should only capture events on the template job [#14](https://github.com/fractaledmind/chaotic_job/pull/14)

## [0.9.0] - 2025-06-12

- Make journal logging idempotent and add `push` for non-idempotent logging [#12](https://github.com/fractaledmind/chaotic_job/pull/12)
- A simulation callstack capture needs to perform child jobs as well [#13](https://github.com/fractaledmind/chaotic_job/pull/13)

## [0.8.1] - 2025-06-12

- Add pretty `to_s` methods for Scenario and Glitch [#11](https://github.com/fractaledmind/chaotic_job/pull/11)

## [0.8.0] - 2025-06-11

- Add methods to allow checking if a Scenario matches a particular Glitch key + event pair [#10](https://github.com/fractaledmind/chaotic_job/pull/10)

## [0.7.0] - 2025-06-09

- Glitch only works with singular event + key definition [#6](https://github.com/fractaledmind/chaotic_job/pull/6)
- Scenarios assert the glitch was executed [#7](https://github.com/fractaledmind/chaotic_job/pull/7)
- Add helper methods to create a Glitch of the various kinds [#8](https://github.com/fractaledmind/chaotic_job/pull/8)
- Improve test coverage [#9](https://github.com/fractaledmind/chaotic_job/pull/9)

## [0.6.0] - 2025-06-08

- `run_scenario` requires a Glitch instance [#5](https://github.com/fractaledmind/chaotic_job/pull/5)

## [0.5.0] - 2025-06-04

- Add a Tracer class [#3](https://github.com/fractaledmind/chaotic_job/pull/3)

## [0.4.0] - 2025-05-27

- Allow a Glitch to be defined for a method call or method return [#4](https://github.com/fractaledmind/chaotic_job/pull/4)

## [0.3.0] - 2024-12-17

- Ensure that assertion failure messages raised within a simulation contain the scenario description
- Add a `ChaoticJob.journal_entries` top-level method

## [0.2.0] - 2024-11-06

- Update the `perform_all` helper method to `perform_all_jobs`
- Update the `perform_all_before` helper method to `perform_all_jobs_before`
- Update the `perform_all_after` helper method to `perform_all_jobs_after`
- Update the `perform_all_within` helper method to `perform_all_jobs_within`

## [0.1.1] - 2024-11-06

- Update `Journal` interface
- Add top-level `ChaoticJob` methods to work with the journal
- Fix bug with job sorting in the `Performer`
- Fix bug with resolving time cutoffs in the `Performer`
- Fix bug with using the `run_scenario` helper with a block

## [0.1.0] - 2024-11-06

- Added `Journal` to log activity for tests
- Added `Performer` to correctly perform jobs with retries
- Added `Glitch` to inject transient failures into code execution
- Added `Scenario` to define a glitch for a specific job
- Added `Simulation` to run all possible error scenarios for a job
- Added `Helpers` module to provide easy to use methods for testing

## [0.0.1] - 2024-11-06

- Initial release
