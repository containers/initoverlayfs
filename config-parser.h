static inline bool is_line_key(const str* line, const str* key) {
  return line->len > key->len && isspace(line->c_str[key->len]) &&
         !strncmp(line->c_str, key->c_str, key->len);
}

static inline int conf_construct(conf* c) {
  c->bootfs.val = (str*)calloc(1, sizeof(str));
  c->bootfs.scoped = (str*)calloc(1, sizeof(str));
  c->bootfstype.val = (str*)calloc(1, sizeof(str));
  c->bootfstype.scoped = (str*)calloc(1, sizeof(str));
  c->fs.val = (str*)calloc(1, sizeof(str));
  c->fs.scoped = (str*)calloc(1, sizeof(str));
  c->fstype.val = (str*)calloc(1, sizeof(str));
  c->fstype.scoped = (str*)calloc(1, sizeof(str));
  return !c->bootfs.val || !c->bootfs.scoped || !c->bootfstype.val ||
         !c->bootfstype.scoped || !c->fs.val || !c->fs.scoped ||
         !c->fstype.val || !c->fstype.scoped;
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

static inline void conf_set_pick(conf* c, str** line) {
  const str bootfs_str = {.c_str = "bootfs", .len = sizeof("bootfs") - 1};
  const str bootfstype_str = {.c_str = "bootfstype",
                              .len = sizeof("bootfstype") - 1};
  const str fs_str = {.c_str = "fs", .len = sizeof("fs") - 1};
  const str fstype_str = {.c_str = "fstype", .len = sizeof("fstype") - 1};

  if (is_line_key(*line, &bootfs_str))
    set_conf(&c->bootfs, line, bootfs_str.len);
  else if (is_line_key(*line, &bootfstype_str))
    set_conf(&c->bootfstype, line, bootfstype_str.len);
  else if (is_line_key(*line, &fs_str))
    set_conf(&c->fs, line, fs_str.len);
  else if (is_line_key(*line, &fstype_str))
    set_conf(&c->fstype, line, fstype_str.len);
}

static inline conf* conf_print(conf* c) {
#ifdef DEBUG
  printd(
      "bootfs: {\"%s\", \"%s\"}, bootfstype: {\"%s\", \"%s\"}, fs: {\"%s\", "
      "\"%s\"}, fstype: {\"%s\", \"%s\"}\n",
      c->bootfs.val->c_str, c->bootfs.scoped->c_str, c->bootfstype.val->c_str,
      c->bootfstype.scoped->c_str, c->fs.val->c_str, c->fs.scoped->c_str,
      c->fstype.val->c_str, c->fstype.scoped->c_str);
#endif
  return c;
}

static inline char* conf_read(conf* c, const char* file) {
  autofclose FILE* f = fopen(file, "r");
  autofree_str str* line = (str*)malloc(sizeof(str));
  if (!line)
    return NULL;

  line->c_str = 0;

  if (!f)
    return NULL;

  for (size_t len_alloc;
       (line->len = getline(&line->c_str, &len_alloc, f)) != -1;)
    conf_set_pick(c, &line);

  conf_print(c);

  return NULL;
}
