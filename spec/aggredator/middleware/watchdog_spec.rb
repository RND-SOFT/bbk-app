RSpec.describe Aggredator::Middleware::Watchdog do

  let(:dispatcher) { Aggredator::Dispatcher.new ObserverMock.new }
  let(:publisher) { PublisherMock.new }
  let(:reply_to) { SecureRandom.hex }

  subject { described_class.new publisher, "example.com", reply_to }

  class PublisherMock
    attr_accessor :msg_stream

    def publish result
      # emulate publish message
      consumer = OpenStruct.new ack: Proc.new{}
      message = OpenStruct.new consumer: consumer, headers: result.message.headers, payload: {}
      msg_stream << message unless msg_stream.nil?
    end

  end

  it 'success work' do
    dispatcher.register_middleware subject
    timestamp = subject.instance_variable_get('@timestamp')
    Thread.new do
      dispatcher.run
    end
    sleep 0.1
    stream = dispatcher.instance_variable_get('@stream')
    publisher.msg_stream = stream
    sleep 1
    subject.start
    sleep 0.1
    new_timesamp = subject.instance_variable_get('@timestamp')
    expect(new_timesamp).not_to eq timestamp
    expect(new_timesamp).to be > timestamp
    expect(subject.pinger_thread.name).to eq 'WatchDog::Pinger'
    expect(subject.watcher_thread.name).to eq 'WatchDog::Watcher'
    dispatcher.close
    subject.stop
  end

  it 'failed' do
    expect(STDERR).to receive(:puts)
    expect(subject).to receive(:exit!).with(8)
    subject.instance_variable_set('@timeout', 3) # wait 3 second
    subject.instance_variable_set('@watcher_delay', 1)
    subject.start
    sleep 5
    subject.stop
  end

end
