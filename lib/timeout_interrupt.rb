require 'ffi/libc'
require 'timeout'

module FFI
	module LibC
		attach_function :alarm, [:uint], :uint  unless FFI::LibC.respond_to? :alarm
	end
end

module TimeoutInterrupt
	def self.timeouts
		@timeouts ||= {}
	end

	def self.alarm_trap sig
		key, (at, bt) = TimeoutInterrupt.timeouts.min_by {|key,(at,bt)| at }
		return  if Time.now < at
		raise Timeout::Error, 'execution expired', bt
	end

	def self.setup_timeout
		if TimeoutInterrupt.timeouts.empty?
			Signal.trap( 'ALRM') {}
			FFI::LibC.alarm 0
		else
			key, (at, bt) = TimeoutInterrupt.timeouts.min_by {|key,(at,bt)| at }
			secs = (at - Time.now).to_i+1
			TimeoutInterrupt.alarm_trap  if 1 > secs
			Signal.trap 'ALRM', &TimeoutInterrupt.method( :alarm_trap)
			FFI::LibC.alarm secs
		end
	end

	def self.timeout seconds
		seconds = seconds.to_i
		raise Timeout::Error, "Timeout must be longer than '0' seconds."  unless 0 < seconds
		return lambda {|&e| self.timeout seconds, &e }  unless block_given?
		at = Time.now + seconds
		key, bt = Random.rand( 2**64-1), Kernel.caller
		begin
			TimeoutInterrupt.timeouts[key] = [at, bt]
			TimeoutInterrupt.setup_timeout
			yield
		ensure
			TimeoutInterrupt.timeouts.delete key
			TimeoutInterrupt.setup_timeout
		end
	end
end
