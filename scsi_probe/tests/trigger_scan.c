#include <stdio.h>
#include <string.h>
#include "../scsi_probe.h"

#define TEST_BUFF_SIZE 200
#define CMDLINE "cmdline"
#define SCSI_SYS_TMPL "testfiles/host%dscan"
#define SCSI_SYS_TMPL_SZ 30

struct result {
	int res;
	char *fn;
	char *addr;
};

struct result results[] = {
	{1, "testfiles/host0scan", "1 2 3\n"},
	{1, "testfiles/host2scan", "3 4 5\n"},
	{0, "testfiles/host0scan", "0 0 0\n"},
};

struct args test_patterns[] = {
	{1, 0, 1, 2, 3},
	{1, 2, 3, 4, 5},
	{0, 0, 1, 2, 3},
};

int verify(int res, struct args *test_pattern, struct result *r){
	char buf[100];
	int n;
	FILE *file;

	if (res != r->res) return 1;
	if (!res)  return 0;
	printf("trigger_scan ret code OK ");
	n = sprintf(buf, SCSI_SYS_TMPL, test_pattern->scsi_host);
	printf("comparefns: '%s' '%s' ", buf, r->fn);
	if (strncmp(buf, r->fn, n)) return 1;
	printf("file to read='%s' ", buf);
	file = fopen(buf, "r");
        if (file == NULL) return 1;
        n = fread(buf, 100, 1, file);
        fclose(file);

	printf("Compare buf=%s expected=%s ", buf, r->addr);
	if (strncmp(buf, r->addr, n)) return 1;
	return 0;
}




int main(){
	struct args ba;
	int i, r;
	char res[TEST_BUFF_SIZE];

	puts(SCSI_SYS_TMPL);
	for (i=0; i< sizeof(test_patterns)/sizeof(struct args); i++) {
		printf("%d - ", i);
		r = trigger_scan(&test_patterns[i], SCSI_SYS_TMPL, SCSI_SYS_TMPL_SZ);
		if (verify(r, &test_patterns[i], &results[i])) {
			printf("Failed\n");
			return -1;
		}
		printf("Success\n");
	}
	return 0;
}
