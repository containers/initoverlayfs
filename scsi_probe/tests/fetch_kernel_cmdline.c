#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "../scsi_probe.h"

#define TEST_BUFF_SIZE 200

char *results[] = {
	"pippo=1 pluto=2 paperino=3\n",
	"pippo=1 pluto=2 paperino=3\n",
	NULL
};

char *test_patterns[] = {
	"testfiles/cmd1",
	"testfiles/cmd2",
	"testfiles/cmd3",
};

int main(){
	int i;
	char *res;

	for (i=0; i< sizeof(test_patterns)/sizeof(char *); i++) {
		res = fetch_kernel_cmdline(test_patterns[i]);
		printf( "Test pattern='%s', expected result='%s' Actual result ='%s' -> ",
				test_patterns[i], results[i], res);
		if (res && results[i]) {
			if (strcmp(res, results[i])!=0) {
				printf("Failed\n");
				free(res);
				return -1;
			}
		}
		printf("Success\n");
		free(res);
	}
	return 0;
}
