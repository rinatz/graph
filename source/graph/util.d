module graph.util;

import std.traits;


auto ref unqual(T)(ref T v) @trusted nothrow pure
{
    return cast(Unqual!T)v;
}
