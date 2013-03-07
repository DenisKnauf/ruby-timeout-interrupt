timeout-interrupt
=================

Works like ruby's timeout, but interrupts every call, also syscalls, which blocks the hole ruby-process.

It uses POSIX's alarm and traps ALRM-signals.

Known limitations bacause of alarm and ALRM are, that you can not use alarm or trap ALRM.

Scopes
======

If you need scopes with inner and outer time outs, you should know:

The first timed out Timeout will be raised:

	include TimeoutInterrupt
	timeout(1) { # Will be raised
		timeout(10) { sleep 2 } # Will not be raised
	}

If you want to know, which was raised, you need custom exceptions:

	class CustomErrorWillBeRaised <Exception
	end
	class CustomErrorNotRaise <Exception
	end
	include TimeoutInterrupt
	timeout( 1, CustomErrorWillBeRaised) { # Will be raised again
		timeout( 10, CustomErrorNotRaise) { sleep 2 } # Will not be raised
	}

Problems
========

Memory-Leaks or no clean up
---------------------------

Do not forget, syscall can have allocated memory.
If you interrupt a call, which can not free his allocations, you will have a memory leak.
If it opens a file, reads it and closes it and while it reads, a time out occurs, the file will not be closed.

So, use it only, if your process did not live any longer or if you call something, which never allocate mem or opens a file.

Every time, a process dies, all his memory will be freed and every file will be closed, so let your process die and you should be safe.

Exception-handling
------------------

Timeouts can break your exception-handling! You should not handling exception while you wait for a timeout:

	include TimeoutInterrupt
	timeout(1) {
		begin
			transaction_begin
			do_something
		ensure
			clean_up
			transaction_end
		end
	}

Same happens, if clean\_up will raise an exception.

And same problem you have with ruby's `Timeout.timeout`.

Copyleft
=========

Copyright (c) 2013 Denis Knauf. See LICENSE.txt for further details.
