# frozen_string_literal: true

RSpec.describe Aggredator::Processors::ExchangeLogsProcessor do
  let(:service_name) { SecureRandom.hex }

  subject { described_class.new service_name }

  it 'check rule' do
    expect(described_class.rule).to match([:meta, Aggredator::Api::Actions::ExchangeLogRequest.meta_match_rule])
  end

  it 'check action' do
    expect(described_class.action).to eq Aggredator::Api::Actions::ExchangeLogRequest.action
  end

  context 'process message' do
    let(:reply_to) { SecureRandom.hex }
    let(:ticket) { SecureRandom.hex }

    let(:headers) do
      {
        message_id: SecureRandom.uuid,
        reply_to: reply_to,
        user_id: SecureRandom.hex,
        ticket: ticket,
        consumer: SecureRandom.hex
      }
    end

    let(:message) do
      Aggredator::Dispatcher::Message.new OpenStruct.new, { headers: headers }, '{}'
    end

    let(:results) { [] }
    let(:process) { subject.process message, results: results }

    it 'success process message' do
      expect { process }.to change { results.count }.from(0).to(1)
      result = results.first

      expect(result).to be_a Aggredator::Dispatcher::Result
      expect(result.route.to_s).to eq "mq://inner@service.#{service_name}.request"

      expect(result.message).to be_a Aggredator::Api::Actions::ExchangeLogRequest
      expect(result.message.headers[:ticket]).to eq ticket
      expect(result.message.headers[:reply_to]).to eq reply_to
    end
  end
end
