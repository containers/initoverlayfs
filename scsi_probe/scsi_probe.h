#define MAX_ARGS 100
#define MAX_BUF 128

#define SCSI_SYS_SCAN_STR "%d %d %d\n"

#define SCSI_ADDR_BOOT_ARG "scsi.addr"

struct args {
	int scsi_manual;
	int scsi_host;
	int scsi_channel;
	int scsi_id;
	int scsi_lun;
};

int update_scsi_args(const char *, struct args *);
int parse_kernel_cmdline(const char *, struct args *);
char *fetch_kernel_cmdline(const char *);
int trigger_scan(struct args *, const char *, const int);
