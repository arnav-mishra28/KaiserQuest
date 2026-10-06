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

# macOS keeps the editor inside an app bundle, and its managed assemblies under
# Resources/Scripting rather than Data/. Probe the Hub's install root so a plain
# `bash Tools/compile-check.sh` works on a Mac with no flags set.
if [ -z "$UNITY_DATA" ]; then
    for root in "$HOME/Unity/Hub/Editor" "/Applications/Unity/Hub/Editor"; do
        [ -d "$root" ] || continue
        for version in "$root"/*; do
            [ -d "$version" ] || continue
            if [ -d "$version/Unity.app/Contents/Resources/Scripting/Managed/UnityEngine" ]; then
                UNITY_DATA="$version/Unity.app/Contents/Resources/Scripting"
                break 2
            fi
            if [ -d "$version/Editor/Data/Managed/UnityEngine" ]; then
                UNITY_DATA="$version/Editor/Data"
                break 2
            fi
        done
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

# The mono profile to compile against when the editor brings no NetStandard ref
# folder — which is the case for Unity 6 on macOS, whose app bundle carries the
# runtime assemblies but neither a compiler nor the netstandard reference set.
MONO_API=""
for candidate in \
    "$UNITY_DATA"/MonoBleedingEdge/lib/mono/4.7.1-api \
    "${MONO_PREFIX:-/opt/homebrew}"/lib/mono/4.7.1-api \
    /usr/lib/mono/4.7.1-api \
    /Library/Frameworks/Mono.framework/Versions/Current/lib/mono/4.7.1-api; do
    if [ -f "$candidate/mscorlib.dll" ]; then MONO_API="$candidate"; break; fi
done

# Prefer the editor's own Roslyn; fall back to a system Mono, which is the only
# way to typecheck the tree on a machine whose Unity install has none.
RUN_CSC=()
if [ -f "$CSC" ]; then
    RUN_CSC=("$MONO" "$CSC")
else
    SYSTEM_CSC="$(command -v csc || true)"
    if [ -n "$SYSTEM_CSC" ]; then
        # Homebrew's csc is a launcher script, so it is run on its own rather
        # than handed to an interpreter.
        RUN_CSC=("$SYSTEM_CSC")
        echo "note: no Roslyn in the Unity install — compiling with $SYSTEM_CSC"
    fi
fi

if [ "${#RUN_CSC[@]}" -eq 0 ]; then
    echo "No C# compiler found. Point UNITY_DATA at a complete Unity install, or run:" >&2
    echo "    brew install mono" >&2
    exit 2
fi

# A nunit.framework the developer fetched into the (ignored) build directory.
# Checked only after the editor's own bundled copy, which always wins.
if [ -z "$NUNIT" ]; then
    NUNIT="$(ls "$HERE"/out/nunit/nunit.framework.dll 2>/dev/null | head -1)"
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
if [ -n "$NUNIT" ]; then
    echo "NUnit      : $NUNIT"
else
    echo "NUnit      : NOT FOUND — the test pass will be skipped."
    echo "             Fetch one into Tools/out/nunit/nunit.framework.dll, or from NuGet:"
    echo "             curl -sSL -o n.nupkg https://api.nuget.org/v3-flatcontainer/nunit/3.5.0/nunit.3.5.0.nupkg"
fi

# Extra reference lines set by the caller before a pass (kept as a string so
# bash quoting survives into the response file).
EXTRA_REFS=""

# The base class library to compile against. Unity's NetStandard reference set is
# preferred; a Mono install supplies the equivalent profile when the editor ships
# none (Unity 6 on macOS).
stdlib_refs() {
    if [ -f "$NETSTANDARD" ]; then
        echo "-r:\"$NETSTANDARD\""
    elif [ -n "$MONO_API" ]; then
        echo "-r:\"$MONO_API/mscorlib.dll\""
        echo "-r:\"$MONO_API/System.dll\""
        echo "-r:\"$MONO_API/System.Core.dll\""
        [ -f "$MONO_API/Facades/netstandard.dll" ] && echo "-r:\"$MONO_API/Facades/netstandard.dll\""
    fi
    return 0
}

# Some installs ship a UnityEditor.dll the compiler outside the Editor cannot read
# (Unity 6 on macOS: the 13 MB assembly is rejected as "PE image doesn't contain
# managed metadata"). Editor code cannot be typechecked without it, so find out
# once with a one-line probe and skip that pass rather than reporting a failure of
# the code that is really a gap in the install.
editor_assembly_usable() {
    [ -f "$UNITY_DATA/Managed/UnityEditor.dll" ] || return 1

    local src="$OUT/editor-probe.cs" dll="$OUT/editor-probe.dll" rsp="$OUT/editor-probe.rsp"
    printf 'namespace KaiserQuest.CompileProbe { internal static class P { } }\n' > "$src"
    {
        echo "-target:library"
        echo "-nostdlib+"
        echo "-nologo"
        echo "-nowarn:0169,0414,0649,0067,0219,1030"
        echo "-out:\"$dll\""
        stdlib_refs
        echo "-r:\"$UNITY_DATA/Managed/UnityEditor.dll\""
        echo "\"$src\""
    } > "$rsp"

    local status=0
    "${RUN_CSC[@]}" -noconfig @"$rsp" >/dev/null 2>&1 || status=1
    rm -f "$src" "$dll" "$rsp"
    return $status
}

refs() {
    if [ "${WITH_TESTS:-0}" = 1 ] || [ ! -f "$NETSTANDARD" ]; then
        # nunit.framework.dll is a net40 assembly built against mscorlib, so the
        # test pass uses the mono profile with the netstandard facade on top of
        # it rather than the netstandard reference alone. An install with no
        # NetStandard/ref folder needs the same treatment for its runtime passes.
        local mono_api
        mono_api="$(ls -d "$UNITY_DATA"/MonoBleedingEdge/lib/mono/4.7.1-api 2>/dev/null | head -1)"
        [ -z "$mono_api" ] && mono_api="$MONO_API"
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
        # The test-framework stub is deliberately not part of this set — it is
        # included below, for the test pass only, so it can never shadow the real
        # attributes the tests are meant to be checked against, and never ends up
        # inside the runtime assembly.
        if [ "$USE_STUBS" = 1 ]; then
            for stub in "$HERE"/CompileCheck/*.cs; do
                case "$stub" in
                    *TestTools*) continue ;;
                esac
                [ -e "$stub" ] && echo "\"$(cygpath -m "$stub" 2>/dev/null || echo "$stub")\""
            done
        fi

        if [ "$with_tests" = 1 ] && [ ! -f "$PKG/UnityEngine.TestRunner.dll" ]; then
            local tests_stub="$HERE/CompileCheck/Stubs UnityEngine.TestTools.cs"
            [ -e "$tests_stub" ] && echo "\"$(cygpath -m "$tests_stub" 2>/dev/null || echo "$tests_stub")\""
        fi

        find "$srcroot" -name '*.cs' | while read -r src; do
            echo "\"$(cygpath -m "$src" 2>/dev/null || echo "$src")\""
        done
    } >> "$rsp"

    if "${RUN_CSC[@]}" -noconfig @"$rsp"; then
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
if editor_assembly_usable; then
    compile "live-editor" "$LIVE/Assets/Scripts" 1 0
else
    echo "  skip  live-editor (this install's UnityEditor.dll cannot be referenced)"
fi

# The tests are their own assembly and reference the runtime one, exactly as the
# assembly definitions describe; the compile above left that DLL in place for it.
# Without an NUnit assembly there is nothing to check the suite against, so the
# pass is reported as skipped rather than silently counted as clean.
if [ -n "$NUNIT" ]; then
    EXTRA_REFS="-r:\"$OUT/live-runtime.dll\""
    compile "live-tests" "$LIVE/Assets/Tests" 0 1
    EXTRA_REFS=""
else
    echo "  skip  live-tests (no nunit.framework available)"
fi

rm -f "$OUT"/*.dll

echo
if [ "$failures" -eq 0 ]; then
    echo "All passes clean."
else
    echo "$failures pass(es) failed."
fi
exit "$failures"
