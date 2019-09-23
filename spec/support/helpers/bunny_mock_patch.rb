require 'bunny-mock'

class BunnyMock::Exchange

  def on_return(*args); end

end

class BunnyMock::Channel

  attr_reader :next_publish_seq_no

  alias origin_initialize initialize

  def initialize(*args)
    @next_publish_seq_no = 99
    self.send(:origin_initialize, *args)
  end

  def synchronize
    yield
  end

end

class BunnyMock::Exchanges::Direct

  attr_reader :messages

  def deliver *args, **kwargs
    @messages ||= []
    @messages << [*args, kwargs]
  end

end

