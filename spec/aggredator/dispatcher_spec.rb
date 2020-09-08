RSpec.describe Aggredator::Dispatcher do

  let(:consumer) { MockConsumer.new }
  let(:incoming) { OpenStruct.new consumer: consumer, headers: {}, payload: {} }
  let(:observer) { ObserverMock.new }
  let(:result_message) {
    Aggredator::Dispatcher::Result.new(
      'amqp://example.com',
      Aggredator::Api::V1::Message.new({}, {})
    )
  }
  let(:answer_message) {
    Aggredator::Dispatcher::Result.new(
      "amqp://#{Aggredator::Dispatcher::ANSWER_DOMAIN}@example.com",
      Aggredator::Api::V1::Message.new({}, {})
    )
  }
  let(:publisher) { MockPublisher.new }
  subject { described_class.new observer }

  class MockConsumer

    attr_reader :acked, :nacked

    def initialize
      @acked = []
      @nacked = []
    end

    def ack incoming, answer: nil
      @acked << {incoming: incoming, answer: answer}
    end

    def nack incoming
      @nacked << incoming
    end

  end

  class MockPublisher

    attr_reader :futures

    def initialize
      @futures = []
    end

    def protocols
      ["amqp"]
    end
  
    def publish result
      f = Concurrent::Promises.resolvable_future
      futures << f
      f
    end
  
  end

  it 'ctor' do
    instance = described_class.new observer
    expect(instance.observer).to eq observer
    expect(instance.logger).to be_a Logger
    expect(instance.publishers).to be_empty
    expect(instance.consumers).to be_empty
    expect(instance.middlewares).to be_empty
  end

  {
    'register consumer' => [:register_consumer, :consumers],
    'register publisher' => [:register_publisher, :publishers],
    'register middleware' => [:register_middleware, :middlewares],
  }.each do |name, (method_name, prop_name)|
    it name do
      value = SecureRandom.hex
      expect {
        subject.send(method_name, value)
      }.to change{subject.send(prop_name).size}.from(0).to(1)
    end
  end

  it 'process message' do
    expect(subject.instance_variable_get('@stream')).to be_nil
    thread = Thread.new do
      subject.run
    end
    sleep 0.1
    stream = subject.instance_variable_get('@stream')
    expect(stream).not_to be_nil
    message = Aggredator::Api::V1::Message.new({}, {})
    expect(subject).to receive(:process).with(message)
    stream << message
    sleep 0.1
    subject.close
    sleep 0.1
    expect(thread).not_to be_alive
  end

  context 'process' do
  
    it 'success processing' do
      results = [Aggredator::Dispatcher::Result.new("http://example.com", Aggredator::Api::V1::Message.new({}, {}))]
      processor = Proc.new do |message|
        expect(incoming).to eq message
        results
      end
      expect(subject).to receive(:build_processing_stack).and_return(processor)
      expect(subject).to receive(:send_results).with(incoming, results)
      subject.send(:process, incoming)
    end

    it 'reject message' do
      error = RuntimeError.new SecureRandom.hex
      expect(subject).to receive(:build_processing_stack).and_raise(error)
      expect(consumer).to receive(:reject).with(incoming)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.exception', msg: incoming, exception: error)
      subject.send(:process, incoming)
    end

  end

  context '#find_processor' do
  
    it 'find processor factory' do
      factory = Aggredator::Factory.new String
      expect(factory).to receive(:create).and_call_original
      expect(observer).to receive(:match).and_return([{}, factory])
      _, processor = subject.send(:find_processor, incoming)
      expect(processor).to eq String.new
    end

    it 'find callable processor' do
      matched, processor = subject.send(:find_processor, incoming)
      expect(matched).to be_a Hash
      expect(processor).to respond_to(:call)
    end

  end

  context '#build_processing_stack' do
  
    it 'empty middlewares' do
      expect(subject.middlewares).to be_empty
      stack = subject.send(:build_processing_stack)
      expect(stack).to respond_to(:call)
      expect(subject).to receive(:process_message).with(incoming)
      stack.call(incoming)
    end

    it 'callable middleware' do

      middleware = Class.new(Aggredator::Middleware::Base) do

        MARKER = SecureRandom.uuid

        def self.marker
          MARKER
        end

        def call(in_msg)
          results = app.call(in_msg)
          results << MARKER
          results
        end
      end

      expect_any_instance_of(middleware).to receive(:call).and_call_original
      subject.register_middleware middleware
      stack = subject.send(:build_processing_stack)
      expect(stack).to respond_to(:call)
      results = stack.call(incoming)
      expect(results).not_to be_empty
      expect(results.last).to eq middleware.marker
    end

    it 'callable factory' do
    
      middleware_factory = Class.new do
        attr_reader :value, :app, :in_msg
        def initialize value
          @value = value
        end

        def build app
          @app = app
          self
        end

        def call(in_msg)
          @in_msg = in_msg
          results = app.call(in_msg)
          results << @value
          results
        end

      end

      marker = SecureRandom.hex
      factory = middleware_factory.new(marker)
      subject.register_middleware factory
      expect(factory).to receive(:build).and_call_original
      stack = subject.send(:build_processing_stack)
      expect(stack).to respond_to(:call)
      results = stack.call incoming
      expect(results).to be_a Array
      expect(results.last).to eq marker
    end

  end


  context '#process_message' do

    it 'success processing message' do
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.request.process', hash_including(msg: incoming))
      results = subject.send(:process_message, incoming)
      expect(results).to be_a Array
    end

    it 'processor have on_error method' do
      mock_processor = Class.new do
        attr_reader :message, :e, :marker

        def on_error(message, e)
          @message = message
          @e = e
          @marker = SecureRandom.hex
          [@marker]
        end
      end
      error = RuntimeError.new SecureRandom.hex
      processor = mock_processor.new
      expect(subject).to receive(:find_processor).and_return([{}, processor])
      expect(ActiveSupport::Notifications).to receive(:instrument).and_raise(error)
      expect {
        @results = subject.send(:process_message, incoming)
      }.not_to raise_error
      expect(@results).to be_a Array
      expect(@results).to eq [processor.marker]
      expect(processor.e).to eq error
      expect(processor.message).to eq incoming
    end
  

    it 'raise error' do
      error = RuntimeError.new SecureRandom.hex
      expect(ActiveSupport::Notifications).to receive(:instrument).and_raise(error)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.request.exception', hash_including(msg: incoming, exception: error))
      expect{
        subject.send(:process_message, incoming)
      }.to raise_error(error)
    end

  end

  context '#publish_result' do

    it 'not found publisher' do
      expect {
        subject.send(:publish_result, result_message)
      }.to raise_error(/Not found publisher/)
    end

    it 'success publish' do
      subject.register_publisher publisher
      expect {
        subject.send(:publish_result, result_message)
      }.not_to raise_error
    end

  end

  context '#send_results' do

    before(:each) {
      subject.register_publisher publisher
    }

    it 'success send results' do
      results = ([result_message] * 5) << answer_message
      expect(consumer).to receive(:ack).with(incoming, answer: answer_message)
      subject.send(:send_results, incoming, results)
      futures = publisher.futures
      expect(futures.size).to eq 6
      futures.each(&:resolve)
      sleep 0.1
    end

    it 'failed publishing' do
      results = [result_message] * 2
      error = SecureRandom.hex
      expect(consumer).to receive(:nack).with(incoming)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.request.result_rejected', hash_including(message: error.inspect))
      subject.send(:send_results, incoming, results)
      futures = publisher.futures
      expect(futures.size).to eq 2
      futures.first.resolve
      futures.last.reject error
      sleep 0.1
    end

    it 'failed processing rejected message' do
      error = RuntimeError.new SecureRandom.hex
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.request.result_rejected', any_args)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.exception', hash_including(msg: incoming, exception: error))
      expect(subject).to receive(:sleep).with(10)
      expect(subject).to receive(:exit!).with(1)
      subject.send(:send_results, incoming, [result_message])

      expect(consumer).to receive(:nack).and_raise(error)
      future = publisher.futures.first
      future.reject "test"
      sleep 0.1
    end

  end

end