﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.


namespace Microsoft.IIS.Administration.Core
{
    using System;

    public class ForbiddenArgumentException : ApiArgumentException {
        public ForbiddenArgumentException(string paramName, Exception innerException = null) : base(paramName, string.Empty, innerException) {
        }

        public ForbiddenArgumentException(string paramName, string message, Exception innerException = null) : base(paramName, message == null ? string.Empty : message, innerException) {
        }

        public override dynamic GetApiError() {
            return Http.ErrorHelper.ForbiddenArgumentError(ParamName, Message);
        }
    }
}
