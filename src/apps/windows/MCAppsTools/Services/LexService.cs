using System;
using System.IO;
using System.Reflection;
using System.Threading.Tasks;
using Cryptlex;

namespace MCAppsTools
{
    public sealed class LexService
    {
        private static readonly object ConfigureLock = new();
        private static bool _isConfigured;

        public bool IsActivated(string productId, string? productData)
        {
            return SyncStatus(productId, productData) == SdkLicenseStatus.Active;
        }

        public SdkLicenseStatus SyncStatus(string productId, string? productData)
        {
            try
            {
                ConfigureLexActivatorRuntime();
                InitializeProduct(productId, productData);
                var status = InvokeLexStatusMethod("SyncLicenseActivation") ?? LexActivator.IsLicenseGenuine();
                return MapValidationStatus(status);
            }
            catch
            {
                return SdkLicenseStatus.Unknown;
            }
        }

        public SdkLicenseStatus CachedStatus(string productId, string? productData)
        {
            try
            {
                ConfigureLexActivatorRuntime();
                InitializeProduct(productId, productData);
                var status = LexActivator.IsLicenseGenuine();
                return MapValidationStatus(status);
            }
            catch
            {
                return SdkLicenseStatus.Unknown;
            }
        }

        private static void InitializeProduct(string productId, string? productData)
        {
            if (!string.IsNullOrWhiteSpace(productData))
            {
                LexActivator.SetProductData(productData!);
            }
            LexActivator.SetProductId(productId, LexActivator.PermissionFlags.LA_USER);
        }

        public async Task<bool> ActivateAsync(string productId, string signedKey, string? productData, string machineFingerprint)
        {
            return await Task.Run(() =>
            {
                try
                {
                    ConfigureLexActivatorRuntime();
                    var originalKey = signedKey.Trim();
                    if (originalKey.Length > 2)
                    {
                        originalKey = originalKey.Substring(0, originalKey.Length - 2);
                    }

                    if (!string.IsNullOrWhiteSpace(productData))
                    {
                        LexActivator.SetProductData(productData!);
                    }
                    LexActivator.SetProductId(productId, LexActivator.PermissionFlags.LA_USER);

                    if (IsSameLicenseAlreadyActive(originalKey))
                    {
                        return true;
                    }

                    LexActivator.SetLicenseKey(originalKey);
                    InvokeOptionalLexMethod("SetActivationMetadata", "app", "MCAppsTools");
                    InvokeOptionalLexMethod("SetActivationMetadata", "hostname", Environment.MachineName);
                    if (!string.IsNullOrWhiteSpace(machineFingerprint))
                    {
                        InvokeOptionalLexMethod("SetActivationMetadata", "machineFingerprint", machineFingerprint);
                    }

                    var status = LexActivator.ActivateLicense();
                    if (status == LexStatusCodes.LA_OK)
                    {
                        return true;
                    }

                    throw new InvalidOperationException($"LexActivator activation failed: {LexStatusMessage(status)}");
                }
                catch (InvalidOperationException)
                {
                    throw;
                }
                catch (LexActivatorException ex)
                {
                    throw new InvalidOperationException($"LexActivator activation failed: {LexExceptionMessage(ex)}", ex);
                }
                catch (Exception ex)
                {
                    throw new InvalidOperationException($"LexActivator activation failed: {ex.Message}", ex);
                }
            });
        }

        public void Deactivate(string productId, string? productData)
        {
            try
            {
                ConfigureLexActivatorRuntime();
                if (!string.IsNullOrWhiteSpace(productData))
                {
                    LexActivator.SetProductData(productData!);
                }
                LexActivator.SetProductId(productId, LexActivator.PermissionFlags.LA_USER);
                LexActivator.DeactivateLicense();
            }
            catch
            {
                // Suppress
            }
        }

        private static void ConfigureLexActivatorRuntime()
        {
            lock (ConfigureLock)
            {
                if (_isConfigured)
                {
                    return;
                }

                try
                {
                    var dataDirectory = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                        "MCAppsTools");
                    Directory.CreateDirectory(dataDirectory);

                    InvokeOptionalLexMethod("SetDataDirectory", dataDirectory);
                    InvokeOptionalLexMethod("SetCacheMode", 0u);
                }
                catch
                {
                    // The SDK default cache remains usable if optional configuration is unavailable.
                }
                finally
                {
                    _isConfigured = true;
                }
            }
        }

        private static void InvokeOptionalLexMethod(string methodName, object argument)
        {
            var method = typeof(LexActivator).GetMethod(
                methodName,
                BindingFlags.Public | BindingFlags.Static);
            method?.Invoke(null, new[] { argument });
        }

        private static void InvokeOptionalLexMethod(string methodName, object firstArgument, object secondArgument)
        {
            var method = typeof(LexActivator).GetMethod(
                methodName,
                BindingFlags.Public | BindingFlags.Static,
                binder: null,
                types: new[] { firstArgument.GetType(), secondArgument.GetType() },
                modifiers: null);
            method?.Invoke(null, new[] { firstArgument, secondArgument });
        }

        private static bool IsSameLicenseAlreadyActive(string licenseKey)
        {
            try
            {
                var method = typeof(LexActivator).GetMethod(
                    "GetLicenseKey",
                    BindingFlags.Public | BindingFlags.Static,
                    binder: null,
                    types: Type.EmptyTypes,
                    modifiers: null);
                var activeKey = method?.Invoke(null, null) as string;
                return string.Equals(activeKey, licenseKey, StringComparison.OrdinalIgnoreCase)
                    && LexActivator.IsLicenseGenuine() == LexStatusCodes.LA_OK;
            }
            catch
            {
                return false;
            }
        }

        private static int? InvokeLexStatusMethod(string methodName)
        {
            var method = typeof(LexActivator).GetMethod(
                methodName,
                BindingFlags.Public | BindingFlags.Static,
                binder: null,
                types: Type.EmptyTypes,
                modifiers: null);
            var result = method?.Invoke(null, null);
            return result is null ? null : Convert.ToInt32(result);
        }

        private static SdkLicenseStatus MapValidationStatus(int status)
        {
            return status switch
            {
                0 => SdkLicenseStatus.Active,
                22 => SdkLicenseStatus.Active,
                21 => SdkLicenseStatus.Suspended,
                20 => SdkLicenseStatus.Expired,
                53 => SdkLicenseStatus.Revoked,
                1 => SdkLicenseStatus.NotActivated,
                _ => SdkLicenseStatus.Unknown
            };
        }

        private static string LexStatusMessage(int status)
        {
            var name = status switch
            {
                0 => "LA_OK",
                1 => "LA_FAIL",
                20 => "LA_EXPIRED",
                21 => "LA_SUSPENDED",
                40 => "LA_E_FILE_PATH",
                41 => "LA_E_PRODUCT_FILE",
                42 => "LA_E_PRODUCT_DATA",
                43 => "LA_E_PRODUCT_ID",
                44 => "LA_E_SYSTEM_PERMISSION",
                45 => "LA_E_FILE_PERMISSION",
                46 => "LA_E_WMIC",
                47 => "LA_E_TIME",
                48 => "LA_E_INET",
                53 => "LA_E_REVOKED",
                54 => "LA_E_LICENSE_KEY",
                55 => "LA_E_LICENSE_TYPE",
                58 => "LA_E_ACTIVATION_LIMIT",
                63 => "LA_E_MACHINE_FINGERPRINT",
                69 => "LA_E_TIME_MODIFIED",
                71 => "LA_E_AUTHENTICATION_FAILED",
                80 => "LA_E_VM",
                81 => "LA_E_COUNTRY",
                82 => "LA_E_IP",
                90 => "LA_E_RATE_LIMIT",
                91 => "LA_E_SERVER",
                92 => "LA_E_CLIENT",
                104 => "LA_E_OS_USER",
                106 => "LA_E_FREE_PLAN_ACTIVATION_LIMIT_REACHED",
                _ => "LA_STATUS_UNKNOWN"
            };
            return $"{name} ({status})";
        }

        private static string LexExceptionMessage(LexActivatorException exception)
        {
            if (exception.Message.Contains("allowed activations limit", StringComparison.OrdinalIgnoreCase))
            {
                return "No activations are available for this license. Deactivate a previous machine or increase the activation limit in Cryptlex.";
            }

            return exception.Message;
        }
    }
}
