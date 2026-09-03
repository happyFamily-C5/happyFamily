#!/bin/sh
# Disables Xcode's "Queue Debugging > Enable backtrace recording" in every
# generated scheme (XcodeGen rewrites schemes on each `xcodegen generate`,
# so the toggle is re-applied here via project.yml options.postGenCommand).
#
# Why: LLDB's queue instrumentation sends -[OS_dispatch_mach_msg _setContext:]
# to dispatch objects whose internals changed on recent iOS runtimes. The
# unrecognized selector aborts the app at launch *under the debugger only*
# (launching from the home screen is unaffected). Unchecked, the option
# restores normal debugging; ordinary breakpoints and stepping still work.
set -e
cd "$(dirname "$0")/.."

patched=0
for scheme in happyFamily.xcodeproj/xcshareddata/xcschemes/*.xcscheme; do
  [ -f "$scheme" ] || continue
  if grep -q "enableBacktraceRecording" "$scheme"; then
    continue
  fi
  python3 - "$scheme" <<'EOF'
import re
import sys

path = sys.argv[1]
with open(path) as file:
    text = file.read()
patched = re.sub(
    r"(<LaunchAction\b[^>]*?)>",
    r'\1\n      enableBacktraceRecording = "NO">',
    text,
    count=1,
)
with open(path, "w") as file:
    file.write(patched)
EOF
  patched=$((patched + 1))
done

echo "patch-schemes: queue backtrace recording disabled in ${patched} scheme(s)."
