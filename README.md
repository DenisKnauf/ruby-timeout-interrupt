timeout-interrupt
=================

Works like ruby's timeout, but interrupts every call, also syscalls, which blocks the hole ruby-process.

It uses POSIX's alarm and traps ALRM-signals.

Known limitations bacause of alarm and ALRM are, that you can not use alarm or trap ALRM.

Do not forget, syscall can have allocated memory.
If you interrupt a call, which can not free his allocations, you will have a memory leak.
So, use it only, if your process did not live any longer or if you call something, which never allocate mem

Copyleft
=========

Copyright (c) 2013 Denis Knauf. See LICENSE.txt for further details.
