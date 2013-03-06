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
		assert TimeoutInterrupt.timeouts.empty?, "For testing, no timeout should be defined, yet!"
	end

	should "not interrupt a long blocking call with the old Timeout" do
		time = Benchmark.realtime do
			begin
				TimeoutInterrupt.timeout(5) do
					Timeout.timeout(1) do
						blocking
						assert false, "Should be unreachable!"
					end
				end
			rescue Timeout::Error
				:ok
			end
		end
		assert 3 < time, "Did timeout!"
	end

	should "interrupt a long blocking call with the new TimeoutInterrupt" do
		time = Benchmark.realtime do
			begin
				TimeoutInterrupt.timeout(1) do
					blocking
					assert false, "Should be unreachable!"
				end
			rescue Timeout::Error
				:ok
			end
		end
		assert 3 > time, "Did not interrupt."
	end

	should "interrupt scoped timeout, but not outer timeout" do
		assert_no_defined_timeout_yet
		begin
			TimeoutInterrupt.timeout(10) do
				TimeoutInterrupt.timeout(1) do
					Kernel.sleep 2
				end
				assert false, "Should be unreachable!"
			end
		rescue Timeout::Error
			:ok
		end
		assert TimeoutInterrupt.timeouts.empty?, "There are timeouts defined, yet!"
	end

	should "clear timeouts, if not timed out, too." do
		assert_no_defined_timeout_yet
		TimeoutInterrupt.timeout(10) {}
		assert TimeoutInterrupt.timeouts.empty?, "There are timeouts defined, yet!"
	end

	should "return a Proc if now block given, but do not create a timeout." do
		assert_no_defined_timeout_yet
		assert TimeoutInterrupt.timeout(10).kind_of?( Proc), "Did not return a Proc."
	end

	should "run a returned Proc with given timeout." do
		assert_no_defined_timeout_yet
		to = TimeoutInterrupt.timeout(10)
		called = false
		to.call { called = true }
		assert called, "Did not called."
	end
end
