#!/usr/bin/env bash
# Tools/compile-check.sh — typecheck the game's C# outside the Editor.
#
# Compiles against the *real* assemblies wherever they exist: Unity 6's engine
# DLLs plus the package assemblies the live project has already imported
# (UnityEngine.UI, Unity.TextMeshPro, Unity.InputSystem). The legacy UI scripts
# are therefore checked against the actual uGUI and TMP APIs they will be built
# against, not against hand-written stubs. The stubs in Tools/CompileCheck are
# only a fallback for a machine that has never opened the project (they live
# outside Assets/ and are never shipped).
#
# Three passes:
#   1. the 2022.3 development copy, player-only code
#   2. the live Unity 6 project, with UNITY_EDITOR defined — editor tooling too
#   3. the PlayMode tests, with the test framework referenced
#
# usage: bash Tools/compile-check.sh [--stubs]
set -u

HERE="$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || pwd)"
ROOT="$(cd "$HERE/.." && pwd -W 2>/dev/null || pwd)"
OUT="$HERE/out"
LIVE="$ROOT/KaiserQuest"
DEV="$ROOT/KaiserQuest-Unity"
PKG="$LIVE/Library/ScriptAssemblies"

mkdir -p "$OUT"

# --- locate a Unity install -------------------------------------------------
UNITY_DATA="${UNITY_DATA:-}"
if [ -z "$UNITY_DATA" ]; then
    for candidate in \
        "D:/Unity/Editors/6000.3.13f1/Editor/Data" \
        "D:/Unity/Editors/2022.3.20f1/Editor/Data" \
        "/c/Program Files/Unity/Hub/Editor/6000.3.13f1/Editor/Data" \
        "$HOME/Unity/Hub/Editor/6000.3.13f1/Editor/Data"; do
        if [ -d "$candidate" ]; then UNITY_DATA="$candidate"; break; fi
    done
fi

if [ -z "$UNITY_DATA" ] || [ ! -d "$UNITY_DATA" ]; then
    echo "No Unity install found. Set UNITY_DATA to <Editor>/Data and retry." >&2
    exit 2
fi

CSC="$UNITY_DATA/MonoBleedingEdge/lib/mono/msbuild/Current/bin/Roslyn/csc.exe"
MONO="$UNITY_DATA/MonoBleedingEdge/bin/mono.exe"
NETSTANDARD="$UNITY_DATA/NetStandard/ref/2.1.0/netstandard.dll"
NUNIT="$(ls "$UNITY_DATA"/Resources/PackageManager/BuiltInPackages/com.unity.ext.nunit/net40/unity-custom/nunit.framework.dll 2>/dev/null | head -1)"

if [ ! -f "$CSC" ]; then
    echo "Roslyn not found at $CSC" >&2
    exit 2
fi

# --- real package assemblies, or stubs as a fallback ------------------------
USE_STUBS=0
[ "${1:-}" = "--stubs" ] && USE_STUBS=1
if [ "$USE_STUBS" = 0 ] && [ ! -f "$PKG/UnityEngine.UI.dll" ]; then
    echo "note: no imported package assemblies in $PKG — falling back to stubs."
    echo "      (Open $LIVE once in Unity to check against the real uGUI and TMP APIs.)"
    USE_STUBS=1
fi

echo "Unity data : $UNITY_DATA"
if [ "$USE_STUBS" = 1 ]; then
    echo "UI/TMP     : stubs (Tools/CompileCheck)"
else
    echo "UI/TMP     : real package assemblies from $PKG"
fi

# Extra reference lines set by the caller before a pass (kept as a string so
# bash quoting survives into the response file).
EXTRA_REFS=""

refs() {
    if [ "${WITH_TESTS:-0}" = 1 ]; then
        # nunit.framework.dll is a net40 assembly built against mscorlib, so the
        # test pass uses the mono profile with the netstandard facade on top of
        # it rather than the netstandard reference alone.
        local mono_api
        mono_api="$(ls -d "$UNITY_DATA"/MonoBleedingEdge/lib/mono/4.7.1-api 2>/dev/null | head -1)"
        if [ -n "$mono_api" ]; then
            echo "-r:\"$mono_api/mscorlib.dll\""
            echo "-r:\"$mono_api/System.dll\""
            echo "-r:\"$mono_api/System.Core.dll\""
            [ -f "$mono_api/Facades/netstandard.dll" ] && echo "-r:\"$mono_api/Facades/netstandard.dll\""
        else
            echo "-r:\"$NETSTANDARD\""
        fi
    else
        echo "-r:\"$NETSTANDARD\""
    fi
    for dll in "$UNITY_DATA"/Managed/UnityEngine/UnityEngine*.dll; do
        echo "-r:\"$dll\""
    done
    if [ "$USE_STUBS" = 0 ]; then
        for dll in UnityEngine.UI Unity.TextMeshPro Unity.InputSystem; do
            [ -f "$PKG/$dll.dll" ] && echo "-r:\"$PKG/$dll.dll\""
        done
    fi
    [ -n "$EXTRA_REFS" ] && echo "$EXTRA_REFS"
    return 0
}

# --- one compilation pass ---------------------------------------------------
failures=0

compile() {
    local label="$1" srcroot="$2" define_editor="$3" with_tests="$4"
    local rsp="$OUT/$label.rsp"

    [ -d "$srcroot" ] || { echo "skip $label (no sources at $srcroot)"; return 0; }

    WITH_TESTS="$with_tests"

    : > "$rsp"
    {
        echo "-target:library"
        echo "-nostdlib+"
        echo "-langversion:9"
        # 0169/0414/0649/0067/0219: fields assigned in the Editor or by Unity's
        # serializer. 1030: unreachable code from #if branches.
        echo "-nowarn:0169,0414,0649,0067,0219,1030"
        echo "-out:\"$OUT/$label.dll\""
        refs

        if [ "$define_editor" = 1 ]; then
            echo "-define:UNITY_EDITOR"
            [ -f "$UNITY_DATA/Managed/UnityEditor.dll" ] && echo "-r:\"$UNITY_DATA/Managed/UnityEditor.dll\""
            [ -f "$PKG/Unity.TextMeshPro.Editor.dll" ] && echo "-r:\"$PKG/Unity.TextMeshPro.Editor.dll\""
            [ -f "$PKG/UnityEditor.UI.dll" ] && echo "-r:\"$PKG/UnityEditor.UI.dll\""
        fi

        if [ "$with_tests" = 1 ]; then
            echo "-define:UNITY_INCLUDE_TESTS"
            [ -f "$PKG/UnityEngine.TestRunner.dll" ] && echo "-r:\"$PKG/UnityEngine.TestRunner.dll\""
            [ -f "$PKG/UnityEditor.TestRunner.dll" ] && echo "-r:\"$PKG/UnityEditor.TestRunner.dll\""
            [ -n "$NUNIT" ] && echo "-r:\"$NUNIT\""
        fi

        # Stubs, when used, are sources: they provide the missing types.
        if [ "$USE_STUBS" = 1 ]; then
            for stub in "$HERE"/CompileCheck/*.cs; do
                [ -e "$stub" ] && echo "\"$(cygpath -m "$stub" 2>/dev/null || echo "$stub")\""
            done
        fi

        find "$srcroot" -name '*.cs' | while read -r src; do
            echo "\"$(cygpath -m "$src" 2>/dev/null || echo "$src")\""
        done
    } >> "$rsp"

    if "$MONO" "$CSC" -noconfig @"$rsp"; then
        echo "  ok    $label"
    else
        echo "  FAIL  $label"
        failures=$((failures + 1))
    fi

    rm -f "$rsp"
}

echo
echo "Compiling:"
# The dev copy is the historical tree; the live project is what ships.
compile "dev-copy" "$DEV/Assets/Scripts" 0 0
compile "live-runtime" "$LIVE/Assets/Scripts" 0 0
compile "live-editor" "$LIVE/Assets/Scripts" 1 0

# The tests are their own assembly and reference the runtime one, exactly as the
# assembly definitions describe; the compile above left that DLL in place for it.
EXTRA_REFS="-r:\"$OUT/live-runtime.dll\""
compile "live-tests" "$LIVE/Assets/Tests" 0 1
EXTRA_REFS=""

rm -f "$OUT"/*.dll

echo
if [ "$failures" -eq 0 ]; then
    echo "All passes clean."
else
    echo "$failures pass(es) failed."
fi
exit "$failures"
