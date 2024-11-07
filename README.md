# 👾 Chaotic Job

[![Gem Version](https://badge.fury.io/rb/chaotic_job.svg)](https://rubygems.org/gems/chaotic_job)
[![Gem Downloads](https://img.shields.io/gem/dt/chaotic_job)](https://rubygems.org/gems/chaotic_job)
![Tests](https://github.com/fractaledmind/chaotic_job/actions/workflows/main.yml/badge.svg)
![Coverage](https://img.shields.io/badge/code%20coverage-92%25-success)
[![Sponsors](https://img.shields.io/github/sponsors/fractaledmind?color=eb4aaa&logo=GitHub%20Sponsors)](https://github.com/sponsors/fractaledmind)
[![Twitter Follow](https://img.shields.io/twitter/url?label=%40fractaledmind&style=social&url=https%3A%2F%2Ftwitter.com%2Ffractaledmind)](https://twitter.com/fractaledmind)

> [!TIP]
> This gem helps you test that your Active Jobs are reliable and resilient to failures. If you want to more easily *build* reliable and resilient Active Jobs, check out the companion [Acidic Job](https://github.com/fractaledmind/acidic_job/tree/alpha-1.0) gem.

`ChaoticJob` provides a set of tools to help you test the reliability and resilience of your Active Jobs. It does this by allowing you to simulate various types of failures and glitches that can occur in a production environment.

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

In order to properly test job retries, you should use the `perform_all` method provided by `ChaoticJob::Helpers`:

```ruby
Job.perform_later
perform_all
```

This helper will perform the job and all of its retries in the proper way, in waves, just like it would in production.

If you need more control over which batches of jobs are performed, you can use the `perform_all_before` and `perform_all_after` methods. These are particularly useful if you need to test the behavior of a job that schedules another job. You can use these methods to perform only the original job and its retries, assert the state of the system, and then perform the scheduled job and its retries.

```ruby
JobThatSchedules.perform_later
perform_all_before(4.seconds)
assert_equal 1, enqueued_jobs.size
assert_equal 2, performed_jobs.size

perform_all_after(1.day)
assert_equal 0, enqueued_jobs.size
assert_equal 3, performed_jobs.size
```

You can pass either a `Time` object or an `ActiveSupport::Duration` object to these methods. And, to make the code as readable as possible, the `perform_all_before` is also aliased as the `perform_all_within` method. This allows you to write the example above as `perform_all_within(4.seconds)`.

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

  run_scenario(Job.new, glitch: ["before", "#{__FILE__}:6"])

  assert_equal 5, ChaoticJob::Journal.total
end
```

> [!NOTE]
> The `ChaoticJob::Journal` class is a simple class that you can use to log things happening. It is used here to track the behavior of the job. It's has a lean, but highly useful, interface:
> |method|description|
> |---|---|
> | `Journal.log` | log simply that something happened within the default scope |
> | `Journal.log(thing, scope: :special)` | log a particular value within a particular scope |
> | `Journal.total` | get the total number of logs under the default scope |
> | `Journal.total(scope: :special)` | get the total number of logs under a particular scope |
> | `Journal.all` | get all of the logged values under the default scope |
> | `Journal.all(scope: :special)` | get all of the logged values under a particular scope |

In this example, the job being tested is defined within the test case. You can, of course, also test jobs defined in your application. The key detail is the `glitch` keyword argument. A "glitch" is simply a tuple that describes precisely where you would like the failure to occur. The first element of the tuple is the location of the glitch, which can be either *before* or *after*. The second element is the location of the code that will be affected by the glitch, defined by its file path and line number. What this example scenario does is inject a glitch before the `step_3` method is called, here:

```ruby
def perform
  step_1
  step_2
  # <-- HERE
  step_3
end
```

This glitch is a transient error, which are the only kind of errors that matter when testing resilience, as permanent errors mean your job will simply end up in the dead set. So, the glitch failure will occur once and only once, this forces a retry but does not prevent the job from completing.

If you want to simulate multiple glitches affecting a job run, you can use the plural `glitches` keyword argument instead and pass an array of tuples:

```ruby
run_scenario(Job.new, glitches: [
  ["before", "#{__FILE__}:6"],
  ["before", "#{__FILE__}:7"]
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

In this example, the simulation will run 12 scenarios:

```ruby
[
  [[:after, "test_chaotic_job.rb:69"]],
  [[:before, "test_chaotic_job.rb:75"]],
  [[:after, "test_chaotic_job.rb:74"]],
  [[:before, "test_chaotic_job.rb:74"]],
  [[:after, "test_chaotic_job.rb:68"]],
  [[:after, "test_chaotic_job.rb:70"]],
  [[:before, "test_chaotic_job.rb:68"]],
  [[:after, "test_chaotic_job.rb:73"]],
  [[:after, "test_chaotic_job.rb:75"]],
  [[:before, "test_chaotic_job.rb:69"]],
  [[:before, "test_chaotic_job.rb:70"]],
  [[:before, "test_chaotic_job.rb:73"]]
]
```

It generates all possible glitch scenarios by performing your job once with a [`TracePoint`](https://docs.ruby-lang.org/en/master/TracePoint.html) that captures each line executed in your job. It then computes all possible glitch locations to produce a set of scenarios that will be run.[^1] The block that you pass to `run_simulation` will be called for each scenario, allowing you to make assertions about the behavior of your job under all scenarios.

[^1]: The logic to determine all possible glitch locations essentially produces two locations, before and after, for each executed line. It then dedupes the functionally equivalent locations of `[:after, "file:1"]` and `[:before, "file:2"]`.

In your application tests, you will want to make assertions about the side-effects that your job performs, asserting that they are correctly idempotent (only occur once) and result in the correct state.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fractaledmind/chaotic_job. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/fractaledmind/chaotic_job/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ChaoticJob project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fractaledmind/chaotic_job/blob/main/CODE_OF_CONDUCT.md).
