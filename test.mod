using CP;

tuple Tup {
    int num;
}

{Tup} items = {<3>, <4>};
     
dvar interval test[<num> in items]
    optional(1)
    in 0..5
    size 5;

dvar sequence itemSeq[<num> in items]
    in all(<num> in items) test[<num>]
    types all(<num> in items) 3;
                        
subject to {
    forall(<num> in items)
        presenceOf(test[<num>]);
}


execute {
    writeln("hello");
    writeln(itemSeq);
}    
