RSpec.describe Aggredator::Middleware::MetadataCopier do

  let(:in_meta) { (2 + rand(5)).times.map {[SecureRandom.hex] * 2}.to_h }
  let(:out_meta) { (2 + rand(5)).times.map {[SecureRandom.hex] * 2}.to_h } 

  it 'copy metadata from inner' do
    in_msg = OpenStruct.new payload: {'metadata' => in_meta}
    results = described_class.new(proc do |msg|
      [Aggredator::Dispatcher::Result.new('mq://out', Aggredator::Api::V1::Message.new({}, metadata: out_meta))]
    end).call in_msg

    expect(results).to be_a Array
    res_meta = results.first.message.payload[:metadata]
    expect(res_meta).to include(in_meta)
    expect(res_meta).to include(out_meta)
  end

end