using CP;

dvar int x;
                        
subject to {
	if("demand1" > "demand2")
		x == 3;
	else
		x == 4;
}


execute {
    writeln("hello");
    writeln(x);
}    
