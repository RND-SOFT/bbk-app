RSpec.describe Aggredator::Executor::Default do

  let(:message) { SecureRandom.hex }
  subject { described_class.new }

  it 'call' do
    expect(subject.call(message){|x| x}).to eq message
  end

end