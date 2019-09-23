RSpec.describe Aggredator::Executor::Base do

  subject { described_class.new }

  it 'call raise exception' do
    expect { subject.call(SecureRandom.hex) }.to raise_error(RuntimeError)
  end

end
