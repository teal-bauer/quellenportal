require 'test_helper'
require 'benchmark'

class BundesarchivImporterBenchmark < ActiveSupport::TestCase
  # Run benchmarks in sequence:
  parallelize(workers: 1, threshold: 1)

  def test_reduced_dataset
    assert_equal 0, Record.count

    time =
      Benchmark.measure do
        BundesarchivImporter.new('test/fixtures/files/dataset-2-percent').run
      end

    Record.delete_all

    puts "Reduced dataset import: #{time}"
    puts "Predicted time for full dataset: #{format('%.d', time.real * 50 / 60)} minutes"
    pass("Reduced dataset import: #{time}")
  end
end
