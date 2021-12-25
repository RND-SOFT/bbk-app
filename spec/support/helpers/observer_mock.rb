class ObserverMock

  attr_accessor :errors, :msg

  def raise_error(str)
    @error = str
  end

  def set_result(result)
    @result = result
  end

  def match(*_args)
    [{}, lambda {|msg, results:|
      @msg = msg
      if @error
        raise @error
      else
        results << (@result || BBK::App::Dispatcher::Result.new(
          BBK::App::Dispatcher::Route.new('mq://main@key'),
          @msg
        ))
      end
    }]
  end

end

