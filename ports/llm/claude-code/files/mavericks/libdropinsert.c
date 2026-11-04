#include <stdlib.h>
/* Nach dem Laden (libavxemu-Handler ist dann bereits installiert) den Insert aus
   der Umgebung entfernen, damit Kindprozesse ihn nicht erben. */
__attribute__((constructor))
static void avxemu_drop_insert(void){ unsetenv("DYLD_INSERT_LIBRARIES"); }
