module graph.range;

import std.range;


/**
 *  Detect whether a type of E is an edge.
 */
template isEdge(E)
{
    enum isEdge = is(typeof({
        E e;
        size_t s = e.source;
        size_t t = e.target;
    }));
}

/**
 *  Detect whether a type of R is range.
 */
template isEdgeRange(R)
{
    enum isEdgeRange = isRandomAccessRange!R && isEdge!(ElementType!R);
}

/**
 *  The edge range already sorted by source.
 */
template SortedEdgeRange(R) if (isEdgeRange!R)
{
    alias SortedEdgeRange = SortedRange!(R, "a.source < b.source");
}

/**
 *  Returns SortedEdges as edges is already sorted by source.
 */
auto assumeSortedEdges(R)(R r) if (isEdgeRange!R)
{
    return SortedEdgeRange!R(r);
}

///
unittest
{
    import std.typecons;

    struct E1
    {
        size_t source;
        size_t target;
    }

    alias E2 = Tuple!(size_t, "source", size_t, "target");

    static assert(isEdge!E1);
    static assert(isEdgeRange!(E1[]));

    static assert(isEdge!E2);
    static assert(isEdgeRange!(E2[]));
}
