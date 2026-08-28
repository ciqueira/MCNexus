using System.Runtime.InteropServices;
using System.Text;

namespace MCAppsTools
{
    /// <summary>
    /// Tells a Store-installed (MSIX) process apart from a Setup-installed
    /// one, without a WinRT/UWP reference: <c>GetCurrentPackageFullName</c>
    /// returns <c>APPMODEL_ERROR_NO_PACKAGE</c> only for an unpackaged
    /// process. Used to decide which Store deep link to open on app-update
    /// click — see <c>MainWindow.xaml.cs.AppUpdate_Click</c>.
    /// </summary>
    public static class AppPackageIdentity
    {
        private const int ApiErrorNoPackage = 15700;

        [DllImport("kernel32.dll")]
        private static extern int GetCurrentPackageFullName(ref int packageFullNameLength, StringBuilder? packageFullName);

        public static bool IsStoreInstalled()
        {
            var length = 0;
            var result = GetCurrentPackageFullName(ref length, null);
            return result != ApiErrorNoPackage;
        }
    }
}
