require 'bunny-mock'

RSpec.describe Aggredator::Dispatcher do
  let(:session){ BunnyMock.new.start }
  let(:channel){ session.channel }
  let(:main){ channel.exchange('main') }
  let(:queue){ channel.queue('testqueue') }
  let(:ex2){ channel.exchange('ex2') }
  let(:client){ Aggredator::Client.new(main, 'client1') }
  let(:domains) do
    {
      gw:    channel.header('gw', passive: true),
      inner: client.exchange,
      outer: client.default_exchange
    }.with_indifferent_access
  end
  let(:observer) { ObserverMock.new }
  let(:dispatcher){ described_class.new(queue, client, observer, domains) }
  let(:incmsg1) do
    msg_id = SecureRandom.hex(6)
    Aggredator::Dispatcher::Message.new(
      OpenStruct.new(delivery_tag: 11),
      OpenStruct.new(headers: { user_id: 'test_user', message_id: msg_id }, user_id: 'test_user', message_id: msg_id),
      { value: SecureRandom.hex(6) }.to_json
    )
  end
  let(:result1) do
    Aggredator::Dispatcher::Result.new(
      "mq://outer@#{incmsg1.reply_to}",
      Aggredator::Api::V1::Pong.new({ correlation_id: incmsg1.message_id }, JSON.load(incmsg1.body))
    )
  end
  let(:result1_dup) do
    Aggredator::Dispatcher::Result.new(
      "mq://outer@#{incmsg1.reply_to}",
      Aggredator::Api::V1::Pong.new({ correlation_id: incmsg1.message_id }, JSON.load(incmsg1.body))
    )
  end
  let(:mqmsg){ { delivery_info: incmsg1.delivery_info, properties: incmsg1.properties, body: incmsg1.body } }

  describe 'dispatcher instance' do
    subject{ dispatcher }

    it { is_expected.to be_a(Aggredator::Dispatcher) }

    %w[before after].each do |type|
      it "##{type} success" do
        expect do
          subject.send(type.to_sym, Aggredator::Dispatcher::Transformer.new)
        end.to change { subject.send("#{type}_transformers".to_sym).count }.by(1)
      end

      it "##{type} error" do
        expect do
          subject.send(type.to_sym, ->{})
        end.to raise_error(TypeError)
      end
    end

    it '#publish' do
      expect(client).to receive(:publish).with(result1.route.routing_key, result1.message, exchange: client.default_exchange, opts: result1.properties)
      dispatcher.publish(result1)
    end

    it '#run' do
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.request', hash_including(queue: queue)).and_call_original
      expect(subject).to receive(:process_request)
      subject.run block: false
      queue.publish({})
    end

    def with_stoptest
      stopresult = catch :stoptest do
        yield
      end

      expect(stopresult).to eq :stopped
    end

    it '#process_incomming_message' do
      observer.set_result(result1)
      results = dispatcher.send(:process_incomming_message, mqmsg, incmsg1)
      expect(observer.msg).to eq(incmsg1)
      expect(results.count).to eq(1)
      expect(results.first).to eq(result1)
    end

    it '#send_results' do
      expect(result1.properties[:message_id]).to eq nil
      expect(dispatcher).to receive(:publish).with(result1).and_call_original
      expect(client.default_exchange).to receive(:publish) do |payload, opts|
        expect(payload).to eq result1.message.body
        expect(opts).to include(message_id: result1.properties[:message_id], routing_key: 'test_user', user_id: client.name)
        expect(opts[:headers]).to include(correlation_id: incmsg1.message_id)
      end

      promise = dispatcher.send(:send_results, mqmsg, incmsg1, [result1])

      expect(promise).to be_a(Concurrent::Promises::Future)
      expect(result1.properties[:message_id]).not_to eq nil
    end

    it '#send_results without message_id will generate same message_id' do
      expect(dispatcher).to receive(:send_results).twice.and_wrap_original do |original, mq, msg, results|
        expect(results.first.properties[:message_id]).to eq(nil)
        original.call(mq, msg, results)
      end

      expect(client.default_exchange).to receive(:publish).twice do |_payload, opts|
        expect(opts[:message_id]).not_to eq nil
      end

      expect(result1.properties[:message_id]).to be_nil
      expect(result1_dup.properties[:message_id]).to be_nil

      dispatcher.send(:send_results, mqmsg, incmsg1, [result1])

      dispatcher.send(:send_results, mqmsg, incmsg1, [result1_dup])

      expect(result1.properties[:message_id]).not_to be_nil
      expect(result1_dup.properties[:message_id]).not_to be_nil

      expect(result1_dup.properties[:message_id]).to eq(result1.properties[:message_id])
    end

    it '#error process request' do
      tag = SecureRandom.hex
      message = {delivery_info: OpenStruct.new(delivery_tag: tag)}
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.exception', hash_including(msg: message))
      expect(client).to receive(:reject).with(tag)
      subject.process_request message
    end

    it '#publish without exchange' do
      result = Aggredator::Dispatcher::Result.new("mq://#{SecureRandom.hex}@service.smev.request", {})
      expect { subject.publish result }.to raise_error(ArgumentError, /no exchange for domain/)
    end

    it '#ack message on success send_results' do
      result = Aggredator::Dispatcher::Result.new("mq://#{domains.keys.sample}@service.smev.request", Aggredator::Api::V1::Message.new({}))
      expect(client).to receive(:ack).with(incmsg1.delivery_tag)
      mqmsg = {}
      subject.send(:send_results, mqmsg, incmsg1, [result])
      ack_id = client.ack_map.keys.first
      client.send(:on_confirm, ack_id, nil, false)
      sleep 1
    end

    it '#reject message on return' do
      mqmsg = {}  
      result = Aggredator::Dispatcher::Result.new("mq://#{domains.keys.sample}@service.smev.request", Aggredator::Api::V1::Message.new({}))
      expect(client).not_to receive(:ack).with(incmsg1.delivery_tag)
      expect(client).to receive(:reject).with(incmsg1.delivery_tag)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.request.result_rejected', hash_including(msg: mqmsg))
      subject.send(:send_results, mqmsg, incmsg1, [result])
      message_id = client.ack_map.values.first
      client.send(:on_return, client.exchange, nil, {message_id: message_id}, '{}')
      sleep 1
    end

    it '#achtung on message reject' do
      result = Aggredator::Dispatcher::Result.new("mq://#{domains.keys.sample}@service.smev.request", Aggredator::Api::V1::Message.new({}))
      mqmsg = {}
      allow(client).to receive(:reject).and_raise(StandardError)
      expect(STDERR).to receive(:puts).with(/\[CRITICAL\]/)
      expect(subject).to receive(:exit!).with(1)
      expect(ActiveSupport::Notifications).to receive(:instrument)
      expect(ActiveSupport::Notifications).to receive(:instrument).with('dispatcher.exception', hash_including(msg: mqmsg))

      subject.send(:send_results, mqmsg, incmsg1, [result])
      message_id = client.ack_map.values.first
      client.send(:on_return, client.exchange, nil, {message_id: message_id}, '{}')
      sleep 12
    end

    it '#set executor' do
      executor = Aggredator::Executor::Default.new
      expect {
        dispatcher.executor = executor
      }.to change {executor.dispatcher}.to(dispatcher)
      expect(dispatcher.executor).to eq executor
    end

    describe '#process_request' do
      class MockTransformer < Aggredator::Dispatcher::Transformer

        def transform(msg, *_args)
          msg
        end

      end

      let(:tr){ MockTransformer.new }
      let(:out_tr) { MockTransformer.new }

      before do
        expect(tr).to receive(:transform).and_return(incmsg1)
        dispatcher.before(tr)
        dispatcher.after(out_tr)
      end

      it '#transform_incomming' do
        expect(dispatcher).to receive(:transform_incomming).and_wrap_original do |original, msg|
          expect(msg).to be_a(Aggredator::Dispatcher::Message)
          expect(msg.message_id).to eq incmsg1.message_id
          original.call(msg)
          throw :stoptest, :stopped
        end

        with_stoptest do
          dispatcher.process_request(mqmsg)
        end
      end

      it '#transform_outcoming' do
        expect(out_tr).to receive(:transform)
        expect(dispatcher).to receive(:transform_outcoming).and_wrap_original do |original, result, original_message|
          expect(result).to be_a(Aggredator::Dispatcher::Result)
          expect(original_message.message_id).to eq incmsg1.message_id
          original.call(result, original_message)
          throw :stoptest, :stopped
        end

        with_stoptest do
          dispatcher.process_request(mqmsg)
        end
      end

      it '#process_incomming_message' do
        expect(dispatcher).to receive(:process_incomming_message).and_wrap_original do |original, mq, msg|
          expect(mq).to eq(mqmsg)
          expect(msg).to eq(incmsg1)
          original.call(mq, msg)
          throw :stoptest, :stopped
        end

        with_stoptest do
          dispatcher.process_request(mqmsg)
        end
      end

      it '#send_results' do
        expect(out_tr).to receive(:transform)
        expect(dispatcher).to receive(:send_results).and_wrap_original do |original, mq, msg, results|
          expect(mq).to eq(mqmsg)
          expect(msg).to eq(incmsg1)
          expect(results).to match_array(result1)
          original.call(mq, msg, results)
          throw :stoptest, :stopped
        end

        with_stoptest do
          observer.set_result(result1)
          dispatcher.process_request(mqmsg)
        end
      end
    end
  end
end

