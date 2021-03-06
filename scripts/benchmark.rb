#!/usr/bin/env ruby

require 'bundler/setup'
require 'benchmark'
require 'securerandom'
require 'bbk/app'
require 'net/http'
require 'active_support/core_ext'

Thread.abort_on_exception = true
BBK::App.logger.level = :info

$str = SecureRandom.hex * 10

def cpu
  100.times do
    $str[SecureRandom.hex]
  end
end

def io
  # Net::HTTP.get_response(URI('http://y12313a.r1231231u')) rescue nil
  sleep 0.1
end

class Consumer

  attr_reader :count, :acks, :nacks

  def initialize(count)
    @count = count
    @acks = 0
    @nacks = 0
  end

  def on_finish(&block)
    @on_finish = block
  end

  def on_ack(&block)
    @on_ack = block
  end

  def run(stream)
    Thread.new(stream) do |s|
      result = @count.times do |i|
        s << BBK::App::Dispatcher::Message.new(self, {}, {}, i)
      end
      @on_finish.call(result)
    end
  end

  def close; end

  def stop(*args); end

  def ack(incoming, answer: nil)
    @acks += 1
    @on_ack.call(incoming)
  end

  def nack(_incoming, error: nil)
    @nacks += 1
  end

end

def run(count, pool_factory:, stream_strategy:, pool: 0, operation: :cpu)
  dispatcher = BBK::App::Dispatcher.new(BBK::App::Handler.new, pool_size: pool, pool_factory: pool_factory,
                                                                   stream_strategy: stream_strategy)
  c = Consumer.new(count).tap do |c|
    c.on_finish do
      dispatcher.close(21)
    end
    c.on_ack do
      send(operation)
    end
    dispatcher.register_consumer(c)
  end
  dispatcher.run
  raise 'Somethong wrong' if c.acks != count
  # puts "ack:#{c.acks}"
end

CPU_COUNT = 100_000
IO_COUNT = 200

[BBK::App::SimplePoolFactory, BBK::App::ConcurrentPoolFactory].each do |pool_factory|
  puts "\n == Benchmark Dispatcher with pool_factory: #{pool_factory}"
  [BBK::App::Dispatcher::QueueStreamStrategy,
   BBK::App::Dispatcher::DirectStreamStrategy].each do |stream_strategy|
    puts "\n   ** Benchmark Dispatcher with stream_strategy: #{stream_strategy}"

    Benchmark.bm(55) do |x|
      x.report("CPU with #{stream_strategy.to_s.demodulize} pool[#{pool_factory.to_s.demodulize}] 1") do
        run(CPU_COUNT, pool: 1, operation: :cpu, pool_factory: pool_factory,
stream_strategy: stream_strategy)
      end
      x.report("CPU with #{stream_strategy.to_s.demodulize} pool[#{pool_factory.to_s.demodulize}] 3") do
        run(CPU_COUNT, pool: 3, operation: :cpu, pool_factory: pool_factory,
stream_strategy: stream_strategy)
      end
      x.report("CPU with #{stream_strategy.to_s.demodulize} pool[#{pool_factory.to_s.demodulize}] 5") do
        run(CPU_COUNT, pool: 5, operation: :cpu, pool_factory: pool_factory,
stream_strategy: stream_strategy)
      end
    end

    Benchmark.bm(55) do |x|
      x.report("IO with #{stream_strategy.to_s.demodulize} pool[#{pool_factory.to_s.demodulize}] 1") do
        run(IO_COUNT, pool: 1, operation: :io, pool_factory: pool_factory,
stream_strategy: stream_strategy)
      end
      x.report("IO with #{stream_strategy.to_s.demodulize} pool[#{pool_factory.to_s.demodulize}] 3") do
        run(IO_COUNT, pool: 3, operation: :io, pool_factory: pool_factory,
stream_strategy: stream_strategy)
      end
      x.report("IO with #{stream_strategy.to_s.demodulize} pool[#{pool_factory.to_s.demodulize}] 5") do
        run(IO_COUNT, pool: 5, operation: :io, pool_factory: pool_factory,
stream_strategy: stream_strategy)
      end
    end
  end
end

