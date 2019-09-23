RSpec.describe Aggredator::Processors::Action do

  subject { described_class.new }

  it 'static action' do
    expect { described_class.action }.to raise_error(RuntimeError, /not implemented/)
  end

  it 'member action' do
    expect(described_class).to receive(:action).and_call_original
    expect { subject.action }.to raise_error(RuntimeError, /not implemented/)
  end

end