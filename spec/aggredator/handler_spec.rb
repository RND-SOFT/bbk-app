RSpec.describe Aggredator::Handler do
  let(:default) { proc { |*args| args } }
  let(:match_rule) { [:meta, { headers: { type: 'test' } }] }

  subject { described_class.new }

  it 'with default block' do
    subj = described_class.new(&default)
    expect(subj.instance_variable_get('@default')).to eq default
  end

  it 'with default lambda' do
    subj = described_class.new
    default_lambda = subj.instance_variable_get('@default')
    expect(default_lambda).not_to be_nil
    expect(default_lambda).to respond_to(:call)
  end

  context 'register' do
    let(:processor) { Aggredator::Processors::PingProcessor }
    let(:block_rule) { [:meta, {}] }
    let(:block) { proc {} }

    it 'register processor' do
      handlers = subject.instance_variable_get('@handlers')
      expect do
        subject.register processor
      end.to change { handlers.size }.from(0).to(1)
      key, value = handlers.first

      expect(key).to be_a Aggredator::BaseMatcher

      expect(value).to be_a Aggredator::Factory
      expect(value.klass).to eq processor
    end

    it 'double register processor' do
      handlers = subject.instance_variable_get('@handlers')
      expect do
        subject.register processor
        subject.register processor
      end.to change { handlers.size }.from(0).to(1)
      key, value = handlers.first

      expect(key).to be_a Aggredator::BaseMatcher

      expect(value).to be_a Aggredator::Factory
      expect(value.klass).to eq processor
    end

    it 'register block' do
      handlers = subject.instance_variable_get('@handlers')
      expect do
        subject.register(*block_rule, &block)
      end.to change { handlers.size }.from(0).to(1)
      key, value = handlers.first
      expect(key).to be_a Aggredator::HeadersMatcher
      expect(value).to eq block
    end

    it 'invalid rule' do
      expect do
        subject.register 42
      end.to raise_error(RuntimeError, /type and rule or method/)
    end

    it 'invalid callable' do
      expect do
        subject.register(*block_rule, 42)
      end.to raise_error(RuntimeError, /callable object or class missing/)
    end
  end

  it 'default setter' do
    v = proc {}
    subject.default(&v)
    expect(subject.instance_variable_get('@default')).to eq v
  end

  it 'match rule' do
    subject.register(*match_rule, default)
    result = subject.match match_rule.last, {}, {}
    expect(result).to be_a Array
    expect(result.first).to eq match_rule.last.deep_stringify_keys
    expect(result.last).to eq default
  end
end
