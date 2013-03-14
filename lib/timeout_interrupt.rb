require 'ffi/libc'
require 'timeout'

# Provided by ffi-libc-lib and extended by this library, if needed.
# Older version of ffi-libc does not provide {FFI::LibC.alarm}
module FFI
	module LibC
		# @!method alarm(seconds)
		# Sets an alarm. After `seconds` it will send an ALRM-signal to this process.
		#
		# Predefined alarm will be reset and will forget.
		# @note Older implementations of ffi-libc does not provide {alarm}, but we need it.
		#       So we detect, if it is not provided and attach it.
		# @param seconds [0] Clears alarm.
		# @param seconds [Integer] How many seconds should be waited, before ALRM-signal should be send?
		# @return (nil)
		attach_function :alarm, [:uint], :uint  unless FFI::LibC.respond_to? :alarm
	end
end

# Helper module for `TimeoutInterrupt`
# @see TimeoutInterrupt
module TimeoutInterruptSingleton
	class <<self
		# Stores all timeouts.
		#
		# @param thread [nil] must be nil! Do not use it yet!
		# @return [Hash< key(Integer): [at(Time), backtrace(Array<String>), exception(Exception)] >]
		def timeouts thread = nil
			@timeouts ||= Hash.new {|h,k| h[k] = {} }
			thread = Thread.current  unless thread.kind_of? Thread
			thread ? @timeouts[thread] : @timeouts
		end

		# If there's a timed out timeout, it will raise its exception.
		# Can be used for handling ALRM-signal.
		# It will prepare the next timeout, too.
		#
		# The timeout will not removed from timeouts, because it is timed out, yet.
		# First, if timeout-scope will be exit, it will be removed.
		#
		# @return [nil]
		def alarm_trap sig
			raise_if_sb_timed_out
			setup
		end

		# There is a timed out timeout? It will raise it!
		# You need not to check it yourself, it will do it for you.
		#
		# @return [nil]
		def raise_if_sb_timed_out
			return  if self.timeouts.empty?
			key, (at, bt, exception) = self.timeouts.min_by {|key,(at,bt,ex)| at }
			return  if Time.now < at
			raise exception, 'execution expired', bt
		end

		# Prepares the next timeout. Sets the trap and the shortest timeout as alarm.
		#
		# @return [nil]
		def setup
			if timeouts.empty?
				Signal.trap( 'ALRM') {}
				FFI::LibC.alarm 0
			else
				raise_if_sb_timed_out
				Signal.trap 'ALRM', &method( :alarm_trap)
				key, (at, bt) = timeouts.min_by {|key,(at,bt)| at }
				FFI::LibC.alarm (at - Time.now).to_i + 1
			end
			nil
		end

		# Creates a timeout and calls your block, which has to finish before timeout occurs.
		#
		# @param seconds [0]           No timeout, so block can take any time.
		# @param seconds [Integer]     In `seconds` Seconds, it should raise a timeout, if not finished.
		# @param seconds [nil]         If also no block given, everything will be ignored and
		#                              it will call {setup} for checking and preparing next known timeout.
		# @param exception [Exception] which will be raised if timed out.
		# @param exception [nil]       `TimeoutInterrupt::Error` will be used to raise.
		# @param block [Proc]          Will be called and should finish its work before it timed out.
		# @param block [nil]           Nothing will happen, instead it will return a Proc,
		#                              which can be called with a block to use the timeout.
		# @return If block given, the returned value of your block.
		#         Or if not, it will return a Proc, which will expect a Proc if called.
		#         This Proc has no arguments and will prepare a timeout, like if you had given a block.
		#
		# You can rescue `Timeout::Error`, instead `TimeoutInterrupt::Error`, it will work too.
		#
		# It will call your given block, which has `seconds` seconds to end.
		# If you want to prepare a timeout, which should be used many times,
		# without giving `seconds` and `exception`, you can omit the block,
		# so, `TimeoutInterruptSingleton#timeout` will return a `Proc`, which want to have the block.
		#
		# There is a problem with scoped timeouts. If you rescue a timeout in an other timeout,
		# it's possible, that the other timeout will never timeout, because both are timed out at once.
		# Than you need to call `TimeoutInterruptSingleton#timeout` without arguments.
		# It will prepare the next timeout or it will raise it directy, if timed out.
		#
		# @see TimeoutInterrupt.timeout
		# @see TimeoutInterrupt#timeout
		# @raise exception
		def timeout seconds = nil, exception = nil, &block
			return yield( seconds)  if seconds.nil? || 0 == seconds  if block_given?
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
				yield seconds
			ensure
				self.timeouts.delete key
				setup
			end
		end
	end
end

# Can be included, or used directly.
# In both cases, it provides {#timeout}.
#
# @see TimeoutInterruptSingleton
module TimeoutInterrupt
	# The {TimeoutInterrupt::Error} is the default exception, which will be raised,
	# if something will time out.
	# Its base-class is {Timeout::Error}, so you can replace {Timeout} by {TimeoutInterrupt} without
	# replacing your `rescue Timeout::Error`, but you can.
	class Error < Timeout::Error
	end

	# Creates a timeout and calls your block, which has to finish before timeout occurs.
	#
	# @param seconds [0]           No timeout, so block can take any time.
	# @param seconds [Integer]     In `seconds` Seconds, it should raise a timeout, if not finished.
	# @param seconds [nil]         If also no block given, everything will be ignored and
	#                              it will call {setup} for checking and preparing next known timeout.
	# @param exception [Exception] which will be raised if timed out.
	# @param exception [nil]       `TimeoutInterrupt::Error` will be used to raise.
	# @param block [Proc]          Will be called and should finish its work before it timed out.
	# @param block [nil]           Nothing will happen, instead it will return a Proc,
	#                              which can be called with a block to use the timeout.
	# @return If block given, the returned value of your block.
	#         Or if not, it will return a Proc, which will expect a Proc if called.
	#         This Proc has no arguments and will prepare a timeout, like if you had given a block.
	#
	# You can rescue `Timeout::Error`, instead `TimeoutInterrupt::Error`, it will work too.
	#
	# It will call your given block, which has `seconds` seconds to end.
	# If you want to prepare a timeout, which should be used many times,
	# without giving `seconds` and `exception`, you can omit the block,
	# so, `TimeoutInterruptSingleton#timeout` will return a `Proc`, which want to have the block.
	#
	# There is a problem with scoped timeouts. If you rescue a timeout in an other timeout,
	# it's possible, that the other timeout will never timeout, because both are timed out at once.
	# Than you need to call `TimeoutInterruptSingleton#timeout` without arguments.
	# It will prepare the next timeout or it will raise it directy, if timed out.
	#
	# @see TimeoutInterrupt#timeout
	# @see TimeoutInterruptSingleton.timeout
	# @raise exception
	def self.timeout seconds = nil, exception = nil, &block
		TimeoutInterruptSingleton.timeout seconds, exception, &block
	end

	# Creates a timeout and calls your block, which has to finish before timeout occurs.
	#
	# @param seconds [0]           No timeout, so block can take any time.
	# @param seconds [Integer]     In `seconds` Seconds, it should raise a timeout, if not finished.
	# @param seconds [nil]         If also no block given, everything will be ignored and
	#                              it will call {setup} for checking and preparing next known timeout.
	# @param exception [Exception] which will be raised if timed out.
	# @param exception [nil]       `TimeoutInterrupt::Error` will be used to raise.
	# @param block [Proc]          Will be called and should finish its work before it timed out.
	# @param block [nil]           Nothing will happen, instead it will return a Proc,
	#                              which can be called with a block to use the timeout.
	# @return If block given, the returned value of your block.
	#         Or if not, it will return a Proc, which will expect a Proc if called.
	#         This Proc has no arguments and will prepare a timeout, like if you had given a block.
	#
	# You can rescue `Timeout::Error`, instead `TimeoutInterrupt::Error`, it will work too.
	#
	# It will call your given block, which has `seconds` seconds to end.
	# If you want to prepare a timeout, which should be used many times,
	# without giving `seconds` and `exception`, you can omit the block,
	# so, `TimeoutInterruptSingleton#timeout` will return a `Proc`, which want to have the block.
	#
	# There is a problem with scoped timeouts. If you rescue a timeout in an other timeout,
	# it's possible, that the other timeout will never timeout, because both are timed out at once.
	# Than you need to call `TimeoutInterruptSingleton#timeout` without arguments.
	# It will prepare the next timeout or it will raise it directy, if timed out.
	#
	# @note This method is useful, if you `include TimeoutInterrupt`. You can call it directly.
	# @see TimeoutInterrupt.timeout
	# @see TimeoutInterruptSingleton.timeout
	# @raise exception
	def timeout seconds = nil, exception = nil, &block
		TimeoutInterruptSingleton.timeout seconds, exception, &block
	end
end
