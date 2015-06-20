module graph.heap;

import std.conv;

import std.algorithm;
import std.array;
import std.container;
import std.functional;
import std.range;
import std.typecons;


/**
 *  D-ary heap.
 */
struct DAryHeap(T, size_t Arity = 2, alias less = "a < b")
{
    alias lessFun = binaryFun!less;

    private T[] _data;

    private auto parentIndex(size_t index) const
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
        auto first = min(index * Arity + 1, length);
        auto last = min(first + Arity, length);

        return iota(first, last);
    }

    private auto isRoot(size_t index) const
    {
        return index == 0;
    }

    private auto isLeaf(size_t index) const
    {
        return childIndices(index).empty;
    }

    /**
     *  Returns the number of elements stored.
     */
    @property auto length() const
    {
        return _data.length;
    }

    /**
     *  Returns length == 0.
     */
    @property auto empty() const
    {
        return _data.empty;
    }

    /**
     *  Returns top element.
     */
    @property auto ref top() const
    in
    {
        assert(!empty);
    }
    body
    {
        return _data.front;
    }

    /**
     *  Pushes an element to heap.
     */
    void push(in T v)
    {
        _data ~= v;
        siftUp(_data.length - 1);
    }

    /**
     *  Pops the top element from heap.
     */
    @property void pop()
    {
        swap(_data[0], _data[$ - 1]);
        _data.popBack();

        if (_data.empty)
        {
            return;
        }

        siftDown(0);
    }

    /**
     *  Updates heap property.
     */
    void update(size_t index)
    {
        if (isRoot(index))
        {
            siftDown(index);
            return;
        }

        auto parentIndex = this.parentIndex(index);

        if (lessFun(_data[parentIndex], _data[index]))
        {
            siftUp(index);
        }
        else
        {
            siftDown(index);
        }
    }

    /**
     *  Sifts up a node at index.
     */
    void siftUp(size_t index)
    {
        while (!isRoot(index))
        {
            auto parentIndex = this.parentIndex(index);

            if (lessFun(_data[parentIndex], _data[index]))
            {
                swap(_data[parentIndex], _data[index]);
                index = parentIndex;
            }
            else
            {
                return;
            }
        }
    }

    /**
     *  Sifts down a node at index.
     */
    void siftDown(size_t index)
    {
        while (!isLeaf(index))
        {
            auto topChildIndex = this.topChildIndex(index);

            if (!lessFun(_data[topChildIndex], _data[index]))
            {
                swap(_data[topChildIndex], _data[index]);
                index = topChildIndex;
            }
            else
            {
                return;
            }
        }
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

        foreach (i; indices)
        {
            if (lessFun(_data[found], _data[i]))
            {
                found = i;
            }
        }

        return found;
    }
}

unittest
{
    import std.random;

    DAryHeap!(int, 4, "a > b") heap;

    foreach (_; 0 .. 10000)
    {
        heap.push(uniform(0, 5000));
    }

    foreach (_; 0 .. 1000)
    {
        auto index = uniform(0, heap.length);
        heap._data[index] = uniform(100, 200);
        heap.update(index);
    }

    int[] a;

    while (!heap.empty)
    {
        a ~= heap.top;
        heap.pop();
    }

    assert(a.isSorted);
}
