RSpec.describe Aggredator::App::ThreadPool do
  subject(:pool) { described_class.new(size, queue: queue) }
  let(:size) { 2 }
  let(:queue) { 5 }

  it 'simple execution' do
    result = []
    10.times do |i|
      pool.post(i) do |value|
        result.push(value)
      end
    end
    pool.shutdown
    expect(pool.wait_for_termination(1)).to eq(true)

    expect(result.size).to eq(10)
  end

  context 'wait to complete' do
    it 'success wait for all task to complete' do
      result = []
      10.times do |i|
        pool.post(i) do |value|
          sleep 0.2
          result.push(value)
        end
      end
      pool.shutdown
      expect(pool.wait_for_termination(1)).to eq(true)

      expect(result.size).to eq(10)
    end

    it 'failure wait' do
      result = []
      10.times do |i|
        pool.post(i) do |value|
          sleep 0.2
          result.push(value)
        end
      end
      pool.shutdown
      # not all jobs able to complete
      expect(pool.wait_for_termination(0.5)).to eq(false)
      expect(result.size).not_to eq(10)

      # ALL jobs able to complete NOW
      expect(pool.wait_for_termination(1)).to eq(true)
      expect(result.size).to eq(10)
    end
  end

  context 'kill threads' do
    it 'not all jobse able to process but threads are completed' do
      result = []
      10.times do |i|
        pool.post(i) do |value|
          sleep 0.2
          result.push(value)
        end
      end
      expect(pool.kill).to eq(true)
      expect(result.size).not_to eq(10)
    end

    it 'failure wait' do
      result = []
      10.times do |i|
        pool.post(i) do |value|
          sleep 2
          result.push(value)
        end
      end
      pool.shutdown
      expect(pool.kill).to eq(false)
      expect(result.size).not_to eq(10)
    end
  end
end
