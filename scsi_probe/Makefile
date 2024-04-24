CC=gcc
CFLAGS= -g
#QUIET = &>/dev/null
VALGRIND_FLAGS= --error-exitcode=1 --leak-check=full -s

tests: tests_res/parse_kernel_cmdline.exec.log tests_res/parse_kernel_cmdline.valgrind.log tests_res/fetch_kernel_cmdline.exec.log tests_res/fetch_kernel_cmdline.valgrind.log tests_res/trigger_scan.valgrind.log tests_res/trigger_scan.exec.log

################################################################
tests_res/parse_kernel_cmdline.exec.log: tests/parse_kernel_cmdline
	@echo "======================= Testing... " $< " exec"
	@$< > $@

tests_res/parse_kernel_cmdline.valgrind.log: tests/parse_kernel_cmdline
	@echo "======================= Testing... " $< "valgrind"
	@valgrind $(VALGRIND_FLAGS) $< >$@ 2>&1

tests/parse_kernel_cmdline: tests/parse_kernel_cmdline.c scsi_probe.o
	@echo "======================= Build... " $<
	@$(CC) $(CFLAGS) $^ -o $@

###########################################################################
tests_res/fetch_kernel_cmdline.exec.log: tests/fetch_kernel_cmdline
	@echo "======================= Testing... " $< " exec"
	@$< > $@

tests_res/fetch_kernel_cmdline.valgrind.log: tests/fetch_kernel_cmdline
	@echo "======================= Testing... " $< "valgrind"
	@valgrind $(VALGRIND_FLAGS) $< >$@ 2>&1

tests/fetch_kernel_cmdline: tests/fetch_kernel_cmdline.c scsi_probe.o
	@echo "======================= Build... " $<
	@$(CC) $(CFLAGS) $^ -o $@

###########################################################################
tests_res/trigger_scan.exec.log: tests/trigger_scan
	@echo "======================= Testing... " $< " exec"
	@$< > $@

tests_res/trigger_scan.valgrind.log: tests/trigger_scan
	@echo "======================= Testing... " $< "valgrind"
	@valgrind $(VALGRIND_FLAGS) $< >$@ 2>&1

tests/trigger_scan: tests/trigger_scan.c scsi_probe.o
	@echo "======================= Build... " $<
	@$(CC) $(CFLAGS) $^ -o $@

###########################################################################
scsi_probe.o: scsi_probe.c scsi_probe.h
	@echo "======================= Build... " $<
	@$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "======================= CLEAN... "
	@rm -f scsi_probe.o tests/parse_kernel_cmdline tests_res/*.log
