module webull.signer;

import std.algorithm;
import std.array;
import std.base64;
import std.conv;
import std.datetime;
import std.digest.hmac;
import std.digest.md;
import std.digest.sha;
import std.format;
import std.json : JSONValue, JSONType;
import std.string;
import std.uni;
import std.uuid;

string[string] signRequest(
    string host,
    string uri,
    string[string] queryParams = null,
    JSONValue bodyParams = JSONValue.emptyObject,
    string key = null,
    string secret = null,
    string apiVersion = "v1",
)
{
    string headerHost = normalizedHost(host);
    string[string] headers;
    headers["x-app-key"] = key;
    headers["x-signature-version"] = "1.0";
    headers["x-signature-algorithm"] = "HMAC-SHA1";
    headers["x-signature-nonce"] = randomUUID().toString().replace("-", "");
    headers["host"] = headerHost;

    SysTime now = Clock.currTime(UTC());
    headers["x-timestamp"] = format("%04d-%02d-%02dT%02d:%02d:%02dZ",
        now.year, now.month, now.day, now.hour, now.minute, now.second);

    string[string] params = queryParams.dup;
    foreach (k, v; headers)
        params[k] = v;

    string bodyStr = null;
    if (bodyParams.type != JSONType.null_ && bodyParams.type != JSONType.object)
    {
        string bodyJson = bodyParams.toString;
        bodyStr = md5Hex(bodyJson).toUpper();
    }
    else if (bodyParams.type == JSONType.object && bodyParams.object.length > 0)
    {
        string bodyJson = bodyParams.toString;
        bodyStr = md5Hex(bodyJson).toUpper();
    }

    string encoded = encode(uri, params, bodyStr);
    string signature = sign(encoded, secret~"&");

    string[string] requestHeaders = headers.dup;
    requestHeaders["x-version"] = apiVersion;
    requestHeaders["x-signature"] = signature;

    return requestHeaders;
}

string composeURL(string hostOrEndpoint, string uri)
{
    if (hostOrEndpoint.canFind("://"))
        return hostOrEndpoint~uri;

    return "https://"~hostOrEndpoint~uri;
}

string buildQueryString(string[string] queryParams)
{
    if (queryParams.length == 0)
        return null;

    string[] queryPairs;
    foreach (k, v; queryParams)
        queryPairs ~= encodeURIComponent(k)~"="~encodeURIComponent(v);
    return "?"~queryPairs.join("&");
}

private string normalizedHost(string hostOrEndpoint)
{
    if (!hostOrEndpoint.canFind("://"))
        return hostOrEndpoint;

    ptrdiff_t schemeEnd = hostOrEndpoint.indexOf("://");
    string remainder = hostOrEndpoint[schemeEnd + 3..$];
    ptrdiff_t slash = remainder.indexOf('/');
    return slash < 0 ? remainder : remainder[0..slash];
}

string encode(string uri, string[string] params, string bodyStr)
{
    if (uri.length == 0)
        throw new Exception("URI is empty");

    string str = uri;
    if (params.length > 0)
        str ~= "&"~params.keys.sort.map!(key => key~"="~params[key]).join("&");

    if (bodyStr !is null && bodyStr.length > 0)
        str ~= "&"~bodyStr;

    string ret;
    foreach (char c; str)
    {
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '.' || c == '_' || c == '~')
            ret ~= c;
        else
            ret ~= "%"~format("%02X", cast(ubyte)c);
    }
    return ret;
}

string md5Hex(string str)
{
    char[] hexChars = ['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'];
    string ret;
    foreach (byte b; md5Of(cast(ubyte[])str))
    {
        ret ~= hexChars[(b >> 4) & 0xF];
        ret ~= hexChars[b & 0xF];
    }
    return ret;
}

string encodeURIComponent(string str)
{
    string ret;
    foreach (char c; str)
    {
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '.' || c == '_' || c == '~')
            ret ~= c;
        else
            ret ~= "%"~format("%02X", cast(ubyte)c);
    }
    return ret;
}

string sign(string source, string secret)
{
    ubyte[] secretBytes = cast(ubyte[])secret;
    HMAC!SHA1 hmac = HMAC!SHA1(secretBytes);
    ubyte[] sourceBytes = cast(ubyte[])source;
    hmac.put(sourceBytes);
    return cast(string)Base64.encode(hmac.finish());
}
