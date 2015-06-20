module graph.csr;

import std.algorithm;
import std.range;
import std.traits;
import std.typecons;

import graph.range;
import graph.selectors;


/**
 *  Descriptor to point a vertex in a graph.
 */
struct VertexDescriptor
{
    private size_t index;
}


/**
 *  Map from vertex descriptor to property.
 */
struct VertexPropertyMap(Props) if (isRandomAccessRange!Props)
{
    private Props _vertexProps;

    this(Props props)
    {
        _vertexProps = props;
    }

    auto ref opIndex(in VertexDescriptor v) inout
    {
        return _vertexProps[v.index];
    }
}

VertexPropertyMap!Props vertexPropertyMap(Props)(Props props)
{
    return VertexPropertyMap!Props(props);
}


/**
 *  Descriptor to point a edge in a graph.
 */
struct EdgeDescriptor
{
    private size_t source;
    private size_t index;

    bool opEquals(in EdgeDescriptor e) const
    in
    {
        assert(index != e.index || source == e.source);
    }
    body
    {
        return index == e.index;
    }
}


/**
 *  Map from edge descriptor to property
 */
struct EdgePropertyMap(Props) if (isRandomAccessRange!Props)
{
    private Props _edgeProps;

    auto ref opIndex(in EdgeDescriptor e) inout
    {
        return _edgeProps[e.index];
    }
}

EdgePropertyMap!Props edgePropertyMap(Props)(Props props)
{
    return EdgePropertyMap!Props(props);
}


/**
 *  Compressed sparse row storage.
 */
private struct Csr(EdgeProp)
{
    enum hasEdgeProp = !is(EdgeProp == void);

    static if (hasEdgeProp)
    {
        alias EdgePropMap = EdgePropertyMap!(EdgeProp[]);
        EdgePropMap _edgePropMap;

		auto ref edgeProperties() @property inout
        {
            return _edgePropMap;
        }
    }

    size_t[] _rowStart;
    size_t[] _column;

    auto ref rowStart() @property @safe nothrow pure const { return _rowStart[]; }
	auto ref column() @property @safe nothrow pure const { return _column[]; }

    this(size_t numVertices) nothrow
    {
        _rowStart.length = numVertices + 1;
        _column.length = 0;
    }

    this(Edges)(SortedEdgeRange!Edges edges, size_t numVertices)
    if (isEdgeRange!Edges)
    {
        _rowStart.length = numVertices + 1;
        _column.length = edges.length;

        size_t currentEdge = 0;
        size_t currentVertexPlusOne = 1;

        _rowStart[0] = 0;
        size_t eIndex = 0;

        foreach (e; edges)
        {
            for (/* NOP */; currentVertexPlusOne != e.source + 1; ++currentVertexPlusOne)
            {
                _rowStart[currentVertexPlusOne] = currentEdge;
            }

            _column[eIndex] = e.target;
            ++currentEdge;
        }

        for (/* NOP */; currentVertexPlusOne != numVertices + 1; ++currentVertexPlusOne)
        {
            _rowStart[currentVertexPlusOne] = currentEdge;
        }
    }

    this(Edges, EdgeProps)(SortedEdgeRange!Edges edges, EdgeProps props, size_t numVertices)
    if (isEdgeRange!Edges && hasEdgeProp)
    in
    {
        assert(edges.length == props.length);
    }
    body
    {
        auto propsCopied = new EdgeProp[props.length];
        copy(props, propsCopied);

        _edgePropMap = EdgePropMap(propsCopied);

        this(edges, numVertices);
    }

    void countRowStarts(Edges)(Edges edges) if (isEdgeRange!Edges)
    {
        foreach (e; edges)
        {
            ++_rowStart[e.source];
        }

        size_t total = 0;

        foreach (ref s; _rowStart)
        {
            auto old = s;
            s = total;
            total += old;
        }
    }

    this(Edges)(Edges edges, size_t numVertices) nothrow if (isEdgeRange!Edges)
    {
        _rowStart.length = numVertices + 1;
        _column.length = edges.length;

        countRowStarts(edges);

        auto insertPos = _rowStart[0 .. numVertices].dup;

        foreach (e; edges)
        {
            auto pos = insertPos[e.source]++;
            _column[pos] = e.target;
        }
    }

    /**
     *  Constructs from unsorted edges and properties.
     */
    this(Edges, EdgeProps)(Edges edges, EdgeProps props, size_t numVertices)
    if (isEdgeRange!Edges && hasEdgeProp && is(ElementType!EdgeProps == EdgeProp))
    in
    {
        assert(edges.length == props.length);
    }
    body
    {
        auto numEdges = edges.length;

        _rowStart.length = numVertices + 1;
        _column.length = numEdges;

        countRowStarts(edges);

        auto insertPos = _rowStart[0 .. numVertices].dup;
        auto sortedProps = new EdgeProp[numEdges];

        foreach (idx; 0 .. numEdges)
        {
            const pos = insertPos[edges[idx].source]++;

            _column[pos] = edges[idx].target;
            sortedProps[pos] = props[idx];
        }

        _edgePropMap = EdgePropMap(sortedProps);
    }
}


/**
 *  Graph constructed by compressed sparse row structure.
 */
struct CsrGraph(Dir, VertexProp = void, EdgeProp = void, GraphProp = void)
if (is(Dir == Directed) || is(Dir == Bidirectional))
{
    private enum hasVertexProp = !is(VertexProp == void);
    private enum hasEdgeProp = !is(EdgeProp == void);
    private enum hasGraphProp = !is(GraphProp == void);

    private enum isBidir = Dir.isBidir;

    alias Vertex = VertexDescriptor;
    alias Edge = EdgeDescriptor;

    //-------------------------------------------------------------------------
    // member variables
    //-------------------------------------------------------------------------
    private alias ForwardType = Csr!EdgeProp;
    ForwardType _forward;

    static if (isBidir)
    {
        private alias BackwardType = Csr!size_t;
        BackwardType _backward;
    }

    static if (hasVertexProp)
    {
        private alias VertexPropMap = VertexPropertyMap!(VertexProp[]);
        private VertexPropMap _vertexProperties;

        /**
         *  Returns a vertex property.
         */
		auto ref opIndex(in VertexDescriptor v) inout
        {
            return _vertexProperties[v];
        }

        /**
         *  Returns vertex property map.
         */
		auto ref vertexProperties() @property inout
        {
            return _vertexProperties;
        }
    }

    static if (hasEdgeProp)
    {
        /**
         *  Returns a edge property
         */
        auto ref opIndex(in EdgeDescriptor e) @safe inout
        {
            return _forward.edgeProperties[e];
        }

        /**
         *  Returns edge property map
         */
        auto ref edgeProperties()
        {
            return _forward.edgeProperties;
        }
    }

    static if (hasGraphProp)
    {
        private GraphProp _graphProp;

        /**
         *  Returns graph property.
         */
		auto ref graphProperty() @property inout
        {
            return _graphProp;
        }
    }

    /**
     *  Constructs with the number of vertices.
     */
    this(size_t numVertices = 0)
    {
        _forward = ForwardType(numVertices);

        static if (hasVertexProp)
        {
            _vertexProperties = VertexPropMap(new VertexProp[numVertices]);
        }
    }

    /**
     *  Constructs with edges and the number of vertices.
     */
    this(Edges)(Edges edges, size_t numVertices) if (isEdgeRange!Edges)
    {
        static if (hasEdgeProp)
        {
            _forward = ForwardType(edges, new EdgeProp[edges.length], numVertices);
        }
        else
        {
            _forward = ForwardType(edges, numVertices);
        }

        static if (hasVertexProp)
        {
            _vertexProperties = VertexPropMap(new VertexProp[numVertices]);
        }

        static if (isBidir)
        {
            setUpBackward();
        }
    }

    /**
     *  Constructs with edges, properties and the number of vertices.
     */
    this(Edges, EdgeProps)(Edges edges, EdgeProps props, size_t numVertices)
    if (isEdgeRange!Edges && hasEdgeProp)
    {
        _forward = ForwardType(edges, props, numVertices);

        static if (hasVertexProp)
        {
            _vertexProperties = VertexPropMap(new VertexProp[numVertices]);
        }

        static if (isBidir)
        {
            setUpBackward();
        }
    }

    //-------------------------------------------------------------------------
    // vertex accessors
    //-------------------------------------------------------------------------

    /**
     *  Returns null vertex.
     */
    static immutable nullVertex = VertexDescriptor(-1);

    /**
     *  Returns index'th vertex descriptor.
     */
    auto vertex(size_t index) const
    in
    {
        assert(index < this.numVertices);
    }
    body
    {
        return VertexDescriptor(index);
    }

    /**
     *  Returns index for vertex descriptor v.
     */
    auto vertexIndex(in VertexDescriptor v) const
    in
    {
        assert(v.index < this.numVertices);
    }
    body
    {
        return v.index;
    }

    /**
     *  Returns the number of vertices.
     */
    auto numVertices() @property const
    {
        return _forward.rowStart.length - 1;
    }

    /**
     *  Returns the outgoing degree of a vertex.
     */
    auto outDegree(in VertexDescriptor v) const
    {
        return _forward.rowStart[v.index + 1] - _forward.rowStart[v.index];
    }

    //-------------------------------------------------------------------------
    // edge accessors
    //-------------------------------------------------------------------------

    /**
     *  Returns null edge descriptor.
     */
    static immutable nullEdge = EdgeDescriptor(nullVertex.index, -1);

    /**
     *  Returns index'th edge descriptor.
     */
    auto edge(size_t index) const
    in
    {
        assert(index < this.numEdges);
    }
    out (result)
    {
        assert(result != nullEdge);
    }
    body
    {
        foreach (src; 0 .. this.numVertices)
        {
            if (_forward.rowStart[src] <= index &&
                index < _forward.rowStart[src + 1])
            {
                return EdgeDescriptor(src, index);
            }
        }

        return nullEdge;
    }

    /**
     *  Returns edge index.
     */
    auto edgeIndex(in EdgeDescriptor e) const
    in
    {
        assert(e.source < this.numVertices);
        assert(e.index < this.numEdges);
    }
    body
    {
        return e.index;
    }

    //-------------------------------------------------------------------------

    /**
     *  Returns the number of edges.
     */
    auto numEdges() @property const
    {
        return _forward.column.length;
    }

    /**
     *  Returns a source of a edge.
     */
    auto source(in EdgeDescriptor e) const
    {
        return VertexDescriptor(e.source);
    }

    /**
     *  Returns a target of a edge.
     */
    auto target(in EdgeDescriptor e) const
    {
        return VertexDescriptor(_forward.column[e.index]);
    }

    /**
     *  Returns a source and a target of a edge.
     */
    auto endpoints(in EdgeDescriptor e) const
    {
        return tuple(source(e), target(e));
    }

    /**
     *  Returns opposite vertex for either endpoint of a edge.
     */
    auto opposite(in EdgeDescriptor e, in VertexDescriptor v) const
    {
        auto s = this.source(e);
        auto t = this.target(e);

        return (s == v) ? t : s;
    }

    //-------------------------------------------------------------------------
    // iteration
    //-------------------------------------------------------------------------

    /**
     *  Iterates all vertices.
     */
    auto vertices() @property const
    {
        return iota(0, this.numVertices).map!(i => VertexDescriptor(i));
    }

    /**
     *  Iterates all edges.
     */
    auto edges() const
    {
        static struct EdgesResult
        {
            size_t numVertices;
            const(size_t)[] rowStart;
            size_t source;
            size_t index;

            this(size_t numVertices, const(size_t)[] rowStart)
            {
                this.numVertices = numVertices;
                this.rowStart = rowStart;

                foreach (s; 0 .. numVertices)
                {
                    if (rowStart[s] < rowStart[s + 1])
                    {
                        source = s;
                        index = rowStart[s];
                        return;
                    }
                }

                index = rowStart.back;
            }

            auto front() @property const
            {
                return EdgeDescriptor(source, index);
            }

            void popFront()
            {
                if (++index == rowStart[source + 1])
                {
                    foreach (s; source + 1 .. this.numVertices)
                    {
                        if (rowStart[s] < rowStart[s + 1])
                        {
                            source = s;
                            index = rowStart[s];
                            return;
                        }
                    }

                    index = rowStart.back;
                }
            }

            bool empty() @property const
            {
                return index == rowStart.back;
            }
        }

        return EdgesResult(this.numVertices, _forward.rowStart[]);
    }

    /**
     *  Iterates edges between vertices s and t.
     */
    auto edges(in VertexDescriptor s, in VertexDescriptor t) const
    {
        return this.outEdges(s).filter!(e => target(e) == t);
    }

    /**
     *  Iterates outgoing edges of a vertex.
     */
    auto outEdges(in VertexDescriptor v) const
    {
        const start = _forward.rowStart[v.index];
        const nextStart = _forward.rowStart[v.index + 1];

        return iota(start, nextStart).map!(i => EdgeDescriptor(v.index, i));
    }

    /**
     *  Iterates vertices adjacent to vertex v.
     */
    auto neighbors(in VertexDescriptor v) const
    {
        return outEdges(v).map!(e => target(e));
    }

    static if (isBidir)
    {
        private void setUpBackward()
        {
            alias VertexIndices = Tuple!(size_t, "source", size_t, "target");

            auto reversedEdges = new VertexIndices[this.numEdges];
            size_t i = 0;

            foreach (e; this.edges)
            {
                reversedEdges[i].source = this.vertexIndex(this.target(e));
                reversedEdges[i].target = this.vertexIndex(this.source(e));
                ++i;
            }

            auto counts = iota(0, reversedEdges.length);

            _backward = BackwardType(reversedEdges, counts, this.numVertices);
        }

        /**
         *  Iterates incoming degree of a vertex.
         */
        auto inDegree(in VertexDescriptor v) const
        {
            const start = _backward.rowStart[v.index];
            const nextStart = _backward.rowStart[v.index + 1];

            return nextStart - start;
        }

        /**
         *  Iterates incoming edges of a vertex.
         */
        auto inEdges(in VertexDescriptor v) const
        {
            const rowStart = _backward.rowStart[v.index];
            const nextRowStart = _backward.rowStart[v.index + 1];

            return iota(rowStart, nextRowStart).map!((i) {
                const source = _backward.column[i];
                const index = _backward.edgeProperties[EdgeDescriptor(v.index, i)];

                return EdgeDescriptor(source, index);
            });
        }
    }
}

version (unittest)
{
    void main() {}

    struct VertexProperty
    {
        string name;
    }

    struct EdgeProperty
    {
        size_t source;
        size_t target;
        string name;
        int weight;
    }

    struct GraphProperty
    {
        string name;
    }
}

unittest
{
    alias Graph = CsrGraph!Bidirectional;
    alias E = Tuple!(size_t, "source", size_t, "target");

    E[1] e;
    int[1] p;

    static assert(!__traits(compiles, new Graph(e[], p[], 0)));
}

///
unittest
{
    enum numVertices = 4;

    auto edges = [
        EdgeProperty(0, 1, "0 -> 1", 0),
        EdgeProperty(0, 3, "0 -> 3", 1),
        EdgeProperty(0, 1, "0 -> 1", 2),
        EdgeProperty(1, 2, "1 -> 2", 3),
        EdgeProperty(1, 2, "1 -> 2", 4),
        EdgeProperty(1, 2, "1 -> 2", 5),
        EdgeProperty(1, 3, "1 -> 3", 6),
        EdgeProperty(3, 2, "3 -> 2", 7)
    ];

    static assert (isEdgeRange!(typeof(edges)));

    alias Graph = CsrGraph!(Directed, VertexProperty, EdgeProperty, GraphProperty);
    auto g = Graph(assumeSortedEdges(edges), edges, numVertices);

    assert(g.numVertices == 4);
    assert(g.numEdges == edges.length);

    assert(g.outDegree(g.vertex(0)) == 3);
    assert(g.outDegree(g.vertex(1)) == 4);
    assert(g.outDegree(g.vertex(2)) == 0);
    assert(g.outDegree(g.vertex(3)) == 1);

    {
        int weight = 0;

        foreach (e; g.edges)
        {
            assert(g[e].weight == weight++);
        }
    }
    {
        int i = 3;
        auto s = g.vertex(1);
        auto t = g.vertex(2);

        foreach (e; g.edges(s, t))
        {
            assert(g[e] == edges[i++]);
        }
    }
}

///
unittest
{
    enum numVertices = 4;

    auto edges = [
        EdgeProperty(1, 2, "1 -> 2", 0),
        EdgeProperty(1, 3, "q -> 3", 1),
        EdgeProperty(1, 2, "1 -> 2", 2),
        EdgeProperty(3, 2, "3 -> 2", 4),
        EdgeProperty(3, 1, "3 -> 1", 5),
        EdgeProperty(1, 3, "1 -> 3", 3)
    ];

    static assert (isEdgeRange!(typeof(edges)));

    alias Graph = CsrGraph!(Bidirectional, VertexProperty, EdgeProperty, GraphProperty);
    auto g = Graph(edges, edges, numVertices);

    assert(g.numVertices == 4);
    assert(g.numEdges == edges.length);

    assert(g.outDegree(g.vertex(0)) == 0);
    assert(g.outDegree(g.vertex(1)) == 4);
    assert(g.outDegree(g.vertex(2)) == 0);
    assert(g.outDegree(g.vertex(3)) == 2);

    assert(g.inDegree(g.vertex(0)) == 0);
    assert(g.inDegree(g.vertex(1)) == 1);
    assert(g.inDegree(g.vertex(2)) == 3);
    assert(g.inDegree(g.vertex(3)) == 2);

    int weight = 0;

    foreach (e; g.edges)
    {
        assert(g[e].weight == weight++);
    }

    foreach (e; g.edges.filter!(e => g[e].weight % 2 == 0))
    {
        assert(g[e].weight % 2 == 0);
    }
}
