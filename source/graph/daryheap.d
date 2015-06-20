module graph.daryheap;

import std.array;
import std.container : Array;
import std.functional;
import std.range;
import std.traits;


/**
 *  D-ary heap.
 */
struct DAryHeap(T, size_t Arity = 2, alias less = "a < b")
{
    private struct HeapNode
    {
        T value;
        size_t index;
    }

    struct Handle
    {
        private HeapNode* node;

        private this(HeapNode* node)
        {
            this.node = node;
        }

        bool opEquals(in Handle rhs) const
        {
            return node.index == rhs.node.index;
        }
    }

    private HeapNode*[] _tree;

    /**
     *  Creates a heap with the capacity specified.
     */
    this(size_t capacity = 0)
    {
        if (capacity > 0)
        {
            _tree.reserve(capacity);
        }
    }

    /**
     *  Returns the number of elements stored.
     */
    auto length() @property const
    {
        return _tree.length;
    }

    /**
     *  Returns length == 0.
     */
    bool empty() @property const
    {
        return _tree.empty;
    }

    /**
     *  Returns the top value in heap.
     */
    auto ref top() @property const
    {
        return _tree.front.value;
    }

    /**
     *  Pushes an element to heap.
     */
    auto push(in T v)
    {
        auto node = new HeapNode(v, 0);
        _tree.assumeSafeAppend ~= node;

        updateIndex(_tree.length - 1, _tree.length - 1);
        siftUp(_tree.length - 1);

        return Handle(node);
    }

    /**
     *  Pops the top element from heap.
     */
    auto pop()
    {
        auto top = _tree.front;

        updateIndex(0, size_t.max);
        updateIndex(_tree.length - 1, 0);

        _tree.front = move(_tree.back);
        _tree.popBack();

        if (!_tree.empty)
        {
            siftDown(0);
        }

        return top.value;
    }

    /**
     *  Updates heap property.
     */
    void update(Handle handle, in T v)
    {
        handle.node.value = v;
        update(handle.node.index);
    }

    /// ditto
    void siftUp(Handle handle, in T v)
    {
        handle.node.value = v;
        siftUp(handle.node.index);
    }

    /// ditto
    void siftDown(Handle handle, in T v)
    {
        handle.node.value = v;
        siftDown(handle.node.index);
    }

    private void update(size_t index)
    {
        if (isRoot(index))
        {
            siftDown(index);
            return;
        }

        auto parentIndex = this.parentIndex(index);

        if (lessFun(_tree[parentIndex], _tree[index]))
        {
            siftUp(index);
        }
        else
        {
            siftDown(index);
        }
    }

    private void siftUp(size_t index)
    {
        while (!isRoot(index))
        {
            auto parentIndex = this.parentIndex(index);

            if (lessFun(_tree[parentIndex], _tree[index]))
            {
                updateIndex(parentIndex, index);
                updateIndex(index, parentIndex);

                swap(_tree[parentIndex], _tree[index]);

                index = parentIndex;
            }
            else
            {
                return;
            }
        }
    }

    private void siftDown(size_t index)
    {
        while (!isLeaf(index))
        {
            auto topChildIndex = this.topChildIndex(index);

            if (!lessFun(_tree[topChildIndex], _tree[index]))
            {
                updateIndex(topChildIndex, index);
                updateIndex(index, topChildIndex);

                swap(_tree[topChildIndex], _tree[index]);

                index = topChildIndex;
            }
            else
            {
                return;
            }
        }
    }

    private static bool lessFun(in HeapNode* n1, in HeapNode* n2)
    {
        return binaryFun!less(n1.value, n2.value);
    }

    private static auto parentIndex(size_t index)
    in
    {
        assert(!isRoot(index));
    }
    body
    {
        return (index - 1) / Arity;
    }

    private auto childIndices(size_t index) const
    {
        auto first = index * Arity + 1;
        return iota(first, min(first + Arity, this.length));
    }

    private auto topChildIndex(size_t index) const
    in
    {
        assert(!isLeaf(index));
    }
    body
    {
        auto indices = childIndices(index);
        size_t found = indices.front;

        foreach (i; indices[1 .. $])
        {
            if (lessFun(_tree[found], _tree[i]))
            {
                found = i;
            }
        }

        return found;
    }

    private static bool isRoot(size_t index)
    {
        return index == 0;
    }

    private bool isLeaf(size_t index) const
    {
        return childIndices(index).empty;
    }

    private void updateIndex(size_t pos, size_t newIndex)
    {
        _tree[pos].index = newIndex;
    }
}

unittest
{
    alias Heap = DAryHeap!(int, 4, "a > b");
    alias Handle = Heap.Handle;
    alias HeapNode = Heap.HeapNode;

    Heap heap;
    Handle[int] handles;

    handles[10] = heap.push(10);

    assert(heap.top == 10);
    assert(*handles[10].node == HeapNode(10, 0));

    handles[5] = heap.push(5);

    assert(heap.top == 5);
    assert(*handles[10].node == HeapNode(10, 1));
    assert(*handles[5].node == HeapNode(5, 0));

    auto v = heap.pop();

    assert(v == 5);
    assert(heap.top == 10);
    assert(*handles[10].node == HeapNode(10, 0));
}

unittest
{
    alias Heap = DAryHeap!(int, 4, "a > b");
    alias Handle = Heap.Handle;
    alias HeapNode = Heap.HeapNode;

    Heap heap;

    heap.push(1);
    heap.push(2);
    auto handle = heap.push(3);
    heap.push(4);
    heap.push(5);

    heap.update(handle, 0);

    assert(heap.top == 0);
    assert(*handle.node == HeapNode(0, 0));
}
