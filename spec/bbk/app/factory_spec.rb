RSpec.describe BBK::App::Factory do
  class Test

    RESULT_VALUE = SecureRandom.hex

    attr_reader :args

    def initialize(*args, **_kwargs)
      @args = args
    end

    def call(*_args)
      RESULT_VALUE
    end

  end

  subject { described_class.new Test, *instance_args }

  let(:instance_args) { Random.rand(2..6).times.map { SecureRandom.hex }  }
  let(:method_params) { Random.rand(2..6).times.map { SecureRandom.hex }  }


  it 'create' do
    item = subject.create
    expect(item).not_to be_nil
    expect(item).to be_a subject.klass
    expect(item).to be_a Test
    expect(item.args).to eq instance_args
    expect(item).not_to eq subject.create
  end

  it 'call' do
    expect_any_instance_of(Test).to receive(:call).with(*method_params, any_args).and_call_original
    result = subject.call(*method_params)
    expect(result).to eq Test::RESULT_VALUE
  end
end

