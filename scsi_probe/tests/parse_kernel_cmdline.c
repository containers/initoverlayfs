#include <stdio.h>
#include <string.h>
#include "../scsi_probe.h"

#define TEST_BUFF_SIZE 200

char *results[] = {
	"has manual=1 host=1 addr=2:3:45",
	"has manual=1 host=1 addr=2:3:45",
	"has manual=1 host=0 addr=0:0:0",
	"has manual=0 host=0 addr=0:0:0"
};

char *test_patterns[] = {
	"pippo=1 pluto=2 scsi_mod.scan=manual scsi.addr=1:2:3:45 paperino=peppe",
	"pippo=1 pluto=2 scsi_mod.scan=manual posw scsi.addr=1:2:3:45 paperino=peppe",
	"pippo=1 pluto=2 scsi_mod.scan=manual paperino=peppe",
	"pippo=1 pluto=2 paperino=peppe",

};

int main(){
	struct args ba;
	int i;
	char res[TEST_BUFF_SIZE];

	for (i=0; i< sizeof(test_patterns)/sizeof(char *); i++) {
		if (!parse_kernel_cmdline(test_patterns[i], &ba)) return -1;
		sprintf(res, "has manual=%d host=%d addr=%d:%d:%d", ba.scsi_manual, ba.scsi_host, ba.scsi_channel, ba.scsi_id, ba.scsi_lun);

		printf( "Test pattern='%s', expected result='%s' Actual result ='%s' -> ",
				test_patterns[i], results[i], res);
		if (strcmp(res, results[i])) {
			printf("Failed\n");
			return -1;
		}
		printf("Success\n");
	}
	return 0;
}
