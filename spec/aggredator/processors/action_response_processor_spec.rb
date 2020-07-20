RSpec.describe Aggredator::Processors::ActionResponseProcessor do

  it 'rule' do
    rule = described_class.rule
    expect(rule).to be_a Array
    expect(rule.size).to eq 2
    expect(rule.first).to eq :meta
    expect(rule.last).to eq Aggredator::Api::V1::ActionResponse.meta_match_rule
  end

end