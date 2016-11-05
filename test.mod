using CP;

tuple Tup {
    int num;
}

{Tup} items = {<3>, <4>};
     
dvar interval test[<num> in items]
    optional(1)
    in 0..5
    size 2;

dvar sequence itemSeq[<num> in items]
    in all(<num1> in items: num1 == num) test[<num>]
    types all(<num1> in items: num1 == num) 3;
                        
subject to {
    forall(<num> in items) {
        presenceOf(test[<num>]);
        noOverlap(itemSeq[<num>]);
    }
}


execute {
    writeln("hello");
    writeln(itemSeq);
}    
