# 👾 Chaotic Job

[![Gem Version](https://badge.fury.io/rb/chaotic_job.svg)](https://rubygems.org/gems/chaotic_job)
[![Gem Downloads](https://img.shields.io/gem/dt/chaotic_job)](https://rubygems.org/gems/chaotic_job)
![Tests](https://github.com/fractaledmind/chaotic_job/actions/workflows/main.yml/badge.svg)
![Coverage](https://img.shields.io/badge/code%20coverage-92%25-success)
[![Sponsors](https://img.shields.io/github/sponsors/fractaledmind?color=eb4aaa&logo=GitHub%20Sponsors)](https://github.com/sponsors/fractaledmind)
[![Twitter Follow](https://img.shields.io/twitter/url?label=%40fractaledmind&style=social&url=https%3A%2F%2Ftwitter.com%2Ffractaledmind)](https://twitter.com/fractaledmind)

> [!TIP]
> This gem helps you test that your Active Jobs are reliable and resilient to failures. If you want to more easily *build* reliable and resilient Active Jobs, check out the companion [Acidic Job](https://github.com/fractaledmind/acidic_job/tree/alpha-1.0) gem.

`ChaoticJob` provides a set of tools to help you test the reliability and resilience of your Active Jobs. It does this by allowing you to simulate various types of failures and glitches that can occur in a production environment, inspired by the principles of [chaos testing](https://principlesofchaos.org) and [deterministic simulation testing](https://blog.resonatehq.io/deterministic-simulation-testing)

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add chaotic_job
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install chaotic_job
```

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

The `ChaoticJob::Helpers` module provides 6 methods, 4 of which simply allow you to perform a job with retries in the proper way while the other 2 allow you to simulate failures and glitches.

### Glitches

A central concept in `ChaoticJob` is the _glitch_. A glitch is an error injected into the job execution flow via a [`TracePoint`](https://docs.ruby-lang.org/en/master/TracePoint.html). Glitches are transient errors, which means they occur _once_ and **only once**, making them perfect for testing a job's resilience to unpredictable failures that can occur while running jobs, like network issues, upstream API outages, rate limits, or  infrastructure failure. By default, `ChaoticJob` raises a custom error defined by the gem (`ChaoticJob::RetryableError`), which the internals of the gem ensure that the job under test is configured to retry on; you can, however, raise specific errors as needed when setting up your [scenarios](#simulating-failures). By forcing a retry via the error handling mechanisms of Active Job, glitches are a simple but effective way to test that your job is resilient to any kind of transient error that the job is configured to retry on.

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

The helper methods for correctly performing jobs and their retries are useful, but they are not the primary reason for using `ChaoticJob`. The real power of this gem comes from its ability to simulate failures and glitches.

The first helper you can use is the `run_scenario` method. A scenario is simply a set of glitches that will be injected into the specified code once. Here is an example:

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

  run_scenario(Job.new, glitch: [:before_call, "Job#step_3"])

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

In this example, the job being tested is defined within the test case. You can, of course, also test jobs defined in your application. The key detail is the `glitch` keyword argument. A "glitch" is simply a tuple that describes precisely where you would like the failure to occur. The first element of the tuple is the _kind_ of glitch, which can be either `:before_line`, `:before_call`, or `:before_return`. These refer to the three kinds of `TracePoint` events that the gem hooks into. The second element is the _key_ for the code that will be affected by the glitch. This _key_ is a specially formatted string that defines the specific bit of code that the glitch should be inserted before. The different kinds of glitches are identified by different kinds of keys:
|kind|key format|key example|
|---|---|---|
|`:before_line`|`"#{file_path}:#{line_number}"`|`"/Users/you/path/to/file.rb:123"`|
|`:before_call`|`"#{YourClass.name}(.|#)#{method_name}"`|`"YourClass.some_class_method"`|
|`:before_return`|`"#{YourClass.name}(.|#)#{method_name}"`|`"YourClass#some_instance_method"`|

As you can see, the `:before_call` and `:before_return` keys are formatted the same, and can identify any instance (`#`) or class (`.`) method.

What the example scenario above does is inject a glitch before the `step_3` method is called, here:

```ruby
def perform
  step_1
  step_2
  # <-- HERE
  step_3
end
```

If we wanted to inject a glitch right before the `step_3` method finishes, we could define the glitch as a `:before_return`, like this:

```ruby
run_scenario(Job.new, glitch: [:before_return, "Job#step_3"])
```

and it would inject the transient error right here:

```ruby
def step_3
  ChaoticJob::Journal.log
  # <-- HERE
end
```

Finally, if you need to inject a glitch right before a particular line of code is executed that is neither a method call nor a method return, you can use the `:before_line` key, like this:

```ruby
run_scenario(Job.new, glitch: [:before_line, "#{__FILE__}:6"])
```

If you want to simulate multiple glitches affecting a job run, you can use the plural `glitches` keyword argument instead and pass an array of tuples:

```ruby
run_scenario(Job.new, glitches: [
  [:before_call, "Job#step_1"],
  [:before_return, "Job#step_1"]
])
```

Scenario testing is useful to test the behavior of a job under a specific set of conditions. But, if you want to test the behavior of a job under a variety of conditions, you can use the `run_simulation` method. Instead of running a single scenario, a simulation will run the full set of possible error scenarios for your job.

```ruby
test "simulation of a simple job" do
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

  run_simulation(Job.new) do |scenario|
    assert_operator ChaoticJob::Journal.total, :>=, 3
  end
end
```

More specifically, it will create a scenario injecting a glitch before every line of code executed in your job. So, in this example, the simulation will run 12 scenarios:

```ruby
[
  [[:before_line, "test_chaotic_job.rb:69"]],
  [[:before_line, "test_chaotic_job.rb:75"]],
  [[:before_line, "test_chaotic_job.rb:74"]],
  [[:before_line, "test_chaotic_job.rb:74"]],
  [[:before_line, "test_chaotic_job.rb:68"]],
  [[:before_line, "test_chaotic_job.rb:70"]],
  [[:before_line, "test_chaotic_job.rb:68"]],
  [[:before_line, "test_chaotic_job.rb:73"]],
  [[:before_line, "test_chaotic_job.rb:75"]],
  [[:before_line, "test_chaotic_job.rb:69"]],
  [[:before_line, "test_chaotic_job.rb:70"]],
  [[:before_line, "test_chaotic_job.rb:73"]]
]
```

It generates all possible glitch scenarios by performing your job once with a [`TracePoint`](https://docs.ruby-lang.org/en/master/TracePoint.html) that captures each line executed in your job. It then computes all possible glitch locations to produce a set of scenarios that will be run. The block that you pass to `run_simulation` will be called for each scenario, allowing you to make assertions about the behavior of your job under all scenarios.

If you want to have the simulation run against a larger collection of scenarios, you can capture a custom callstack using the `ChaoticJob::Tracer` class and pass it to the `run_simulation` method as the `callstack` parameter. A `Tracer` is initialized with a block that determines which `TracePoint` events to collect. You then call `capture` with a block that defines the code to be traced. The default `Simulation` tracer collects all events for the passed job and then traces the job execution, essentially like this:

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fractaledmind/chaotic_job. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fractaledmind/chaotic_job/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ChaoticJob project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fractaledmind/chaotic_job/blob/main/CODE_OF_CONDUCT.md).
