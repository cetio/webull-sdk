module webull.orchestrate;

import conductor.http : httpGet = get, httpPost = post, JSONValue, JSONType;
import std.algorithm;
import std.array;
import std.base64;
import std.conv;
import std.datetime;
import std.digest.hmac;
import std.digest.md;
import std.digest.sha;
import std.format;
import std.net.curl : HTTP;
import std.string;
import std.uni;
import std.uuid;
import webull.client : Client;

struct Request
{
    HTTP http;
    string url;

    void get(
        void delegate(ubyte[]) success,
        void delegate(ubyte[]) failure,
    )
        => httpGet(http, url, success, failure);

    void post(
        void delegate(ubyte[]) success,
        void delegate(ubyte[]) failure,
        JSONValue json = JSONValue(null),
    )
        => httpPost(
            http,
            url,
            json.type == JSONType.null_ ? "" : json.toString,
            success,
            failure,
            "application/json",
        );
}

Request orchestrate(string VERSION = "v1")(
    string host,
    string uri,
    string[string] queryParams = null,
    JSONValue bodyParams = JSONValue.emptyObject)
{
    HTTP http = HTTP();

    string[string] headers;
    headers["x-app-key"] = Client.key;
    headers["x-signature-version"] = "1.0";
    headers["x-signature-algorithm"] = "HMAC-SHA1";
    headers["x-signature-nonce"] = randomUUID().toString().replace("-", "");
    headers["host"] = host;

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
    string signature = sign(encoded, Client.secret~"&");

    string url = "https://"~host~uri;
    if (queryParams.length > 0)
    {
        string[] queryPairs;
        foreach (k, v; queryParams)
            queryPairs ~= encodeURIComponent(k)~"="~encodeURIComponent(v);
        url ~= "?"~queryPairs.join("&");
    }

    http.addRequestHeader("x-version", VERSION);
    http.addRequestHeader("x-signature", signature);
    foreach (key, value; headers)
        http.addRequestHeader(key, value);

    return Request(http, url);
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
    foreach (byte b; md5Of(cast(ubyte[]) str))
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
    ubyte[] secretBytes = cast(ubyte[]) secret;
    HMAC!SHA1 hmac = HMAC!SHA1(secretBytes);
    ubyte[] sourceBytes = cast(ubyte[]) source;
    hmac.put(sourceBytes);
    return cast(string) Base64.encode(hmac.finish());
}
