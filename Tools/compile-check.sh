#!/usr/bin/env bash
# Tools/compile-check.sh — typecheck the whole C# tree outside the Editor.
#
# Uses the Unity install's Roslyn with stub assemblies for UnityEngine.UI and
# TMPro (Tools/CompileCheck/*.cs) so the legacy scripts that reference those
# packages compile-verify without the package DLLs, which only exist after an
# Editor import. The stubs live outside Assets/ and are never shipped.
set -u

E="D:/Unity/Editors/2022.3.20f1/Editor/Data"
if [ ! -d "$E" ]; then
    echo "Unity 2022.3.20f1 not found at $E" >&2
    exit 2
fi

# Windows-style paths: csc.exe is a Windows program, and Git Bash's /d/... form
# is read by it as a drive-rooted path on the wrong drive.
HERE="$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || pwd)"
ROOT="$(cd "$HERE/.." && pwd -W 2>/dev/null || pwd)"
OUT="$HERE/out"
mkdir -p "$OUT"

RSP="$OUT/check.rsp"
: > "$RSP"

echo "-target:library" >> "$RSP"
echo "-nostdlib+" >> "$RSP"
echo "-langversion:9" >> "$RSP"
echo "-nowarn:0169,0414,0649,0067,0219,1030" >> "$RSP"
echo "-out:\"$OUT/kaiserquest-check.dll\"" >> "$RSP"
echo "-r:\"$E/NetStandard/ref/2.1.0/netstandard.dll\"" >> "$RSP"

for dll in "$E"/Managed/UnityEngine/UnityEngine*.dll; do
    echo "-r:\"$dll\"" >> "$RSP"
done

# Verification-only stubs for package assemblies (never under Assets/).
for stub in "$HERE"/CompileCheck/*.cs; do
    [ -e "$stub" ] || continue
    echo "\"$stub\"" >> "$RSP"
done

# Every script in the project.
find "$ROOT/KaiserQuest-Unity/Assets/Scripts" -name '*.cs' | while read -r src; do
    src_win="$(cygpath -m "$src" 2>/dev/null || echo "$src")"
    echo "\"$src_win\"" >> "$RSP"
done

"$E/MonoBleedingEdge/bin/mono.exe" \
    "$E/MonoBleedingEdge/lib/mono/msbuild/Current/bin/Roslyn/csc.exe" \
    -noconfig @"$RSP"
status=$?

rm -f "$OUT/check.rsp" "$OUT/kaiserquest-check.dll"
exit $status
