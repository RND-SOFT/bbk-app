require 'bbk/app/spec'

RSpec.describe BBK::App::Spec do
  subject { described_class }

  it { is_expected.to be_a(Module) }
end

