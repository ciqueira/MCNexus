using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace MCAppsTools
{
    public sealed class AppBackendService
    {
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
        {
            WriteIndented = false
        };

        private readonly HttpClient _httpClient;
        private DateTimeOffset? _rateLimitedUntil;

        public DateTimeOffset? RateLimitedUntil => _rateLimitedUntil;

        public AppBackendService()
            : this(new HttpClient(), new SessionTokenStore())
        {
        }

        public AppBackendService(string machineFingerprint)
            : this(new HttpClient(), new SessionTokenStore(new AppPaths(), machineFingerprint))
        {
        }

        public AppBackendService(HttpClient httpClient, SessionTokenStore sessionTokens)
        {
            _httpClient = httpClient;
            SessionTokens = sessionTokens;
        }

        public SessionTokenStore SessionTokens { get; }

        public Task<HealthResponseDto> CheckHealthAsync(CancellationToken cancellationToken = default)
        {
            return GetAsync<HealthResponseDto>("/v1/health", AppBackendEndpointConfig.Health, null, cancellationToken);
        }

        public Task<AppLatestResponseDto> FetchLatestAppAsync(string platform = "windows", CancellationToken cancellationToken = default)
        {
            return GetAsync<AppLatestResponseDto>(
                "/v1/app/latest",
                AppBackendEndpointConfig.AppLatest,
                new Dictionary<string, string?> { ["platform"] = platform },
                cancellationToken);
        }

        public Task<ValidateInstallationResponseDto> ValidateInstallationAsync(
            ValidateInstallationRequestDto request,
            CancellationToken cancellationToken = default)
        {
            return PostAsync<ValidateInstallationRequestDto, ValidateInstallationResponseDto>(
                "/v1/licenses/validate-installation",
                request,
                null,
                AppBackendEndpointConfig.Validate,
                cancellationToken);
        }

        public Task<SyncLicenseResponseDto> SyncLicenseAsync(
            SyncLicenseRequestDto request,
            string? sessionToken,
            CancellationToken cancellationToken = default)
        {
            return PostAsync<SyncLicenseRequestDto, SyncLicenseResponseDto>(
                "/v1/licenses/sync",
                request,
                sessionToken,
                AppBackendEndpointConfig.Sync,
                cancellationToken);
        }

        public Task<SyncBatchResponseDto> SyncBatchAsync(
            SyncBatchRequestDto request,
            CancellationToken cancellationToken = default)
        {
            return PostAsync<SyncBatchRequestDto, SyncBatchResponseDto>(
                "/v1/licenses/sync-batch",
                request,
                null,
                AppBackendEndpointConfig.SyncBatch,
                cancellationToken);
        }

        /// <summary>
        /// Fase 5 / D42 — unifies this machine's legacy activation identity
        /// with the one the SDK computes. Call once, at the last
        /// installation step, immediately before the SDK's own activate,
        /// never earlier: the JWT that authenticates this call comes from
        /// validate-installation, and the route derives the legacy identity
        /// from the SESSION, never the request body. Best-effort by
        /// contract (D42 — "always 200"): the caller must swallow transport
        /// failures rather than block activation on them.
        /// </summary>
        public Task<MigrateBindingResponseDto> MigrateBindingAsync(
            string hardwareId,
            string sessionToken,
            CancellationToken cancellationToken = default)
        {
            return PostAsync<MigrateBindingRequestDto, MigrateBindingResponseDto>(
                "/v1/licenses/migrate-binding",
                new MigrateBindingRequestDto { HardwareId = hardwareId },
                sessionToken,
                AppBackendEndpointConfig.MigrateBinding,
                cancellationToken);
        }

        public Task<ResolveDownloadResponseDto> ResolveDownloadAsync(
            string releaseId,
            ResolveDownloadRequestDto request,
            string? sessionToken,
            CancellationToken cancellationToken = default)
        {
            var encodedReleaseId = Uri.EscapeDataString(releaseId);
            return PostAsync<ResolveDownloadRequestDto, ResolveDownloadResponseDto>(
                $"/v1/releases/{encodedReleaseId}/resolve-download",
                request,
                sessionToken,
                AppBackendEndpointConfig.ResolveDownload,
                cancellationToken);
        }

        public async Task<string> DownloadFileAsync(
            string url,
            string suggestedName,
            IProgress<DownloadProgress>? progress = null,
            CancellationToken cancellationToken = default)
        {
            var downloadUri = ResolveDownloadUri(url);
            using var response = await _httpClient.GetAsync(
                downloadUri,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            response.EnsureSuccessStatusCode();

            var tempDirectory = Path.Combine(Path.GetTempPath(), "MCAppsTools");
            Directory.CreateDirectory(tempDirectory);
            var destinationPath = Path.Combine(tempDirectory, SanitizedDownloadFileName(suggestedName));
            var totalBytes = response.Content.Headers.ContentLength ?? 0;
            var writtenBytes = 0L;

            await using var source = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var destination = File.Create(destinationPath);
            var buffer = new byte[81920];

            while (true)
            {
                var read = await source.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
                if (read == 0)
                {
                    break;
                }

                await destination.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                writtenBytes += read;
                progress?.Report(new DownloadProgress(
                    totalBytes > 0 ? (double)writtenBytes / totalBytes : 0,
                    writtenBytes,
                    totalBytes));
            }

            return destinationPath;
        }

        private Task<TResponse> GetAsync<TResponse>(
            string path,
            AppBackendEndpointConfig config,
            IReadOnlyDictionary<string, string?>? query,
            CancellationToken cancellationToken)
        {
            var request = BuildRequest(path, HttpMethod.Get, null, query);
            return SendWithRetryAsync<TResponse>(request, path, config, cancellationToken);
        }

        private Task<TResponse> PostAsync<TBody, TResponse>(
            string path,
            TBody body,
            string? sessionToken,
            AppBackendEndpointConfig config,
            CancellationToken cancellationToken)
        {
            var request = BuildRequest(path, HttpMethod.Post, sessionToken, null);
            request.Content = new StringContent(JsonSerializer.Serialize(body, JsonOptions), Encoding.UTF8, "application/json");
            return SendWithRetryAsync<TResponse>(request, path, config, cancellationToken);
        }

        private static HttpRequestMessage BuildRequest(
            string path,
            HttpMethod method,
            string? sessionToken,
            IReadOnlyDictionary<string, string?>? query)
        {
            var uri = BuildUri(path, query);
            var request = new HttpRequestMessage(method, uri);
            request.Headers.Accept.ParseAdd("application/json");
            request.Headers.TryAddWithoutValidation("X-App-Version", AppBackendConfiguration.AppVersion);

            // Fase 5 (D41/P34). Declares that this build embeds NexKeyRuntime
            // and will call /v1/sdk/licenses/activate itself — its absence is
            // what every MCNexus released before the bridge is identified by,
            // so this must go out on EVERY request, not just licensing ones,
            // the same single point macOS's buildRequest uses.
            request.Headers.TryAddWithoutValidation("X-NexKey-Capabilities", "nexkeyruntime-sdk");
            request.Headers.TryAddWithoutValidation(
                "X-NexKey-Platform",
                $"windows-{System.Runtime.InteropServices.RuntimeInformation.OSArchitecture.ToString().ToLowerInvariant()}");

            if (!string.IsNullOrWhiteSpace(sessionToken))
            {
                request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", sessionToken);
            }

            return request;
        }

        private static Uri BuildUri(string path, IReadOnlyDictionary<string, string?>? query)
        {
            if (!path.StartsWith("/", StringComparison.Ordinal))
            {
                path = "/" + path;
            }

            var builder = new UriBuilder(new Uri(AppBackendConfiguration.BaseUri, path));
            if (query is { Count: > 0 })
            {
                var pairs = new List<string>();
                foreach (var item in query)
                {
                    if (item.Value is null)
                    {
                        continue;
                    }

                    pairs.Add($"{Uri.EscapeDataString(item.Key)}={Uri.EscapeDataString(item.Value)}");
                }

                builder.Query = string.Join("&", pairs);
            }

            return builder.Uri;
        }

        private async Task<TResponse> SendWithRetryAsync<TResponse>(
            HttpRequestMessage request,
            string path,
            AppBackendEndpointConfig config,
            CancellationToken cancellationToken)
        {
            System.Diagnostics.Debug.WriteLine($"[MCBackend API Request] {request.Method} {path}");

            using (request)
            {
                EnforceRateLimitCooldown();

                for (var attempt = 1; ; attempt++)
                {
                    using var attemptRequest = CloneRequest(request);
                    using var timeoutSource = new CancellationTokenSource(config.Timeout);
                    using var linkedSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutSource.Token);

                    try
                    {
                        var result = await PerformHttpRequestAsync<TResponse>(attemptRequest, linkedSource.Token);
                        if (attempt > 1)
                        {
                            System.Diagnostics.Debug.WriteLine($"[MCBackend API Success] {path} succeeded on attempt {attempt}");
                        }
                        return result;
                    }
                    catch (AppBackendException error) when (attempt < config.MaxAttempts && IsRetryable(error))
                    {
                        System.Diagnostics.Debug.WriteLine($"[MCBackend API Error] {path} failed (Attempt {attempt}): {error.Message}. Retrying...");
                        var delay = TimeSpan.FromMilliseconds(config.InitialBackoff.TotalMilliseconds * Math.Pow(2, attempt - 1));
                        await Task.Delay(delay, cancellationToken);
                    }
                    catch (OperationCanceledException error) when (!cancellationToken.IsCancellationRequested && attempt < config.MaxAttempts)
                    {
                        System.Diagnostics.Debug.WriteLine($"[MCBackend API Timeout] {path} timed out (Attempt {attempt}). Retrying...");
                        var delay = TimeSpan.FromMilliseconds(config.InitialBackoff.TotalMilliseconds * Math.Pow(2, attempt - 1));
                        await Task.Delay(delay, cancellationToken);
                        _ = error;
                    }
                    catch (OperationCanceledException error) when (!cancellationToken.IsCancellationRequested)
                    {
                        System.Diagnostics.Debug.WriteLine($"[MCBackend API Fatal] {path} timed out permanently.");
                        throw new AppBackendException(AppBackendErrorKind.Transport, $"Request timed out for {path}.", error);
                    }
                }
            }
        }

        private async Task<TResponse> PerformHttpRequestAsync<TResponse>(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            HttpResponseMessage response;
            try
            {
                response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            }
            catch (HttpRequestException error)
            {
                throw new AppBackendException(AppBackendErrorKind.Transport, error.Message, error);
            }
            catch (TaskCanceledException error)
            {
                throw new AppBackendException(AppBackendErrorKind.Transport, "Request timed out.", error);
            }

            using var responseToDispose = response;
            var data = await response.Content.ReadAsByteArrayAsync(cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var payload = TryDecodeError(data);
                if (response.StatusCode == HttpStatusCode.TooManyRequests)
                {
                    RegisterRateLimit(response.Headers.RetryAfter?.ToString());
                }

                throw new AppBackendException(
                    AppBackendErrorKind.Http,
                    $"Backend returned {(int)response.StatusCode}.",
                    statusCode: response.StatusCode,
                    payload: payload);
            }

            try
            {
                var decoded = JsonSerializer.Deserialize<TResponse>(data, JsonOptions);
                if (decoded is null)
                {
                    throw new JsonException("Empty response.");
                }

                return decoded;
            }
            catch (JsonException error)
            {
                throw new AppBackendException(AppBackendErrorKind.Decoding, error.Message, error);
            }
        }

        private void EnforceRateLimitCooldown()
        {
            if (_rateLimitedUntil is null)
            {
                return;
            }

            if (DateTimeOffset.UtcNow < _rateLimitedUntil.Value)
            {
                throw new AppBackendException(
                    AppBackendErrorKind.Http,
                    "Too many requests. Please try again later.",
                    statusCode: HttpStatusCode.TooManyRequests,
                    payload: new AppBackendErrorDto
                    {
                        Code = "rate_limited",
                        Message = "Too many requests. Please try again later."
                    });
            }

            _rateLimitedUntil = null;
        }

        private void RegisterRateLimit(string? retryAfter)
        {
            var interval = ParseRetryAfterInterval(retryAfter) ?? TimeSpan.FromSeconds(30);
            if (interval < TimeSpan.FromSeconds(1))
            {
                interval = TimeSpan.FromSeconds(1);
            }

            if (interval > TimeSpan.FromMinutes(5))
            {
                interval = TimeSpan.FromMinutes(5);
            }

            _rateLimitedUntil = DateTimeOffset.UtcNow.Add(interval);
        }

        private static TimeSpan? ParseRetryAfterInterval(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw))
            {
                return null;
            }

            if (double.TryParse(raw.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var seconds))
            {
                return TimeSpan.FromSeconds(seconds);
            }

            if (DateTimeOffset.TryParse(raw, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var retryAt))
            {
                return retryAt - DateTimeOffset.UtcNow;
            }

            return null;
        }

        private static bool IsRetryable(AppBackendException error)
        {
            if (error.Kind == AppBackendErrorKind.Transport)
            {
                return true;
            }

            if (error.Kind != AppBackendErrorKind.Http || error.StatusCode is null)
            {
                return false;
            }

            return error.StatusCode == HttpStatusCode.BadGateway ||
                   error.StatusCode == HttpStatusCode.ServiceUnavailable ||
                   error.StatusCode == HttpStatusCode.GatewayTimeout;
        }

        private static AppBackendErrorDto? TryDecodeError(byte[] data)
        {
            try
            {
                return JsonSerializer.Deserialize<AppBackendErrorDto>(data, JsonOptions);
            }
            catch
            {
                return null;
            }
        }

        private static HttpRequestMessage CloneRequest(HttpRequestMessage request)
        {
            var clone = new HttpRequestMessage(request.Method, request.RequestUri);

            foreach (var header in request.Headers)
            {
                clone.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }

            if (request.Content is not null)
            {
                var content = request.Content.ReadAsStringAsync().GetAwaiter().GetResult();
                clone.Content = new StringContent(content, Encoding.UTF8, request.Content.Headers.ContentType?.MediaType ?? "application/json");
            }

            return clone;
        }

        private static Uri ResolveDownloadUri(string url)
        {
            var trimmed = url.Trim();
            if (Uri.TryCreate(trimmed, UriKind.Absolute, out var absoluteUri))
            {
                return absoluteUri;
            }

            if (!trimmed.StartsWith("/", StringComparison.Ordinal))
            {
                trimmed = "/" + trimmed;
            }

            return new Uri(AppBackendConfiguration.BaseUri, trimmed);
        }

        private static string SanitizedDownloadFileName(string suggestedName)
        {
            var fileName = Path.GetFileName(suggestedName.Trim());
            return string.IsNullOrWhiteSpace(fileName) || fileName is "." or ".."
                ? $"release-{Guid.NewGuid():N}.zip"
                : fileName;
        }
    }

    public sealed record DownloadProgress(double Fraction, long BytesWritten, long BytesTotal);
}
