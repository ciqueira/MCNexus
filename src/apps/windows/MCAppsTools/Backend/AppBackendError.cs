using System;
using System.Net;

namespace MCAppsTools
{
    public enum AppBackendErrorKind
    {
        MissingConfiguration,
        InvalidUrl,
        Http,
        Decoding,
        Transport,
        Unknown,
        /// <summary>
        /// The downloaded file's SHA256 does not match what the backend
        /// declared for it. Never tolerated, in any channel — the file has
        /// already been deleted by the time this is thrown.
        /// PLAN_Release_Integrity_And_Listing.md §2.4.
        /// </summary>
        IntegrityCheckFailed,
        /// <summary>
        /// The resolve-download response carried no SHA256 for this asset.
        /// Only thrown on the "stable" channel — "beta" proceeds with a
        /// logged warning instead. PLAN §2.4.
        /// </summary>
        IntegrityCheckMissing
    }

    public sealed class AppBackendException : Exception
    {
        public AppBackendException(
            AppBackendErrorKind kind,
            string message,
            Exception? innerException = null,
            HttpStatusCode? statusCode = null,
            AppBackendErrorDto? payload = null)
            : base(message, innerException)
        {
            Kind = kind;
            StatusCode = statusCode;
            Payload = payload;
        }

        public AppBackendErrorKind Kind { get; }
        public HttpStatusCode? StatusCode { get; }
        public AppBackendErrorDto? Payload { get; }
    }
}
