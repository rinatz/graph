module graph.dijkstra;

import std.container : Array;

import graph.daryheap;
import graph.csr;


private enum infinity = size_t.max;

private size_t combine(size_t a, size_t b)
{
    return (a > infinity - b) ? infinity : a + b;
}

/**
 *  Find shortest paths by Dijkstra method.
 */
void dijkstra(alias done = v => false, Graph, Vertex = Graph.Vertex, Labels)(
    in Graph g,
    in Vertex start,
    ref VertexPropertyMap!(Labels) labels)
{
    struct HeapNode
    {
        Vertex vertex;
        size_t distance;
        alias vertex this;
    }

    alias Heap = DAryHeap!(HeapNode, 4, "a.distance > b.distance");
    alias Handle = Heap.Handle;

    auto heap = Heap(g.numVertices);
    auto handles = vertexPropertyMap(new Handle[g.numVertices]);

    foreach (v; g.vertices)
    {
        labels[v].predecessor = v;
        labels[v].distance = infinity;
    }

    labels[start].distance = 0;
    handles[start] = heap.push(HeapNode(start, 0));

    while (!heap.empty)
    {
        auto u = heap.pop();

        if (done(u))
        {
            break;
        }

        foreach (e; g.outEdges(u))
        {
            auto v = g.target(e);
            auto dist = combine(labels[u].distance, g[e].weight);

            if (labels[v].distance == size_t.max)
            {
                labels[v].predecessor = u;
                labels[v].distance = dist;

                handles[v] = heap.push(HeapNode(v, dist));
            }
            else if (dist < labels[v].distance)
            {
                labels[v].predecessor = u;
                labels[v].distance = dist;

                heap.siftUp(handles[v], HeapNode(v, dist));
            }
        }
    }
}

unittest
{
    import graph.csr;
    import graph.range;
    import graph.selectors;

    struct EdgeProperty
    {
        size_t source;
        size_t target;
        size_t weight;
    }

    alias Graph = CsrGraph!(Directed, void, EdgeProperty);
    alias Vertex = Graph.Vertex;

    struct Label
    {
        Vertex predecessor;
        size_t distance;
    }

    enum numVertices = 3;

    auto edges = [
        EdgeProperty(0, 1, 1),
        EdgeProperty(0, 2, 4),
        EdgeProperty(1, 2, 2),
    ];

    auto g = Graph(assumeSortedEdges(edges), edges, numVertices);
    auto labels = vertexPropertyMap(new Label[g.numVertices]);

    g.dijkstra(g.vertex(0), labels);

    assert(labels[g.vertex(0)].distance == 0);
    assert(labels[g.vertex(1)].distance == 1);
    assert(labels[g.vertex(2)].distance == 3);

    assert(labels[g.vertex(0)].predecessor == g.vertex(0));
    assert(labels[g.vertex(1)].predecessor == g.vertex(0));
    assert(labels[g.vertex(2)].predecessor == g.vertex(1));
}
