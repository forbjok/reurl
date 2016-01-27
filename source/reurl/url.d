module reurl.url;

import std.regex;
import std.conv;
import std.format;
import std.string;
import std.algorithm;

@safe:

class InvalidURLException : Exception {
    this(string url) {
        super("Invalid URL: %s".format(url));
    }
}

struct URL {
    string scheme;
    string username;
    string password;
    string hostname;
    string port;
    string path;
    string query;
    string fragment;

    @property string host() {
        return this.hostname ~ (this.port == "" ? "" : ":%s".format(this.port));
    }

    string toString() {
        auto usernamePassword = this.username.length == 0 ? "" : (this.username ~ (this.password.length == 0 ? "" : ":" ~ this.password) ~ "@");

        return this.scheme ~ "://" ~ usernamePassword ~ this.host ~ this.path ~ this.query ~ this.fragment;
    }

    URL opOpAssign(string op : "~")(in string url) {
        if (url.startsWith("/")) {
            // The URL appended starts with // - replace host, path, query and fragment
            auto splitDoubleDashPart = regex(`(//([\w\.]*)(?::(\d*))?)?(/[\w\-\.\/]*)?(\?[\w&=]*)?(#\w*)?`);

            auto m = url.matchFirst(splitDoubleDashPart);

            with (this) {
                if (m[1].length > 0) {
                    hostname = m[2];
                    port = m[3];
                }

                path = m[4];
                query = m[5];
                fragment = m[6];
            }
        }
        else {
            if (url.canFind("://")) {
                // The URL appended is an absolute URL - replace this one with it
                this = url.parseURL();
            }
            else {
                // The URL appended is a relative path - append it to the current one and replace query and fragment
                auto splitPart = regex(`([\w\-\.\/]*)?(\?[\w&=]*)?(#\w*)?`);
                auto m = url.matchFirst(splitPart);
                with (this) {
                    path ~= (path.endsWith("/") ? "" : "/") ~ m[1];
                    query = m[2];
                    fragment = m[3];
                }
            }
        }

        return this;
    }

    URL opBinary(string op : "~")(in string url) {
        auto newURL = this;

        newURL ~= url;
        return newURL;
    }
}

URL parseURL(in string url) {
    URL purl;

    auto splitUrl = regex(`(\w*)://(?:(\w*)(?::(\w*))?@)?([\w\.]*)(?::(\d*))?(/[\w\-\.\/]*)?(\?[\w&=]*)?(#\w*)?`);

    auto m = url.matchFirst(splitUrl);
    if (m.empty) {
        throw new InvalidURLException(url);
    }

    with (purl) {
        scheme = m[1];
        username = m[2];
        password = m[3];
        hostname = m[4];
        port = m[5];
        path = m[6];
        query = m[7];
        fragment = m[8];
    }

    return purl;
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);

    assert(purl.scheme == "http");
    assert(purl.username == "username");
    assert(purl.password == "password");
    assert(purl.hostname == "www.hostname.com");
    assert(purl.port == "1234");
    assert(purl.path == "/path1/path2");
    assert(purl.query == "?param1=value1&param2=value2");
    assert(purl.fragment == "#fragment");
    assert(purl.host == "www.hostname.com:1234");
    assert(purl.toString() == url);
}

unittest {
    auto url = "http://www.hostname.com/path?param=value";
    auto purl = parseURL(url);

    assert(purl.scheme == "http");
    assert(purl.username == "");
    assert(purl.password == "");
    assert(purl.hostname == "www.hostname.com");
    assert(purl.port == "");
    assert(purl.path == "/path");
    assert(purl.query == "?param=value");
    assert(purl.fragment == "");
    assert(purl.host == "www.hostname.com");
    assert(purl.toString() == url);
}

unittest {
    auto url = "http://www.hostname.com/path";
    auto purl = parseURL(url);

    assert(purl.scheme == "http");
    assert(purl.username == "");
    assert(purl.password == "");
    assert(purl.hostname == "www.hostname.com");
    assert(purl.port == "");
    assert(purl.path == "/path");
    assert(purl.query == "");
    assert(purl.fragment == "");
    assert(purl.host == "www.hostname.com");
    assert(purl.toString() == url);
}

unittest {
    auto url = "http://www.hostname.com";
    auto purl = parseURL(url);

    assert(purl.scheme == "http");
    assert(purl.username == "");
    assert(purl.password == "");
    assert(purl.hostname == "www.hostname.com");
    assert(purl.port == "");
    assert(purl.path == "");
    assert(purl.query == "");
    assert(purl.fragment == "");
    assert(purl.host == "www.hostname.com");
    assert(purl.toString() == url);
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    purl ~= "//newhost.org/newpath";

    assert(purl.scheme == "http");
    assert(purl.username == "username");
    assert(purl.password == "password");
    assert(purl.hostname == "newhost.org");
    assert(purl.port == "");
    assert(purl.path == "/newpath");
    assert(purl.query == "");
    assert(purl.fragment == "");
    assert(purl.host == "newhost.org");
    assert(purl.toString() == "http://username:password@newhost.org/newpath");
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto newUrl = "newscheme://newusername:newpassword@www.newhostname.com:2345/newpath?newparam=newvalue#newfragment";
    auto purl = parseURL(url);
    purl ~= newUrl;

    assert(purl.scheme == "newscheme");
    assert(purl.username == "newusername");
    assert(purl.password == "newpassword");
    assert(purl.hostname == "www.newhostname.com");
    assert(purl.port == "2345");
    assert(purl.path == "/newpath");
    assert(purl.query == "?newparam=newvalue");
    assert(purl.fragment == "#newfragment");
    assert(purl.host == "www.newhostname.com:2345");
    assert(purl.toString() == newUrl);
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    purl ~= "/newpath?newparam=newvalue#newfragment";

    assert(purl.scheme == "http");
    assert(purl.username == "username");
    assert(purl.password == "password");
    assert(purl.hostname == "www.hostname.com");
    assert(purl.port == "1234");
    assert(purl.path == "/newpath");
    assert(purl.query == "?newparam=newvalue");
    assert(purl.fragment == "#newfragment");
    assert(purl.host == "www.hostname.com:1234");
    assert(purl.toString() == "http://username:password@www.hostname.com:1234/newpath?newparam=newvalue#newfragment");
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    purl ~= "path3?newparam=newvalue#newfragment";

    assert(purl.scheme == "http");
    assert(purl.username == "username");
    assert(purl.password == "password");
    assert(purl.hostname == "www.hostname.com");
    assert(purl.port == "1234");
    assert(purl.path == "/path1/path2/path3");
    assert(purl.query == "?newparam=newvalue");
    assert(purl.fragment == "#newfragment");
    assert(purl.host == "www.hostname.com:1234");
    assert(purl.toString() == "http://username:password@www.hostname.com:1234/path1/path2/path3?newparam=newvalue#newfragment");
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    auto purl2 = purl ~ "//newhost.org/newpath";

    assert(purl.toString() == url);
    assert(purl2.toString() == "http://username:password@newhost.org/newpath");
}
