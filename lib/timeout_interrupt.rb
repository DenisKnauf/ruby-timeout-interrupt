require 'ffi/libc'
require 'timeout'

module FFI
	module LibC
		attach_function :alarm, [:uint], :uint  unless FFI::LibC.respond_to? :alarm
	end
end

module TimeoutInterruptSingleton
	class <<self
		def timeouts thread = nil
			@timeouts ||= Hash.new {|h,k| h[k] = [] }
			thread = Thread.current  if thread.kind_of? Thread
			thread ? @timeouts[thread] : @timeouts
		end

		def alarm_trap sig
			key, (at, bt, exception) = self.timeouts.min_by {|key,(at,bt,ex)| at }
			return  if Time.now < at
			raise exception, 'execution expired', bt
		end

		def setup
			if timeouts.empty?
				Signal.trap( 'ALRM') {}
				FFI::LibC.alarm 0
			else
				key, (at, bt) = timeouts.min_by {|key,(at,bt)| at }
				secs = (at - Time.now)
				alarm_trap 14  if 0 > secs
				Signal.trap 'ALRM', &method( :alarm_trap)
				FFI::LibC.alarm secs.to_i+1
			end
		end

		def timeout seconds = nil, exception = nil
			return setup  if seconds.nil?
			seconds = seconds.to_i
			exception ||= TimeoutInterrupt::Error
			raise exception, "Timeout must be longer than '0' seconds."  unless 0 < seconds
			unless block_given?
				return lambda {|&e|
					raise exception, "Expect a lambda."  unless e
					timeout seconds, exception, &e
				}
			end
			at = Time.now + seconds
			key, bt = Random.rand( 2**64-1), Kernel.caller
			begin
				self.timeouts[key] = [at, bt, exception]
				setup
				yield
			ensure
				self.timeouts.delete key
				setup
			end
		end
	end
end

module TimeoutInterrupt
	class Error < Timeout::Error
	end

	def self.timeout seconds = nil, exception = nil, &e
		TimeoutInterruptSingleton.timeout seconds, exception, &e
	end

	def timeout seconds = nil, exception = nil, &e
		TimeoutInterruptSingleton.timeout seconds, exception, &e
	end
end
