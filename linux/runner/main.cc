#include <cstdlib>
#include <sys/stat.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // Restrictive process umask BEFORE Flutter initializes any plugin: files
  // and directories the app creates (vault data dir, logs, cache fragments)
  // must not become group/world readable just because the desktop session
  // launched us with a permissive umask (e.g. 0002). Vault-class files are
  // additionally created with explicit mode 0600 by the storage layer, which
  // does not depend on this umask; this protects everything else.
  umask(077);
  // Round-6 rendering fix (2026-10-18): under Wayland sessions that provide
  // XWayland, run through GDK's X11 backend. Flutter's Impeller-on-GL
  // surfaces come up black when a new subtree first paints on this GPU class
  // (older NVIDIA on nouveau; reproduced on a GT 710) — the Send tab click
  // and the post-import wallet view both hit it. The same binary renders
  // every page correctly via XWayland, with GPU acceleration retained.
  // An explicit GDK_BACKEND from the user's environment is never overridden.
  if (getenv("GDK_BACKEND") == nullptr &&
      getenv("WAYLAND_DISPLAY") != nullptr && getenv("DISPLAY") != nullptr) {
    setenv("GDK_BACKEND", "x11", 0);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
