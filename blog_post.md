Blog post outline:

Goals:
 * Wanted to replace current record matching tools (gone through two iterations already)
 * Wanted to be able to match residents based on family relations (derived from `relation_to_head`).  Seems like a particularly great place for a graph
 * Want to create a framework to evaluate the quality of my matches (as in GitHub / StackOverflow MDM posts)

## Matching objects

 * `record_linkage` gem

 * Previously I had a solution in place to index records for searching with elasticsearch/searchkick.  I had problems getting searchkick to index my Neo4j database because I couldn't configure enough memory on my laptop to let it use `find_in_batches` in Neo4j.  So I ended up using a PostgreSQL copy of the data (which I had already set up for playing with) and indexing that with searchkick and then building a wrapper in the Neo4j model to search for Neo4j node instances using PostgreSQL as the elasticsearch bridge.  Coming back to the project again I wanted to be able to index directly from Neo4j.  I though I could simply find chunks of the database (like an entire DED, for example) and give searchkick a scope which it would reindex.  And while I could do that (with a bit of a workaround), it would delete the elasticsearch index each time, so it wasn't really helping.  Also see THIS LINK in the searchkick project for information about supporting scopes.  In the end, after looking at the searchkick code, I wrote my own code to index the entire database one DED at a time (SEE LINK, PUT CODE INTO MODEL RATHER THAN SEPARATE SCRIPT FILE).  



## Matching relationships

NEED TO DRAW A DIAGRAM
THINK ABOUT IF COMPARING RESIDENTS OR COMPARING HOUSES IS BETTER

 * Primary relationships (like `born_to` and `married_to`)
 * Secondary/derived relationships (like `grandchild_of`, `niece_nephew_of`, `sibling_of`).  Gender neutral
 * We can straight-up match to see that two candidates in a house match two other people in another house with the same relationship.
 * When the head of the household changes, a person that you are trying to match generally has a different `relation_to_head`.
   * 1901: C-[:born_to]->head<-[:born_to]-B
   * 1911: new_head-[:sibling_of]-D
   * Could be the case that B == new_head and C == D  or  C == new_head and B == D

 * First tried thinking at a individual resident level.  Was thinking of matching relationships as a sort of additional "property", but 

 * Using relationships to match residents
   * Created "relations" method to get other residents who are 1-2 level away and return string paths
   * Need to go up to a house level
   * Need to first create "similarity_candidate" relationship so that house similarity candidates can bet found
   * Tried thinking in terms of matching relationships as a matching property of residents.  I think it works better for houses
   * 
