﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.


namespace Microsoft.IIS.Administration.Tests
{
    using System.Net;
    using System.Net.Http;
    using Xunit;

    public class IISOptionalFeatures
    {
        [Theory]
        [InlineData("/api/webserver/default-documents")]
        [InlineData("/api/webserver/http-request-tracing")]
        [InlineData("/api/webserver/authentication/basic-authentication")]
        [InlineData("/api/webserver/authentication/digest-authentication")]
        [InlineData("/api/webserver/authentication/windows-authentication")]
        [InlineData("/api/webserver/ip-restrictions")]
        [InlineData("/api/webserver/logging")]
        [InlineData("/api/webserver/http-request-tracing")]
        [InlineData("/api/webserver/http-response-compression")]
        [InlineData("/api/webserver/directory-browsing")]
        [InlineData("/api/webserver/static-content")]
        [InlineData("/api/webserver/http-request-filtering")]
        [InlineData("/api/webserver/http-redirect")]
        public void InstallUninstallFeature(string feature)
        {
            using (HttpClient client = ApiHttpClient.Create()) {
                string result;
                bool installed = IsInstalled(feature, client);

                if (!installed) {
                    Assert.True(client.Post(Configuration.TEST_SERVER_URL + feature, "", out result));
                    Assert.True(IsInstalled(feature, client));
                }

                var settings = client.Get(Configuration.TEST_SERVER_URL + feature + "?scope=");
                Assert.True(client.Delete(Utils.Self(settings)));
                Assert.True(!IsInstalled(feature, client));

                if (installed) {
                    Assert.True(client.Post(Configuration.TEST_SERVER_URL + feature, "", out result));
                    Assert.True(IsInstalled(feature, client));
                }
            }
        }

        private bool IsInstalled(string feature, HttpClient client)
        {
            var res = client.GetAsync(Configuration.TEST_SERVER_URL + feature + "?scope=").Result;
            return res.StatusCode != HttpStatusCode.NotFound; 
        }
    }
}
