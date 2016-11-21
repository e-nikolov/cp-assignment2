main 
{
    
	var instances = new Array(
//		"foodPrecedence1"
    	"instance0"
    	, "instance1"
    	, "instance2"
//    	, "instance3"
//    	, "instance4"
	);
   
	var solutions = new Array( instances.length );
   
	var models = new Array(
		"Ass2.mod"
//		, "test2.mod"
	);
    
   
	for(var m = 0; m < models.length; ++m) {
		var modelSource = new IloOplModelSource(models[m]);
		   
		var modelDef= new IloOplModelDefinition(modelSource);
		var cpe = new IloCP;


		for(var i = 0; i < instances.length; i++)
		{
			var modelOpl = new IloOplModel( modelDef, cpe);
			var modelname = instances[i] + ".dat";
			var data = new IloOplDataSource( modelname );
			modelOpl.addDataSource( data );
			modelOpl.generate();
	 
			writeln("Testing model: ", models[m], " instance: ", instances[i]);
	 
			if (cpe.solve()) {   
				writeln("Result:");
				modelOpl.postProcess();
			}        
			else {
				writeln("No Solution"); 
				writeln();
 			}
			modelOpl.end();  
			data.end(); 
		}
	}
}   
   
   