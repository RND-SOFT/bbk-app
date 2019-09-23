RSpec.describe Aggredator::Dispatcher::Message do

  let(:delivery_info) {
    OpenStruct.new(
      routing_code: SecureRandom.hex,
      delivery_tag: SecureRandom.hex,
      redelivered?: [true, false].sample
    )
  }

  let(:properties) {
    {
      headers: {
        user_id: SecureRandom.hex,
        reply_to: SecureRandom.hex,
        message_id: SecureRandom.uuid
      }
    }
  }

  let(:body){
    JSON.generate Hash[(2 + Random.rand(5)).times.map {[SecureRandom.hex, SecureRandom.hex]}]
  }

  subject { described_class.new(delivery_info, properties, body) }

  context 'ctor' do
  
    it 'success initialize' do
      subj = described_class.new delivery_info, properties, body
      expect(subj.delivery_info).to eq delivery_info
      expect(subj.properties).to eq properties.with_indifferent_access
      expect(subj.body).to eq body
      expect(subj.payload).to eq JSON.parse(body)
    end

    it 'message without headers' do
      headers = properties.delete :headers
      properties.merge! headers
      expect(properties[:headers]).to be_nil
      subj = described_class.new delivery_info, properties, body
      expect(subj.delivery_info).to eq delivery_info
      expect(subj.properties).to include(properties.with_indifferent_access)
      expect(subj.properties[:headers]).to eq({})
      expect(subj.body).to eq body
      expect(subj.payload).to eq JSON.parse(body)
    end

    it 'properties is not hash' do
      expect{ described_class.new(delivery_info, 1, body) }.to raise_error(Aggredator::Dispatcher::UndeliverableError, /must be a Hash/)
    end

    it 'body not json' do
      subj = described_class.new delivery_info, properties, SecureRandom.hex
      expect(subj.payload).to eq({})
    end

  end

  it 'id getter' do
    expect(subject.id).to eq properties.dig(:headers, :message_id)
  end

  context 'reply to getter' do
    
    it 'return properties reply_to' do
      value = subject.properties[:reply_to] = SecureRandom.hex
      expect(subject.reply_to).to eq value
    end

    it 'return headers reply_to' do
      expect(subject.properties[:reply_to]).to be_nil
      expect(subject.reply_to).to eq subject.headers[:reply_to]
    end

    it 'return user_id' do
      subject.properties.clear
      subject.properties[:headers] = {}
      expect(subject.reply_to).to eq subject.user_id
    end

  end

  it 'delivery_tag getter' do
    expect(subject.delivery_tag).to eq delivery_info.delivery_tag
  end

  it 'redelivered' do
    expect(subject.redelivered?).to eq delivery_info.redelivered?
  end

  it 'cast to hash' do
    h = subject.to_h
    expect(h).to be_a Hash
    expect(h[:properties]).to eq subject.properties
    expect(h[:body]).to eq subject.body
  end

  it 'throw exception on diff value field in props and header' do
    properties[:user_id] = SecureRandom.uuid
    expect { described_class.new delivery_info, properties, body }.to raise_error(RuntimeError, /Diffrent user_id/)
  end

end