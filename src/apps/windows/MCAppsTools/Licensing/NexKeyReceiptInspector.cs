using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace MCAppsTools
{
    public sealed record NexKeyReceiptInfo(string Variant, string ActivationId);

    public static class NexKeyReceiptInspector
    {
        public static NexKeyReceiptInfo? DeduceReceipt(string tenantIdOrProductId, string productName)
        {
            if (string.IsNullOrWhiteSpace(productName))
            {
                return null;
            }

            var targetName = productName.Trim();
            var targetSlug = new string(targetName.Where(char.IsLetterOrDigit).ToArray()).ToLowerInvariant();
            if (string.IsNullOrEmpty(targetSlug))
            {
                return null;
            }

            var candidateReceiptDirs = new List<string>();
            var baseRoots = new List<string>();

            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (!string.IsNullOrEmpty(localAppData))
            {
                baseRoots.Add(Path.Combine(localAppData, "NexKeyRuntime"));
            }

            var commonAppData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            if (!string.IsNullOrEmpty(commonAppData))
            {
                baseRoots.Add(Path.Combine(commonAppData, "NexKeyRuntime"));
            }

            var tenantFilter = tenantIdOrProductId?.Trim();

            foreach (var baseDir in baseRoots)
            {
                if (!Directory.Exists(baseDir))
                {
                    continue;
                }

                if (!string.IsNullOrEmpty(tenantFilter))
                {
                    var specificReceiptsDir = Path.Combine(baseDir, tenantFilter, "receipts");
                    if (Directory.Exists(specificReceiptsDir))
                    {
                        candidateReceiptDirs.Add(specificReceiptsDir);
                    }
                }

                try
                {
                    var tenantDirs = Directory.GetDirectories(baseDir);
                    foreach (var tDir in tenantDirs)
                    {
                        var rDir = Path.Combine(tDir, "receipts");
                        if (Directory.Exists(rDir) && !candidateReceiptDirs.Contains(rDir, StringComparer.OrdinalIgnoreCase))
                        {
                            candidateReceiptDirs.Add(rDir);
                        }
                    }
                }
                catch
                {
                    // Best-effort directory scan
                }
            }

            foreach (var receiptsDir in candidateReceiptDirs)
            {
                try
                {
                    var jsonFiles = Directory.GetFiles(receiptsDir, "*.json");
                    foreach (var filePath in jsonFiles)
                    {
                        var receiptInfo = ParseReceiptFile(filePath, targetSlug);
                        if (receiptInfo != null)
                        {
                            return receiptInfo;
                        }
                    }
                }
                catch
                {
                    // Ignore I/O errors on individual directory
                }
            }

            return null;
        }

        private static NexKeyReceiptInfo? ParseReceiptFile(string filePath, string targetSlug)
        {
            try
            {
                var content = File.ReadAllText(filePath);
                using var doc = JsonDocument.Parse(content);
                var root = doc.RootElement;

                if (!root.TryGetProperty("payload", out var payloadElement) ||
                    payloadElement.GetString() is not { } payloadB64 ||
                    string.IsNullOrEmpty(payloadB64))
                {
                    return null;
                }

                var payloadBytes = DecodeBase64Url(payloadB64);
                if (payloadBytes == null)
                {
                    return null;
                }

                using var payloadDoc = JsonDocument.Parse(payloadBytes);
                var pRoot = payloadDoc.RootElement;

                if (!pRoot.TryGetProperty("entitlement", out var entElem) ||
                    entElem.GetString() is not { } entitlement ||
                    string.IsNullOrEmpty(entitlement))
                {
                    return null;
                }

                if (!pRoot.TryGetProperty("activationId", out var actElem) ||
                    actElem.GetString() is not { } activationId ||
                    string.IsNullOrEmpty(activationId))
                {
                    return null;
                }

                var entSlug = new string(
                    entitlement.Replace("download:", "", StringComparison.OrdinalIgnoreCase)
                        .Where(char.IsLetterOrDigit)
                        .ToArray()
                ).ToLowerInvariant();

                if (!string.IsNullOrEmpty(entSlug) &&
                    (entSlug == targetSlug || targetSlug.Contains(entSlug, StringComparison.Ordinal) || entSlug.Contains(targetSlug, StringComparison.Ordinal)))
                {
                    return new NexKeyReceiptInfo(entitlement, activationId);
                }
            }
            catch
            {
                // Ignore parse errors on corrupt or non-matching receipts
            }

            return null;
        }

        private static byte[]? DecodeBase64Url(string base64Url)
        {
            try
            {
                var base64 = base64Url.Replace('-', '+').Replace('_', '/');
                var rem = base64.Length % 4;
                if (rem > 0)
                {
                    base64 += new string('=', 4 - rem);
                }
                return Convert.FromBase64String(base64);
            }
            catch
            {
                return null;
            }
        }
    }
}
