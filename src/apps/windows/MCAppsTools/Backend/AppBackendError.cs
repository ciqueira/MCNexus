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
        Unknown
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
