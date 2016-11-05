using CP;

tuple Tup {
    int num;
}

{Tup} items = {<1>, <2>, <3>, <4>};
     
dvar interval itemIntervals[<num> in items]
    optional(1)     // With optional 1, itemSequence is empty 
                    // unless constraints are defined on it, 
                    // even if the intervals in it must be present due to presenceOf
                    
//    optional(0)   // With optional 0, itemSequence is full.
    in 0..10
    size 2;

dvar sequence itemSequence[<num> in items]  // Dictionary of Sequences, each containing one interval
    in all(<num1> in items: num1 == num) itemIntervals[<num>]
    types all(<num1> in items: num1 == num) 3;
                        
subject to {
    forall(<num> in items) {
        presenceOf(itemIntervals[<num>]); // All intervals must be present, even if optional
//        first(itemSequence[<num>], itemIntervals[<num>]); // Without any constraints on itemSequence
//                                                          // it appears empty when printed      
    }
}


execute {
    writeln("hello");
    writeln(itemSequence);
}    
