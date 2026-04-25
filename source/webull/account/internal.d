module webull.account.internal;

import std.conv : to;
import std.json;
import std.string : assumeUTF, toLower;
import webull.client : Client, Permissions;
import webull.orchestrate;

package string[] listEndpoints()
{
    return [
        "/openapi/account/list",
        "/app/subscriptions/list",
    ];
}

package void enforceAccountsPermission()
{
    if (Client.permissions != Permissions.NONE && !(Client.permissions & Permissions.ACCOUNTS))
        throw new Exception("Accounts API not available - permission denied");
}

package JSONValue requestJson(string path, string[string] queryParams = null)
{
    JSONValue json;
    orchestrate!"v2"(Client.endpoint, path, queryParams).get(
        (ubyte[] data) {
            json = parseJSON(data.assumeUTF);
        },
        (ubyte[] data) {
            throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
        },
    );
    return json;
}

package JSONValue requestJsonWithFallback(string[] paths, string[string] queryParams = null)
{
    Exception lastError;

    foreach (string path; paths)
    {
        try
            return requestJson(path, queryParams);
        catch (Exception err)
            lastError = err;
    }

    if (lastError !is null)
        throw lastError;

    throw new Exception("No account endpoints were provided.");
}

package JSONValue[] arrayValue(JSONValue json, string[] objectKeys = null)
{
    if (json.type == JSONType.array)
        return json.array.dup;

    if (json.type != JSONType.object)
        return null;

    foreach (string key; objectKeys)
    {
        if (auto value = key in json)
        {
            if (value.type == JSONType.array)
                return value.array.dup;
        }
    }

    return null;
}

package const(JSONValue)* field(JSONValue json, string snakeName, string camelName = null)
{
    if (json.type != JSONType.object)
        return null;

    if (auto value = snakeName in json)
        return value;

    if (camelName !is null)
    {
        if (auto value = camelName in json)
            return value;
    }

    return null;
}

package string textValue(JSONValue json, string snakeName, string camelName = null)
{
    if (auto value = field(json, snakeName, camelName))
        return toText(*value);

    return null;
}

package double doubleValue(JSONValue json, string snakeName, string camelName = null, double fallback = 0)
{
    if (auto value = field(json, snakeName, camelName))
        return toDouble(*value, fallback);

    return fallback;
}

package bool boolValue(JSONValue json, string snakeName, string camelName = null, bool fallback = false)
{
    if (auto value = field(json, snakeName, camelName))
        return toBool(*value, fallback);

    return fallback;
}

package string toText(JSONValue value)
{
    switch (value.type)
    {
    case JSONType.string:
        return value.str;

    case JSONType.integer:
        return value.integer.to!string;

    case JSONType.uinteger:
        return value.uinteger.to!string;

    case JSONType.float_:
        return value.floating.to!string;

    case JSONType.true_:
        return "true";

    case JSONType.false_:
        return "false";

    case JSONType.null_:
        return null;

    default:
        return value.toString();
    }
}

package double toDouble(JSONValue value, double fallback = 0)
{
    switch (value.type)
    {
    case JSONType.integer:
        return cast(double)value.integer;

    case JSONType.uinteger:
        return cast(double)value.uinteger;

    case JSONType.float_:
        return value.floating;

    case JSONType.string:
        if (value.str is null || value.str.length == 0)
            return fallback;

        return value.str.to!double;

    default:
        return fallback;
    }
}

package bool toBool(JSONValue value, bool fallback = false)
{
    switch (value.type)
    {
    case JSONType.true_:
        return true;

    case JSONType.false_:
        return false;

    case JSONType.integer:
        return value.integer != 0;

    case JSONType.uinteger:
        return value.uinteger != 0;

    case JSONType.string:
        string lowered = value.str.toLower();
        if (lowered == "true" || lowered == "1")
            return true;
        if (lowered == "false" || lowered == "0")
            return false;
        return fallback;

    default:
        return fallback;
    }
}
