// Verification-only stubs for the Unity Test Framework's PlayMode attributes.
//
// They live outside Assets/, exactly like the uGUI and TMP stubs, so the harness
// can typecheck the PlayMode suite on a machine whose Unity install carries no
// `UnityEngine.TestRunner` assembly. Inside the Editor the real attributes always
// win, because these are only added to the response file when the package
// assemblies are missing.
//
// They derive from System.Attribute rather than NUnit's NUnitAttribute on
// purpose: these three are compiled into the *runtime* pass as well, which has no
// reference to nunit.framework. The real attributes are themselves only markers,
// so a plain Attribute preserves everything the compiler can check.
using System;

namespace UnityEngine.TestTools
{
    /// <summary>Marks a coroutine test. Stub for the Editor's UnityTestAttribute.</summary>
    [AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
    public sealed class UnityTestAttribute : Attribute
    {
    }

    /// <summary>Marks a coroutine set-up step. Stub for UnitySetUpAttribute.</summary>
    [AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
    public sealed class UnitySetUpAttribute : Attribute
    {
    }

    /// <summary>Marks a coroutine tear-down step. Stub for UnityTearDownAttribute.</summary>
    [AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
    public sealed class UnityTearDownAttribute : Attribute
    {
    }
}
