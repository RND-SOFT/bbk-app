RSpec.describe Aggredator::Processors::PongProcessor do
  subject { described_class.new }

  it 'check action' do
    expect(described_class.action).to eq 'pong'
  end

  it 'rule' do
    rule = described_class.rule
    expect(rule).to be_a Array
    expect(rule.size).to eq 2
    expect(rule.first).to eq :meta
    expect(rule.last).to eq Aggredator::Api::V1::Pong.meta_match_rule
  end
end
