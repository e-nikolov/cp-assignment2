/*********************************************
 * OPL 12.6.3.0 Model
 * Author: enikolov
 * Creation Date: 19 Oct 2016 at 15:23:24
 *********************************************/

tuple Product {
	key int productId;
	string name;
}
{Product} Products = ...;

tuple Demand {
	key string DEMAND_ID;
	int PRODUCT_ID	;
	int QUANTITY;
	int DELIVERY_MIN;
	int DELIVERY_MAX;
	float NON_DELIVERY_VARIABLE_COST;
	int DUE_TIME;
	float TARDINESS_VARIABLE_COST;
}
{Demand} Demands = ...;

tuple Resource {
	key string RESOURCE_ID;
	int RESOURCE_NR;
	string SETUP_MATRIX_ID;
	int INITIAL_PRODUCT_ID;
}
{Resource} Resources = ...;

tuple SetupResource {
	key string SETUP_RESOURCE_ID;
}
{SetupResource} SetupResources = ...;

tuple StorageTank {
	key string STORAGE_TANK_ID;
	string NAME;
	int QUANTITY_MAX;
	string SETUP_MATRIX_ID;
	int INITIAL_PRODUCT_ID;
}
{StorageTank} StorageTanks = ...;

tuple Step {
	key string STEP_ID;
	int PRODUCT_ID;
	string SETUP_RESOURCE_ID;
}
{Step} Steps = ...;

tuple Precedence {
	string PREDECESSOR_ID;
	string SUCCESSOR_ID;
	int DELAY_MIN;
	int DELAY_MAX;
}
{Precedence} Precedences = ...;

tuple Alternative {
	key string STEP_ID;
	key int ALTERNATIVE_NUMBER;
	string RESOURCE_ID;
	int FIXED_PROCESSING_TIME;
	float VARIABLE_PROCESSING_TIME;
	float FIXED_PROCESSING_COST;
	float VARIABLE_PROCESSING_COST;
}
{Alternative} Alternatives = ...;

tuple StorageProduction {
	key string PROD_STEP_ID;
	key string STORAGE_TANK_ID;
	string CONS_STEP_ID;
}
{StorageProduction} StorageProductions = ...;

tuple Setup {
	key string SETUP_MATRIX_ID;
	key int FROM_STATE;
	key int TO_STATE;
	int SETUP_TIME;
	int SETUP_COST;
}
{Setup} Setups = ...;

tuple CriterionWeight {
	key string CRITERION_ID;
	float WEIGHT;
}
{CriterionWeight} CriterionWeights = ...;

//our vars here..

execute {
//	cp.param.Workers = 1;
//	cp.param.TimeLimit = 5;
 
}

subject to {

}

tuple DemandAssignment {
	key string demandId;
	int startTime;
	int endTime;
	float nonDeliveryCost;
	float tardinessCost;
};
//{DemandAssignment} demandAssignments = fill in from your decision variables.
//{DemandAssignment} demandAssignments =
//{
//	<d.demandId,
//	startOf(something),
//	endOf(something),
//	someExpression,
//	someOtherExpression>
//	| d in Demands
//};

tuple StepAssignment {
	key string demandId;
	key string stepId;
	int startTime;
	int endTime;
	string resourceId;
	float procCost;
	float setupCost;
	int startTimeSetup;
	int endTimeSetup;
	string setupResourceId;
};
//{StepAssignment} stepAssignments = fill in from your decision variables.

tuple StorageAssignment {
	key string demandId;
	key string prodStepId;
	int startTime;
	int endTime;
	int quantity;
	string storageTankId;
};
//{StorageAssignment} storageAssignments = fill in from your decision variables.

execute {
	writeln("hello")

//	writeln("Total Non-Delivery Cost : ", TotalNonDeliveryCost);
//	writeln("Total Processing Cost : ", TotalProcessingCost);
//	writeln("Total Setup Cost : ", TotalSetupCost);
//	writeln("Total Tardiness Cost : ", TotalTardinessCost);
//	writeln();
//	writeln("Weighted Non-Delivery Cost : ",WeightedNonDeliveryCost);
//	writeln("Weighted Processing Cost : ", WeightedProcessingCost);
//	writeln("Weighted Setup Cost : ", WeightedSetupCost);
//	writeln("Weighted Tardiness Cost : ", WeightedTardinessCost);
//	writeln();
//	
//	for(var d in demandAssignments) 
//	{
//		writeln(d.demandId, ": [",	d.startTime, ",", d.endTime, "] ");
//		writeln(" non-delivery cost: ", d.nonDeliveryCost,	", tardiness cost: " , d.tardinessCost);
//	}
//	writeln();
//	for(var sa in stepAssignments) {
//		writeln(sa.stepId, " of ", sa.demandId,": [", sa.startTime, ",", sa.endTime, "] ","on ", sa.resourceId);
//		write(" processing cost: ", sa.procCost);
//		if (sa.setupCost > 0)
//			write(", setup cost: ", sa.setupCost);
//		writeln();
//		if (sa.startTimeSetup < sa.endTimeSetup)
//			writeln(" setup step: [",sa.startTimeSetup, ",", sa.endTimeSetup, "] ","on ", sa.setupResourceId);
//	}
//	writeln();
//	for(var sta in storageAssignments) {
//		if (sta.startTime < sta.endTime) {
//			writeln(sta.prodStepId, " of ", sta.demandId," produces quantity ", sta.quantity," in storage tank ", sta.storageTankId," at time ", sta.startTime," which is consumed at time ", sta.endTime);
//		}
//	}
}

