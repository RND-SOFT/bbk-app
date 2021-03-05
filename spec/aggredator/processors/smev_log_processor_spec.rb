RSpec.describe Aggredator::Processors::SmevLogRequest do
  let(:smev_service_name) { SecureRandom.hex }
  let(:service_name) { SecureRandom.hex }

  subject { described_class.new ServiceRequest, smev_service_name, service_name }

  it 'check rule' do
    rule = described_class.rule
    expect(rule).to be_a Array
    expect(rule.size).to eq 2
    expect(rule.first).to eq :meta
    expect(rule.last).to eq Aggredator::Api::V1::Actions::ExchangeLogRequest.meta_match_rule
  end

  it 'check action' do
    expect(described_class.action).to eq Aggredator::Api::V1::Actions::ExchangeLogRequest.action
  end

  context 'ctor' do
    it 'success' do
      subj = described_class.new ServiceRequest, smev_service_name, service_name
      expect(subj.model_class).to eq ServiceRequest
      expect(subj.smev_service_name).to eq smev_service_name
    end

    it 'invalid model type' do
      expect { described_class.new Hash, smev_service_name, service_name }.to raise_error(TypeError)
    end
  end

  context 'process message' do
    let(:request) do
      ServiceRequest.create(
        ticket_id: SecureRandom.uuid,
        consumer: SecureRandom.hex,
        reply_to: SecureRandom.hex
      )
    end
    let(:reply_to) { SecureRandom.hex }

    let(:headers) do
      {
        message_id: SecureRandom.uuid,
        reply_to: reply_to,
        user_id: SecureRandom.hex,
        ticket: request.ticket_id,
        consumer: SecureRandom.hex
      }
    end

    let(:message) do
      Aggredator::Dispatcher::Message.new OpenStruct.new, { headers: headers }, '{}'
    end

    it 'success process message' do
      results = []
      subject.process message, results: results
      expect(results.size).to eq 1
      result = results.first
      expect(result).to be_a Aggredator::Dispatcher::Result
      route = result.route
      expect(route.to_s).to eq "mq://inner@service.#{smev_service_name}.request"
      message = result.message
      expect(message).to be_a Aggredator::Api::V1::Actions::ExchangeLogRequest
      expect(message.headers[:ticket]).to eq request.ticket_id
    end

    it 'not found ticket' do
      expect(subject).to receive(:make_error_answer).and_call_original
      results = []
      headers[:ticket] = SecureRandom.hex
      subject.process message, results: results
      expect(results.size).to eq 1
      result = results.first
      expect(result).to be_a Aggredator::Dispatcher::Result
      route = result.route
      expect(route.to_s).to eq "mq://outer@#{message.reply_to}"
      res_msg = result.message
      expect(res_msg).to be_a Aggredator::Api::V1::Responses::ExchangeLogResponse
      headers = res_msg.headers
      expect(headers[:ticket]).to eq message.headers[:ticket]
      expect(headers[:correlation_id]).to eq message.message_id
      expect(headers[:service]).to eq service_name

      payload = res_msg.payload
      expect(payload[:success]).to eq false
    end
  end
end
