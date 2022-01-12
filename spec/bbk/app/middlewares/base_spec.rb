RSpec.describe BBK::App::Middlewares::Base do
  subject { described_class.new nil }

  it 'call raise exception' do
    expect { subject.call(SecureRandom.hex) }.to raise_error(RuntimeError)
  end
end

