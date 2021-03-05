RSpec.describe Aggredator::Processors::ActionProcessor do
  let(:io) { StringIO.new }
  let(:output) { io.string }
  let(:logger) { ::Logger.new(io) }
  subject { described_class.new logger: logger }

  it 'check rule' do
    rule = described_class.rule
    expect(rule).to be_a Array
    expect(rule.size).to eq 2
    expect(rule.first).to eq :meta
    expect(rule.last).to eq Aggredator::Api::V1::ActionRequest.meta_match_rule
  end

  context 'register' do
    let(:args) { Random.rand(2..6).times.map { SecureRandom.hex } }
    let(:proc_obj) { proc {} }
    let(:action) { SecureRandom.hex }
    let(:processor) { Aggredator::Processors::PingProcessor }

    it 'register processor with action method' do
      subject.register processor, *args
      actions = subject.instance_variable_get('@actions')
      expect(actions.size).to eq 1
      expect(actions).to have_key processor.action
      callable = actions.values.first
      expect(callable).to be_a Aggredator::Factory
      expect(callable.klass).to eq processor
      expect(callable.instanceargs).to eq args
    end

    it 'register processor with block param' do
      subject.register processor, *args, &proc_obj
      actions = subject.instance_variable_get('@actions')
      callable = actions.values.first
      expect(callable.instanceargs).to eq args + [proc_obj]
    end

    xit 'register action processor twice' do
      # now we can register processor twice with override semantic
      subject.register processor
      expect { subject.register processor }.to raise_error(RuntimeError, /already registered/)
    end

    it 'register with explicit action' do
      subject.register action, processor
      actions = subject.instance_variable_get('@actions')
      expect(actions).to have_key action
      callable = actions[action]
      expect(callable.klass).to eq processor
    end

    it 'invalid action name or not exist action method' do
      expect { subject.register nil, processor }.to raise_error(RuntimeError, /action name or method/)
    end

    it 'register block' do
      subject.register action, proc_obj
      actions = subject.instance_variable_get('@actions')
      expect(actions[action]).to eq proc_obj
    end

    it 'register not callable object' do
      expect { subject.register action, nil }.to raise_error(RuntimeError, /callable object or class missing/)
    end

    it 'double action registration' do
      subject.register action, proc_obj
      expect do
        subject.register action, proc_obj
      end.not_to raise_error
      expect(output).to match(/Action with same name already registered/)
    end
  end

  context 'process message' do
    let(:delivery_info) { OpenStruct.new }
    let(:body) { JSON.generate({}) }
    let(:processor_cls) { Aggredator::Processors::PingProcessor }
    let(:properties) do
      properties = Aggredator::Api::V1::Ping.meta_match_rule
      properties[:headers].merge!(
        message_id: SecureRandom.uuid,
        reply_to: SecureRandom.hex,
        user_id: SecureRandom.uuid,
        action: processor_cls.action,
        type: Aggredator::Api::V1::ActionRequest.type
      )
      properties
    end

    let(:message) do
      Aggredator::Dispatcher::Message.new delivery_info, properties, body
    end

    before(:each) do
      subject.register processor_cls
      @handler = subject.instance_variable_get('@actions').values.first
    end

    it 'call processor' do
      results = []
      expect(ActiveSupport::Notifications).to receive(:instrument).with('action_processor.action',
                                                                        action: processor_cls.action, headers: message.headers).and_call_original
      expect(@handler).to receive(:call).with(message, results: results)
      subject.process message, results: results
    end

    it 'not found processor for action' do
      results = []
      new_action = message.headers[:action] = SecureRandom.hex
      expect(ActiveSupport::Notifications).to receive(:instrument).with('action_processor.action_missing',
                                                                        action: new_action, headers: message.headers)
      expect(@handler).not_to receive(:call)
      expect(subject).to receive(:make_error_answer).and_call_original
      subject.process message, results: results
      # Проверяем наличия сообщения об ошибке
      expect(results).not_to be_empty
      msg = results.first
      expect(msg).to be_a Aggredator::Dispatcher::Result
      expect(msg.route.uri.to_s).to eq "mq://outer@#{message.reply_to}"
      expect(msg.message).to be_a Aggredator::Api::V1::Error
    end

    it 'catch error' do
      subject.instance_variable_set('@actions', nil)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('action_processor.exception',
                                                                        hash_including(
                                                                          action: message.headers[:action], headers: message.headers
                                                                        ))
      results = []
      subject.process message, results: results
      expect(results).not_to be_empty
      msg = results.first
      expect(msg).to be_a Aggredator::Dispatcher::Result
      expect(msg.route.uri.to_s).to eq "mq://outer@#{message.reply_to}"
      expect(msg.message).to be_a Aggredator::Api::V1::Error
    end
  end
end
