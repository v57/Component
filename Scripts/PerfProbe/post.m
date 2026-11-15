// perfprobe-post <pid> <command>: posts a PerfProbe command to that app.
// perfprobe-post --name <notification name> <object>: posts any distributed notification (an app's debug hooks).
#import <Foundation/Foundation.h>

int main(int argc, const char *argv[]) {
  if (argc < 3) {
    fprintf(stderr, "usage: perfprobe-post <pid> <command>\n");
    return 2;
  }
  BOOL named = strcmp(argv[1], "--name") == 0 && argc >= 4;
  NSString *name = named ? @(argv[2]) : [NSString stringWithFormat:@"dev.v57.perfprobe.%s", argv[1]];
  [[NSDistributedNotificationCenter defaultCenter] postNotificationName:name
                                                                 object:@(argv[named ? 3 : 2])
                                                               userInfo:nil
                                                     deliverImmediately:YES];
  return 0;
}
