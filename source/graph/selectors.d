module graph.selectors;


/**
 *  Stands for undirected graph.
 */
struct Undirected
{
    package enum isDirected = false;
    package enum isBidir = false;
}


/**
 *  Stands for directed graph.
 */
struct Directed
{
    package enum isDirected = true;
    package enum isBidir = false;
}


/**
 *  Stands for bidirectional graph.
 */
struct Bidirectional
{
    package enum isDirected = true;
    package enum isBidir = true;
}
