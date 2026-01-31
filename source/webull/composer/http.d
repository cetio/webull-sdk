module webull.composer.http;

import std.net.curl;
import std.json;
import std.stdio : writeln;
import webull.composer.orchestrate : toCompactJSON;

void get(
    HTTP http,
    string url,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure)
{
    http.url = url;
    get(http, success, failure);
}

void get(
    HTTP http,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure)
{
    http.method = HTTP.Method.get;

    ubyte[] data;
    http.onReceive((ubyte[] tmp) {
        if (tmp.length > 0)
            data ~= tmp;
        return tmp.length;
    });

    if (http.perform() == 0 && success !is null)
        success(data);
    else if (failure !is null)
        failure(data);
}

void post(
    HTTP http,
    string url,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure,
    JSONValue json = JSONValue(null))
{
    http.url = url;
    post(http, success, failure, json);
}

void post(
    HTTP http,
    void delegate(ubyte[]) success,
    void delegate(ubyte[]) failure,
    JSONValue json = JSONValue(null))
{
    http.method = HTTP.Method.post;
    if (json.type != JSONType.null_)
        http.setPostData(toCompactJSON(json), "application/json");
    else
        http.setPostData("", "application/json");

    ubyte[] data;
    http.onReceive((ubyte[] tmp) {
        if (tmp.length > 0)
            data ~= tmp;
        return tmp.length;
    });

    if (http.perform() == 0 && success !is null)
        success(data);
    else if (failure !is null)
        failure(data);
}
