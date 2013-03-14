require 'helper'

class TestRubyTimeoutInterrupt < Test::Unit::TestCase
	def blocking
		t = FFI::LibC.fopen '/dev/ptmx', 'r'
		b = FFI::LibC.malloc 1025
		s = FFI::LibC.fread b, 1, 1024, t
	ensure
		FFI::LibC.fclose t  if t
		FFI::LibC.free b    if b
	end

	def assert_no_defined_timeout_yet
		assert TimeoutInterruptSingleton.timeouts.empty?, "For testing, no timeout should be defined, yet!"
	end

	def print_timeouts pre
		puts "#{pre}: < #{TimeoutInterruptSingleton.timeouts.map {|k,(a,_b,_e)| "#{k.inspect}: #{a.strftime '%H:%M:%S'} (#{a-Time.now})" }.join ', '} >"
	end

	# For testing raising scoped Timeout.
	class TimeoutError < Exception
	end
	# For testing raising scoped TimeoutInterrupt.
	class TimeoutInterruptError < Exception
	end

	context "Long really blocking calls" do
		should "not be interrupted by the old Timeout" do
			time = Benchmark.realtime do
				assert_nothing_raised TimeoutError, "Unexpected time out. Your Ruby implementation can time out with old Timeout? You need not TimeoutInterrupt. But it is ok. You can ignore this Error. :)" do
					assert_raise TimeoutInterruptError, "Ohoh. TimeoutInterrupt should be raised." do
						TimeoutInterrupt.timeout 5, TimeoutInterruptError do
							Timeout.timeout 1, TimeoutError do
								blocking
								assert false, "Should be unreachable!"
							end
						end
					end
				end
			end
			assert 3 < time, "Did timeout!"
		end

		should "be interrupted by the new TimeoutInterrupt" do
			time = Benchmark.realtime do
				assert_raise TimeoutInterrupt::Error, "It should be timed out, why it did not raise TimeoutInterrupt::Error?" do
					TimeoutInterrupt.timeout 1 do
						blocking
						assert false, "Should be unreachable!"
					end
				end
			end
			assert 3 > time, "Did not interrupt."
		end
	end

	should "interrupt scoped timeout, but not time out the outer timeout" do
		assert_no_defined_timeout_yet
		assert_raise TimeoutInterruptError, "It should be timed out, why it did not raise TimeoutInterruptError?" do
			assert_nothing_raised Timeout::Error, "Oh, outer timeout was timed out. Your machine must be slow, or there is a bug" do
				TimeoutInterrupt.timeout 10 do
					TimeoutInterrupt.timeout 1, TimeoutInterruptError do
						Kernel.sleep 2
					end
					assert false, "Should be unreachable!"
				end
			end
		end
		assert TimeoutInterruptSingleton.timeouts.empty?, "There are timeouts defined, yet!"
	end

	should "clear timeouts, if not timed out, too." do
		assert_no_defined_timeout_yet
		TimeoutInterrupt.timeout(10) {}
		assert TimeoutInterruptSingleton.timeouts.empty?, "There are timeouts defined, yet!"
	end

	class CustomException <Exception
	end

	should "raise custom exception." do
		assert_raise CustomException, "Custom exceptions do not work." do
			TimeoutInterrupt.timeout 1, CustomException do
				sleep 2
			end
		end
	end

	context "A prepared timeout (Proc)" do
		should "be returned by calling timeout without a block" do
			assert_no_defined_timeout_yet
			assert TimeoutInterrupt.timeout(10).kind_of?( Proc), "Did not return a Proc."
		end

		should "run with once given timeout" do
			assert_no_defined_timeout_yet
			to = TimeoutInterrupt.timeout 10
			called = false
			to.call { called = true }
			assert called, "Did not called."
		end

		should "raise custom exception" do
			assert_raise CustomException, "Custom exceptions do not work." do
				prepared = TimeoutInterrupt.timeout 1, CustomException
				prepared.call { sleep 2 }
			end
		end

		should "not be scopeable, without manualy setup after rescue and 2 time outs at once" do
			prepared = TimeoutInterrupt.timeout 1
			assert_no_defined_timeout_yet
			called = false
			prepared.call do
				assert_raise TimeoutInterrupt::Error, 'It should time out after one second, but it did not.' do
					prepared.call { 2; sleep 2 }
				end
				called = true
			end
			assert called, "It's true, it should be called, also if not expected."
		end

		should "be scopeable, with manualy setup after rescue, also if 2 time outs at once." do
			prepared = TimeoutInterrupt.timeout 1
			assert_no_defined_timeout_yet
			prepared.call do
				assert_raise TimeoutInterrupt::Error, 'It should time out after one second, but it did not.' do
					prepared.call { sleep 2 }
				end
				assert_raise TimeoutInterrupt::Error, 'Manualy called timeout setup did not raise.' do
					TimeoutInterrupt.timeout
				end
				assert true, "Should never be reached."
			end
		end
	end

	class IncludeModuleTest
		include TimeoutInterrupt
		def please_timeout after
			timeout after do
				sleep after+10
			end
		end
	end

	context "Included module" do
		should "provide timeout too" do
			assert_raise TimeoutInterrupt::Error, "Included timeout can not be used?" do
				IncludeModuleTest.new.please_timeout 2
			end
		end
	end

	should "not timeout, if timeout is 0" do
		assert_nothing_raised TimeoutInterrupt::Error, "Unexpected Timed out." do
			# should never timeout (we can not wait infinity seconds, so only 5)
			TimeoutInterrupt.timeout( 0) { sleep 5 }
		end
	end
end
