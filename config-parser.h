static inline bool is_line_key(const str* line, const str* key) {
  return line->len > key->len && isspace(line->c_str[key->len]) &&
         !strncmp(line->c_str, key->c_str, key->len);
}

static inline void set_conf(pair* conf, str** line, const size_t key_len) {
  int i;
  for (i = key_len; isspace((*line)->c_str[i]); ++i)
    ;
  conf->val->c_str = (*line)->c_str + i;

  for (i = (*line)->len; isspace((*line)->c_str[i]); --i)
    ;
  (*line)->c_str[i - 1] = 0;

  swap(conf->scoped, *line);
}

static inline void set_conf_pick(conf* c, str** line) {
  const str bootfs_str = {.c_str = "bootfs", .len = sizeof("bootfs") - 1};
  const str bootfstype_str = {.c_str = "bootfstype",
                              .len = sizeof("bootfstype") - 1};
  const str fs_str = {.c_str = "fs", .len = sizeof("fs") - 1};
  const str fstype_str = {.c_str = "fstype", .len = sizeof("fstype") - 1};
  const str udev_trigger_str = {.c_str = "udev_trigger",
                                .len = sizeof("udev_trigger") - 1};

  if (is_line_key(*line, &bootfs_str))
    set_conf(&c->bootfs, line, bootfs_str.len);
  else if (is_line_key(*line, &bootfstype_str))
    set_conf(&c->bootfstype, line, bootfstype_str.len);
  else if (is_line_key(*line, &fs_str))
    set_conf(&c->fs, line, fs_str.len);
  else if (is_line_key(*line, &fstype_str))
    set_conf(&c->fstype, line, fstype_str.len);
  else if (is_line_key(*line, &udev_trigger_str))
    set_conf(&c->udev_trigger, line, udev_trigger_str.len);
}

static inline void print_conf(conf* c) {
  printd(
      "bootfs: {\"%s\", \"%s\"}, bootfstype: {\"%s\", \"%s\"}, fs: {\"%s\", "
      "\"%s\"}, fstype: {\"%s\", \"%s\"}, udev_trigger: {\"%s\", \"%s\"}\n",
      c->bootfs.val->c_str, c->bootfs.scoped->c_str, c->bootfstype.val->c_str,
      c->bootfstype.scoped->c_str, c->fs.val->c_str, c->fs.scoped->c_str,
      c->fstype.val->c_str, c->fstype.scoped->c_str, c->udev_trigger.val->c_str,
      c->udev_trigger.scoped->c_str);
}

static inline char* read_conf(const char* file, conf* c) {
  autofclose FILE* f = fopen(file, "r");
  autofree_str str* line = (str*)malloc(sizeof(str));
  if (!line)
    return NULL;

  line->c_str = 0;

  if (!f)
    return NULL;

  for (size_t len_alloc;
       (line->len = getline(&line->c_str, &len_alloc, f)) != -1;)
    set_conf_pick(c, &line);

  print_conf(c);

  return NULL;
}
