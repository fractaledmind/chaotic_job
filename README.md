# 👾 Chaotic Job

[![Gem Version](https://badge.fury.io/rb/chaotic_job.svg)](https://rubygems.org/gems/chaotic_job)
[![Gem Downloads](https://img.shields.io/gem/dt/chaotic_job)](https://rubygems.org/gems/chaotic_job)
![Tests](https://github.com/fractaledmind/chaotic_job/actions/workflows/main.yml/badge.svg)
![Coverage](https://img.shields.io/badge/code%20coverage-98%25-success)
[![Sponsors](https://img.shields.io/github/sponsors/fractaledmind?color=eb4aaa&logo=GitHub%20Sponsors)](https://github.com/sponsors/fractaledmind)
[![Twitter Follow](https://img.shields.io/twitter/url?label=%40fractaledmind&style=social&url=https%3A%2F%2Ftwitter.com%2Ffractaledmind)](https://twitter.com/fractaledmind)

> [!TIP]
> This gem helps you test that your Active Jobs are reliable and resilient to failures. If you want to more easily *build* reliable and resilient Active Jobs, check out the companion [Acidic Job](https://github.com/fractaledmind/acidic_job) gem.

`ChaoticJob` provides a set of tools to help you test the reliability and resilience of your Active Jobs. It does this by allowing you to simulate various types of failures, glitches, and races that can occur in a production environment, inspired by the principles of [chaos testing](https://principlesofchaos.org) and [deterministic simulation testing](https://blog.resonatehq.io/deterministic-simulation-testing)

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add chaotic_job
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install chaotic_job
```

## Concepts

### Glitches

A central concept in `ChaoticJob` is the _glitch_. A glitch is an error injected into the job execution flow via a [`TracePoint`](https://docs.ruby-lang.org/en/master/TracePoint.html). Glitches are transient errors, which means they occur _once_ and **only once**, making them perfect for testing a job's resilience to unpredictable failures that can occur while running jobs, like network issues, upstream API outages, rate limits, or  infrastructure failure. By default, `ChaoticJob` raises a custom error defined by the gem (`ChaoticJob::RetryableError`), which the internals of the gem ensure that the job under test is configured to retry on; you can, however, raise specific errors as needed when setting up your [scenarios](#simulating-failures). By forcing a retry via the error handling mechanisms of Active Job, glitches are a simple but effective way to test that your job is resilient to any kind of transient error that the job is configured to retry on.

### Scenarios

Glitches allows `ChaoticJob` to test specific failure _scenarios_. A scenario is a mutation of a single job's traced callstack defined by where you stop and restart (e.g. [e1, e2, e1, e2, e3]), because a glitch occurs at a certain moment in the callstack. So, a scenario is defined by a particular job and a particular glitch. A simulation computes the set of all possible Scenarios and runs each one, checking them with the passed assertions.

### Races

Another central concept in `ChaoticJob` is the _race_. A race is a mutation of multiple jobs' traced callstacks defined by how you interleave the ordered sets into a single ordered set (e.g. [a1, a2, b1, a3, b2, b3] or [b1, a1, a2, b2, a3, b3]). A race is defined by a particular set of jobs and a particular schedule of linear execution events. The linear sequence schedule must be an exhaustive set of ordered execution events. `ChaoticJob` performs those jobs concurrently, ensuring that the pattern of events is executed in order. This simulates a race condition, which is typically a bug that occurs when two linear sequence of execution events get interleaved in such a way as to produce an unexpected effect. By having an executor that can force multiple concurrent execution streams to follow a fixed pattern, we can test particular race condition scenarios deterministically.

> [!INFO]
> A [`Scenario`](https://github.com/fractaledmind/chaotic_job/blob/main/lib/chaotic_job/scenario.rb) is to [`Simulation`](https://github.com/fractaledmind/chaotic_job/blob/main/lib/chaotic_job/simulation.rb) as a [`Race`](https://github.com/fractaledmind/chaotic_job/blob/main/lib/chaotic_job/race.rb) is to a [`Relay`](https://github.com/fractaledmind/chaotic_job/blob/main/lib/chaotic_job/relay.rb).

## Usage

`ChaoticJob` should be used primarily by including its helpers into your Active Job tests:

```ruby
class TestYourJob < ActiveJob::TestCase
  include ChaoticJob::Helpers

  test "job is reliable" do
    # ...
  end
end
```

The `ChaoticJob::Helpers` module provides 7 methods, 3 of which simply allow you to perform a job with retries in the proper way while the other 4 allow you to simulate failures, glitches, and races. The module works with both Minitest and RSpec. Altogether, it provides a suite of tools to allow you to simply and deterministically test the primary surface areas for bugs in the eventually consistent, concurrent environment that is background jobs.

### Performing Jobs

When testing job resilience, you will necessarily be testing how a job behaves when it retries. Unfortunately, the helpers provided by `ActiveJob::TestHelper` are tailored to testing the job's behavior on the first attempt.

Specifically, when you want to perform a job and all of its retries, you would naturally reach for the [`perform_enqueued_jobs`](https://api.rubyonrails.org/classes/ActiveJob/TestHelper.html#method-i-perform_enqueued_jobs) method.

> [!WARNING]
> Do not use `perform_enqueued_jobs` to test job retries.

```ruby
perform_enqueued_jobs do
  Job.perform_later
end
```

But, this method does not behave as you would expect. Functionally, it overwrites the `enqueue` method to immediately perform the job, which means that instead of your job being performed in waves, the retry is performed _within_ the execution of the original job. This both confuses the logs and means the behavior in your tests are not representative of the behavior in production.

In order to properly test job retries, you should use the `perform_all_jobs` method provided by `ChaoticJob::Helpers`:

```ruby
Job.perform_later
perform_all_jobs
```

This helper will perform the job and all of its retries in the proper way, in waves, just like it would in production.

If you need more control over which batches of jobs are performed, you can use the `perform_all_jobs_before` and `perform_all_jobs_after` methods. These are particularly useful if you need to test the behavior of a job that schedules another job. You can use these methods to perform only the original job and its retries, assert the state of the system, and then perform the scheduled job and its retries.

```ruby
JobThatSchedules.perform_later
perform_all_jobs_before(4.seconds)
assert_equal 1, enqueued_jobs.size
assert_equal 2, performed_jobs.size

perform_all_jobs_after(1.day)
assert_equal 0, enqueued_jobs.size
assert_equal 3, performed_jobs.size
```

You can pass either a `Time` object or an `ActiveSupport::Duration` object to these methods. And, to make the code as readable as possible, the `perform_all_jobs_before` is also aliased as the `perform_all_jobs_within` method. This allows you to write the example above as `perform_all_jobs_within(4.seconds)`.

### Simulating Failures

#### Failure Scenarios

The helper methods for correctly performing jobs and their retries are useful, but they are not the primary reason for using `ChaoticJob`. The real power of this gem comes from its ability to simulate failures and glitches.

The first helper you can use is the `run_scenario` method. A scenario is simply a particular glitch that will be injected into the specified code once. Here is an example:

```ruby
test "scenario of a simple job" do
  class Job < ActiveJob::Base
    def perform
      step_1
      step_2
      step_3
    end

    def step_1; ChaoticJob::Journal.log; end
    def step_2; ChaoticJob::Journal.log; end
    def step_3; ChaoticJob::Journal.log; end
  end

  run_scenario(Job.new, glitch: glitch_before_call("Job#step_3"))

  assert_equal 5, ChaoticJob::Journal.total
end
```

> [!NOTE]
> The `ChaoticJob::Journal` class is a simple class that you can use to log things happening. It is used here to track the behavior of the job. It's has a lean, but highly useful, interface:
> |method|description|
> |---|---|
> | `Journal.log` | log simply that something happened within the default scope |
> | `Journal.log(thing, scope: :special)` | log a particular value within a particular scope |
> | `Journal.size` | get the total number of logs under the default scope |
> | `Journal.size(scope: :special)` | get the total number of logs under a particular scope |
> | `Journal.entries` | get all of the logged values under the default scope |
> | `Journal.entries(scope: :special)` | get all of the logged values under a particular scope |

In this example, the job being tested is defined within the test case. You can, of course, also test jobs defined in your application. The key detail is the `glitch` keyword argument.

A "glitch" is describes precisely where you would like the failure to occur. The description is composed first of the _kind_ of glitch, which can be either `before_line`, `before_call`, or `before_return`. These refer to the three kinds of `TracePoint` events that the gem hooks into. The second element is the _key_ for the code that will be affected by the glitch. This _key_ is a specially formatted string that defines the specific bit of code that the glitch should be inserted before. The different kinds of glitches are identified by different kinds of keys:
|kind|key format|key example|
|---|---|---|
|`before_line`|`"#{file_path}:#{line_number}"`|`"/Users/you/path/to/file.rb:123"`|
|`before_call`|`"#{YourClass.name}(.|#)#{method_name}"`|`"YourClass.some_class_method"`|
|`before_return`|`"#{YourClass.name}(.|#)#{method_name}"`|`"YourClass#some_instance_method"`|

As you can see, the `before_call` and `before_return` keys are formatted the same, and can identify any instance (`#`) or class (`.`) method.

What the example scenario above does is inject a glitch before the `step_3` method is called, here:

```ruby
def perform
  step_1
  step_2
  # <-- HERE
  step_3
end
```

If we wanted to inject a glitch right before the `step_3` method finishes, we could define the glitch as a `before_return`, like this:

```ruby
run_scenario(Job.new, glitch: glitch_before_return("Job#step_3"))
```

and it would inject the transient error right here:

```ruby
def step_3
  ChaoticJob::Journal.log
  # <-- HERE
end
```

Finally, if you need to inject a glitch right before a particular line of code is executed that is neither a method call nor a method return, you can use the `before_line` key, like this:

```ruby
run_scenario(Job.new, glitch: glitch_before_line("#{__FILE__}:6"))
```

#### Exhaustive Failure Simulations

Scenario testing is useful to test the behavior of a job under a specific set of conditions. But, if you want to test the behavior of a job under a variety of conditions, you can use the `test_simulation` method. Instead of running a single scenario, a simulation will define a full set of possible error scenarios for your job as individual test cases.

```ruby
class TestYourJob < ActiveJob::TestCase
  include ChaoticJob::Helpers

  class Job < ActiveJob::Base
    def perform
      step_1
      step_2
      step_3
    end

    def step_1 = ChaoticJob::Journal.log
    def step_2 = ChaoticJob::Journal.log
    def step_3 = ChaoticJob::Journal.log
  end

  # will dynamically generate a test method for each failure scenario
  test_simulation(Job.new) do |scenario|
    assert_operator ChaoticJob::Journal.total, :>=, 3
  end
end
```

More specifically, it will create a scenario injecting a glitch before every line of code executed in your job. So, in this example, the simulation will run 12 scenarios:

```ruby
#<Set:
 {[:call, "Job#perform"],
  [:line, "file.rb:3"],
  [:call, "Job#step_1"],
  [:return, "Job#step_1"],
  [:line, "file.rb:4"],
  [:call, "Job#step_2"],
  [:return, "Job#step_2"],
  [:line, "file.rb:5"],
  [:call, "Job#step_3"],
  [:return, "Job#step_3"],
  [:return, "Job#perform"]}>
```

It generates all possible glitch scenarios by performing your job once with a [`TracePoint`](https://docs.ruby-lang.org/en/master/TracePoint.html) that captures every event executed as a part of your job running. The block that you pass to `test_simulation` will be called for each scenario, allowing you to make assertions about the behavior of your job under all scenarios.

If you want to have the simulation run against a larger collection of scenarios, you can capture a custom callstack using the `ChaoticJob::Tracer` class and pass it to the `test_simulation` method as the `callstack` parameter. A `Tracer` is initialized with a block that determines which `TracePoint` events to collect. You then call `capture` with a block that defines the code to be traced. The default `Simulation` tracer collects all events for the passed job and then traces the job execution, essentially like this:

```ruby
job_file_path = YourJob.instance_method(:perform).source_location&.first
tracer = Tracer.new { |tp| tp.path == job_file_path || tp.defined_class == YourJob }
tracer.capture { YourJob.perform_now }
```

To capture, for example, a custom callstack that includes all events within your application, you can use the `ChaoticJob::Tracer` class as follows:

```ruby
tracer = ChaoticJob::Tracer.new { |tp| tp.path.start_with?(Rails.root.to_s) }
tracer.capture { YourJob.perform_now }
```

If you passed this callstack to your simulation, it would test what happens to your job whenever a transient glitch is injected anywhere in your application code called as a part of executing the job under test.

Remember, in your application tests, you will want to make assertions about the side-effects that your job performs, asserting that they are correctly idempotent (only occur once) and result in the correct state.

### Simulating Races

#### Race Conditions

In addition to simulating transient failures, `ChaoticJob` can help you simulate and test race conditions that may occur between your jobs.

Much like the `run_scenario` method, you can use the `run_race` method to orchestrate and run a particular race condition. Here is an example:

```ruby
test "race between two simple jobs" do
  class Job1 < ActiveJob::Base
    def perform
      step_1
      step_2
      step_3
    end

    def step_1; ChaoticJob::Journal.push(1.1); end
    def step_2; ChaoticJob::Journal.push(1.2); end
    def step_3; ChaoticJob::Journal.push(1.3); end
  end

  class Job2 < ActiveJob::Base
    def perform
      step_1
      step_2
      step_3
    end

    def step_1; ChaoticJob::Journal.push(2.1); end
    def step_2; ChaoticJob::Journal.push(2.2); end
    def step_3; ChaoticJob::Journal.push(2.3); end
  end

  job1 = Job1.new
  job2 = Job2.new

  job1_callstack = trace(job1)
  job2_callstack = trace(job2)

  schedule = job1_callstack.to_a.zip(job2_callstack.to_a).flatten(1)

  ChaoticJob::Journal.reset!

  race = run_race([job1, job2], schedule: schedule)

  assert_equal [1.1, 2.1, 1.2, 2.2, 1.3, 2.3], ChaoticJob.journal_entries
  assert race.success?
  assert_equal schedule, race.executions
end
```

By zipping together the two job's callstacks, we created an _ordered_ and _exhaustive_ execution schedule that defines a particular race condition. By passing our jobs and that execution pattern to the `run_race` method, we are able to deterministically execute that exact linear sequence of concurrent execution events, thus mimicing a real race condition in production.

The `run_race` helper works with any collection of job instances and an _ordered_ and _exhaustive_ execution schedule. As demonstrated in the example above, the best way to produce such a `schedule` is to `trace` the callstack for each job in the collection and then interleave those callstacks in the desired manner. By using the `trace` helper, you can ensure that you produce an ordered and exhaustive callstack that is likewise minimally large (`ChaoticJob` only traces the `call`, `line`, and `return` events from Ruby's `TracePoint`).

As the example also shows, the `ChaoticJob::Race` instance returned from the `run_race` helper provides two public readers for use in assertions. The `#success?` boolean communicates whether the actual execution flow perfectly matched the passed `schedule` (in the example, the two assertions are thus redundant). The `#executions` reader returns the ordered array of actual execution events, allowing you to see how `ChaoticJob` actually executed your concurrent jobs' events.

#### Exhaustive Race Simulations

Just as with failure scenarios, the full power of `ChaoticJob` is unlocked when you use the gem to explore the full space of possible race conditions to ensure you have exhaustively resilient jobs. The `test_races` macro method produces a distinct test for each of the possible race conditions possible for the passed collection of jobs.

```ruby
class TestYourJob < ActiveJob::TestCase
  include ChaoticJob::Helpers

  class Job1 < ActiveJob::Base
    def perform
      step_1
      step_2
      step_3
    end

    def step_1; ChaoticJob::Journal.push(1.1); end
    def step_2; ChaoticJob::Journal.push(1.2); end
    def step_3; ChaoticJob::Journal.push(1.3); end
  end

  class Job2 < ActiveJob::Base
    def perform
      step_1
      step_2
      step_3
    end

    def step_1; ChaoticJob::Journal.push(2.1); end
    def step_2; ChaoticJob::Journal.push(2.2); end
    def step_3; ChaoticJob::Journal.push(2.3); end
  end

  # will dynamically generate a test method for each failure scenario
  test_races(Job1.new, Job2.new) do |scenario|
    assert_equal 6, ChaoticJob.journal_size
    assert race.success?
    assert_equal schedule, race.executions
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fractaledmind/chaotic_job. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fractaledmind/chaotic_job/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ChaoticJob project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fractaledmind/chaotic_job/blob/main/CODE_OF_CONDUCT.md).
