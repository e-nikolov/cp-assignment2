/*********************************************
 * OPL 12.6.3.0 Model
 * Author: enikolov
 * Creation Date: 19 Oct 2016 at 15:23:24
 *********************************************/

using CP;

tuple Product {
	key int productId;
	string name;
}
{Product} Products = ...;

tuple Demand {
	key string demandId;
	int productId	;
	int quantity;
	int deliveryMin;
	int deliveryMax;
	float nonDeliveryVariableCost;
	int due_time;
	float tardinessVariableCost;
}
{Demand} Demands = ...;

tuple Resource {
	key string resourceId;
	int resourceNr;
	string setupMatrixId;
	int initialProductId;
}
{Resource} Resources = ...;

tuple SetupResource {
	key string setupResourceId;
}
{SetupResource} SetupResources = ...;

tuple StorageTank {
	key string storageTankId;
	string name;
	int quantityMax;
	string setupMatrixId;
	int initialProductId;
}
{StorageTank} StorageTanks = ...;

tuple Step {
	key string stepId;
	int productId;
	string setupResourceId;
}
{Step} Steps = ...;

tuple Precedence {
	string predecessorId;
	string successorId;
	int delayMin;
	int delayMax;
}
{Precedence} Precedences = ...;

tuple Alternative {
	key string stepId;
	key int alternativeNumber;
	string resourceId;
	int fixedProcessingTime;
	float variableProcessingTime;
	float fixedProcessingCost;
	float variableProcessingCost;
}
{Alternative} Alternatives = ...;

tuple StorageProduction {
	key string prodStepId;
	key string storageTankId;
	string consStepId;
}
{StorageProduction} StorageProductions = ...;

tuple Setup {
	key string setupMatrixId;
	key int fromState;
	key int toState;
	int setupTime;
	int setupCost;
}
{Setup} Setups = ...;

{string} CritConsts = {"NonDeliveryCost", "ProcessingCost", "SetupCost", "TardinessCost"};
tuple CriterionWeight {
	key string criterionId;
	float weight;
}
{CriterionWeight} CriterionWeights with criterionId in CritConsts = ...;

tuple DemandStep {
	Demand demand;
	Step step;
}
{DemandStep} DemSteps = {<d,st> | d in Demands, st in Steps : d.productId == st.productId};

dvar interval operations[<d,st> in DemSteps] 
	optional(1);

pwlFunction tardinessFees[dem in Demands] = piecewise{0->100; 400}(100, 0); //todo get it from the xls data

dexpr float NonDeliveryCost = 0;
dexpr float ProcessingCost = 0;
dexpr float SetupCost = 0;
// this gonna be a sum of all demand [max of all 'step' endEval(operations[demand][<'step'>], tardinessFees)]
dexpr float TardinessCost = 0;

execute {
//	cp.param.Workers = 1;
//	cp.param.TimeLimit = 5;
 
}
minimize
  NonDeliveryCost * item(CriterionWeights, ord(CriterionWeights, <"NonDeliveryCost">)).weight
  + ProcessingCost * item(CriterionWeights, ord(CriterionWeights, <"ProcessingCost">)).weight
  + SetupCost * item(CriterionWeights, ord(CriterionWeights, <"SetupCost">)).weight
  + TardinessCost * item(CriterionWeights, ord(CriterionWeights, <"TardinessCost">)).weight;
subject to {
	forall(<d,st> in DemSteps) // setting the size this way
	    endOf(operations[<d,st>]) - startOf(operations[<d,st>]) == 20
	    ||
	    endOf(operations[<d,st>]) - startOf(operations[<d,st>]) == 10;
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
	writeln("hello");
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

