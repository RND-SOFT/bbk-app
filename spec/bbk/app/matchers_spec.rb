RSpec.describe BBK::App::Matchers do
  metadata = {
    user_id: 'user',
    headers: { 'ticket' => '544fa70d-4a2c-458a-803f-db80f240e9cc', 'consumer' => 'admin', 'retry' => 0 },
    content_type: 'application/octet-stream',
    delivery_mode: 2, priority: 0, reply_to: 'admin', message_id: '3'
  }
  payload = { 'passportSeries' => '5', 'test' => { value: 1 }, 'passportNumber' => '465', 'lastname' => '456',
              'firstname' => '456', 'middlename' => '4565464', 'snils' => '54656564', 'inn' => '5646' }
  delivery_info = {
    routing_key: 'test'
  }

  matchers = BBK::App::Matchers

  context 'matchers create' do
    types = {
      meta:     matchers::Headers,
      headers:  matchers::Headers,
      payload:  matchers::Payload,
      delivery: matchers::DeliveryInfo,
      full:     matchers::Full
    }

    types.each do |type, cls|
      it "create #{type} matcher" do
        matcher = described_class.create(type, {}, {}, {})
        expect(matcher).to be_a cls
      end
    end

    it 'unknown matcher' do
      expect do
        described_class.create(SecureRandom.hex, {})
      end.to raise_error(RuntimeError, /no such matcher/)
    end
  end

  describe BBK::App::Matchers::Headers do
    success_cases = [
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     { user_id: :any, headers: { consumer: 'admin' } },
        result:   { user_id: 'user', headers: { consumer: 'admin' } }
      },
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     { user_id: 'user', headers: { consumer: :any }, priority: 0 },
        result:   { user_id: 'user', headers: { consumer: 'admin' }, priority: 0 }
      },
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     {},
        result:   {}
      }
    ]

    failure_story = [
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     { user_id: :any, headers: { consumer: 'not admin' } }
      },
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     { user_id: 'user', headers: { consumer: :any }, priority: 1 }
      }
    ]

    success_cases.each_with_index do |args, i|
      meta = args[:metadata]
      payload = args[:payload]
      rule = args[:rule]
      result = args[:result].with_indifferent_access

      it "success case #{i} [#{rule.inspect}]" do
        m = matchers.create(:meta, rule)
        expect(m.match(meta, {})).not_to eq nil
        expect(m.match(meta, {})).to eq result
      end
    end

    failure_story.each_with_index do |args, i|
      meta = args[:metadata]
      payload = args[:payload]
      rule = args[:rule]
      result = nil

      it "failure case #{i} [#{rule.inspect}]" do
        m = matchers.create(:meta, rule)
        expect(m.match(meta, {})).to eq nil
        expect(m.match(meta, {})).to eq result
      end
    end

    it 'return nil on exception' do
      matcher = described_class.new({})
      expect(matcher.match(nil, nil)).to be_nil
    end
  end

  describe BBK::App::Matchers::Payload do
    success_cases = [
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     { passportSeries: :any, test: { value: :any } },
        result:   { passportSeries: '5', test: { value: 1 } }
      },
      {
        metadata: metadata.deep_dup,
        payload:  { request: payload.deep_dup },
        rule:     { request: { passportSeries: :any, test: :any } },
        result:   { request: { passportSeries: '5', test: { value: 1 } } }
      }
    ]

    failure_story = [
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     { passportSeries: :any, test: { value: 2 } }
      }
    ]

    success_cases.each_with_index do |args, i|
      meta = args[:metadata]
      payload = args[:payload]
      rule = args[:rule]
      result = args[:result].with_indifferent_access

      it "success case #{i} [#{rule.inspect}]" do
        m = BBK::App::Matchers::Payload.new(rule)
        expect(m.match({}, args[:payload])).not_to eq nil
        expect(m.match({}, args[:payload])).to eq result
      end
    end

    failure_story.each_with_index do |args, i|
      meta = args[:metadata]
      payload = args[:payload]
      rule = args[:rule]
      result = nil

      it "failure case #{i} [#{rule.inspect}]" do
        m = BBK::App::Matchers::Payload.new(rule)
        expect(m.match({}, payload)).to eq nil
        expect(m.match({}, payload)).to eq result
      end
    end

    it 'return nil on exception' do
      matcher = described_class.new({})
      expect(matcher.match(nil, nil)).to be_nil
    end
  end

  describe BBK::App::Matchers::DeliveryInfo do
    success_cases = [
      {
        metadata:      metadata.deep_dup,
        payload:       payload.deep_dup,
        delivery_info: delivery_info.deep_dup,
        rule:          { routing_key: :any },
        result:        { routing_key: 'test' }
      },
      {
        metadata:      metadata.deep_dup,
        payload:       payload.deep_dup,
        delivery_info: delivery_info.deep_dup,
        rule:          { routing_key: '#test#' },
        result:        { routing_key: 'test' }
      }
    ]

    failure_story = [
      {
        metadata:      metadata.deep_dup,
        payload:       payload.deep_dup,
        delivery_info: delivery_info.deep_dup,
        rule:          { passportSeries: :any, test: { value: 2 } }
      }
    ]

    success_cases.each_with_index do |args, i|
      delivery_info = args[:delivery_info]
      rule = args[:rule]
      result = args[:result].with_indifferent_access

      it "success case #{i} [#{rule.inspect}]" do
        m = described_class.new(rule)
        m.match({}, {}, delivery_info)
        expect(m.match({}, {}, delivery_info)).not_to eq nil
        expect(m.match({}, {}, delivery_info)).to eq result
      end
    end

    failure_story.each_with_index do |args, i|
      delivery_info = args[:delivery_info]
      rule = args[:rule]
      result = nil

      it "failure case #{i} [#{rule.inspect}]" do
        m = described_class.new(rule)
        expect(m.match({}, {}, delivery_info)).to eq nil
        expect(m.match({}, {}, delivery_info)).to eq result
      end
    end

    it 'return nil on exception' do
      matcher = described_class.new({})
      expect(matcher.match(nil, nil, nil)).to be_nil
    end
  end

  describe BBK::App::Matchers::Full do
    success_cases = [
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     [{ user_id: :any, headers: { consumer: 'admin' } }, { passportSeries: :any, test: { value: :any } },
                   { routing_key: 'test' }],
        result:   [{ user_id: 'user', headers: { consumer: 'admin' } }, { passportSeries: '5', test: { value: 1 } },
                   { routing_key: 'test' }]
      }
    ]

    failure_story = [
      {
        metadata: metadata.deep_dup,
        payload:  payload.deep_dup,
        rule:     [{ user_id: :any, headers: { consumer: 'not_admin' } },
                   { passportSeries: :any, test: { value: :any } }, { routing_key: :any }]
      }
    ]

    success_cases.each_with_index do |args, i|
      meta = args[:metadata]
      payload = args[:payload]
      rule = args[:rule]
      result = args[:result].map(&:with_indifferent_access)

      it "success case #{i} [#{rule.inspect}]" do
        m = BBK::App::Matchers::Full.new(*rule)
        expect(m.match(meta, payload, delivery_info)).not_to eq nil
        expect(m.match(meta, payload, delivery_info)).to eq result
      end
    end

    failure_story.each_with_index do |args, i|
      meta = args[:metadata]
      payload = args[:payload]
      rule = args[:rule]
      result = nil

      it "failure case #{i} [#{rule.inspect}]" do
        m = BBK::App::Matchers::Full.new(*rule)
        expect(m.match({}, payload, delivery_info)).to eq nil
        expect(m.match({}, payload, delivery_info)).to eq result
      end
    end

    it 'return nil on exception' do
      matcher = described_class.new({}, {}, {})
      matcher.instance_variable_set('@mm', nil)
      expect(matcher.match(nil, nil, nil)).to be_nil
    end
  end
end

