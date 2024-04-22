#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include "scsi_probe.h"

static int c2i(char *str){
	char *endptr;
	int num;

	errno = 0;
	num = strtol(str, &endptr, 10);
	if ((errno != 0 && num == 0) || (num > 99)) return -1;
	if (endptr == str) return -1;
	return num;
}

inline int update_scsi_args(const char *ba_str, struct args *ba){
	char *token;
	char *ba_str2;
	char *tmp1, *tmp2;

	if (!ba_str) return 0;
	if ((ba_str2 = strdup(ba_str)) == NULL) return 0;
	token = strtok(ba_str2, " ");
	while (token != NULL) {
		if (strncmp(token, SCSI_ADDR_BOOT_ARG, strlen(SCSI_ADDR_BOOT_ARG)) == 0) {
			tmp1 = strchr(token, '=');
			if (tmp1 != NULL) {
				tmp2 = tmp1 + 1;
				sscanf(tmp2, "%d:%d:%d:%d", &ba->scsi_host, &ba->scsi_channel, &ba->scsi_id, &ba->scsi_lun);
			}
		}
		token = strtok(NULL, " ");
	}
	free(ba_str2);
	return 1;
}


int parse_kernel_cmdline(const char *ba_str, struct args *ba){
	memset(ba, 0, sizeof(struct args));
	ba->scsi_manual=strstr(ba_str, "scsi_mod.scan=manual")?1:0;
	return update_scsi_args(ba_str, ba);
}

char *fetch_kernel_cmdline(const char *cmdline_fn){
	FILE *file;
	char *cmdline;

	file = fopen(cmdline_fn, "r");
	if (file == NULL) return NULL;
	cmdline = (char *) malloc(MAX_BUF);
	if (! fgets(cmdline, MAX_BUF, file)) {
		free(cmdline);
		return NULL;
	}
	fclose(file);
	return cmdline;
}


int trigger_scan(struct args *ba, const char *scsi_sys_tmpl, const int scsi_sys_tmpl_sz) {
	FILE *file;
	char buf[128];
	int n;

	if (ba->scsi_manual==0) return 0;
	snprintf(buf, scsi_sys_tmpl_sz, scsi_sys_tmpl, ba->scsi_host);
	file = fopen(buf, "w");
	if (file == NULL) return 0;
	n = snprintf(buf, MAX_BUF, SCSI_SYS_SCAN_STR, ba->scsi_channel, ba->scsi_id, ba->scsi_lun);
	fwrite(buf, n, 1, file);
	fclose(file);
	return 1;
}
