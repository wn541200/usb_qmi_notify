#ifndef __UEVENT_H__
#define __UEVENT_H__

#define ERROR(fmt, arg...) do { fprintf(stderr, fmt, ##arg); fflush(stderr); } while(0)
#define INFO(fmt, arg...) do { fprintf(stdout, fmt, ##arg); fflush(stdout); } while(0)
#define NOTICE(fmt, arg...) do { fprintf(stdout, fmt, ##arg); fflush(stdout); } while(0)

typedef void (*event_cb)(int state, void *data);

extern int uevent_loop(event_cb cb, void *userdata);

#endif
