 main 
 {
    
   var models = new Array(
		"foodPrecedence1",
    	"instance0"
    	,"instance1"
    	,"instance2"
//    	,"instance3"
   );
   
   var solutions = new Array( models.length );
   
   var modelSource = new IloOplModelSource("Ass2.mod" );
   
   var modelDef= new IloOplModelDefinition(modelSource);
   var cpe = new IloCP;


   for(var m = 0; m < models.length; m++)
   {
     var modelOpl = new IloOplModel( modelDef, cpe);
     var modelname = models[m] + ".dat";
     var data = new IloOplDataSource( modelname );
     modelOpl.addDataSource( data );
     modelOpl.generate();
     
     writeln("Testing instance: ", models[m]);
     
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
   
   