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

dvar interval prodSteps[<dem,st> in DemSteps] //todo add "in min .. max" 
	optional(1);

//todo, some demands have minimum
dvar interval demand[d in Demands] //todo add "in min .. max"
	optional(1);

{int} ProductIds = union(p in Products) {p.productId};
tuple triplet {int prod1; int prod2; int time;}; 

int maxResTime = max(s in Setups) s.setupTime;
{triplet} setupTimes[res in Resources] = 
	{<p1,p2,t> | p1,p2 in ProductIds, t in 0..maxResTime: t == p1};
//	{<p1,p2,t> | p1,p2 in ProductIds, stp in Setups, t in 0..maxResTime
//		: stp.fromState == p1 && stp.toState == p2 
//			&& stp.setupMatrixId == res.setupMatrixId && t == stp.setupTime};

tuple DemandStepAlternatives {
	DemandStep demStep;
	Alternative altern;
}
{DemandStepAlternatives} DemandStepAlternative = 
	{<<dem,st>,alt> | <dem,st> in DemSteps, alt in Alternatives
		: st.stepId == item(Steps, ord(Steps, <alt.stepId>)).stepId};
dvar interval DemStepAlternative[<<dem,st>,alt> in DemandStepAlternative] //todo add "in min .. max"
	optional(1)
	size ftoi(ceil(alt.fixedProcessingTime + alt.variableProcessingTime * dem.quantity));

	
dvar sequence resources[res in Resources] in
	all (dem in Demands,st in Steps, alt in Alternatives
		: res.resourceId == alt.resourceId && st.stepId == alt.stepId 
		  && dem.productId == item(Steps, ord(Steps, <alt.stepId>)).productId)
		    DemStepAlternative[<<dem,st>,alt>];


pwlFunction tardinessFees[dem in Demands] = 
				piecewise{0->dem.due_time; dem.tardinessVariableCost}(dem.due_time, 0);
dexpr float TardinessCost = sum(dem in Demands) endEval(demand[dem], tardinessFees[dem]);

dexpr float NonDeliveryCost = sum(dem in Demands)
		 		(1 - presenceOf(demand[dem])) * (dem.quantity * dem.nonDeliveryVariableCost);

dexpr float ProcessingCost = sum(<<dem,st>,alt> in DemandStepAlternative) 
								presenceOf(DemStepAlternative[<<dem,st>,alt>])
								*(alt.fixedProcessingCost + dem.quantity * alt.variableProcessingCost);

dexpr float SetupCost = 0;

dexpr float WeightedTardinessCost = 
		TardinessCost * item(CriterionWeights, ord(CriterionWeights, <"TardinessCost">)).weight;
dexpr float WeightedNonDeliveryCost = 
		NonDeliveryCost * item(CriterionWeights, ord(CriterionWeights, <"NonDeliveryCost">)).weight;
dexpr float WeightedProcessingCost =
		ProcessingCost * item(CriterionWeights, ord(CriterionWeights, <"ProcessingCost">)).weight;
dexpr float WeightedSetupCost = 
		SetupCost * item(CriterionWeights, ord(CriterionWeights, <"SetupCost">)).weight;


execute {
	cp.param.Workers = 1;
	cp.param.TimeLimit = 30;
}
minimize 
  WeightedTardinessCost + WeightedNonDeliveryCost + WeightedProcessingCost + WeightedSetupCost;
subject to {	    
	forall(<d,st> in DemSteps)
  		alternative(prodSteps[<d,st>], 
  			all(alt in Alternatives: alt.stepId == st.stepId) DemStepAlternative[<<d,st>,alt>]);
  		
	forall(res in Resources)
	    noOverlap(resources[res], setupTimes[res], 1);
	    
	forall(<d,st> in DemSteps)
	  	presenceOf(demand[d]) == presenceOf(prodSteps[<d,st>]);
	
	forall(<d1,st1> in DemSteps, <d2,st2> in DemSteps, p in Precedences
				:st1.stepId == p.predecessorId && st2.stepId == p.successorId && d1 == d2)
		endBeforeStart(prodSteps[<d1,st1>], prodSteps[<d2,st2>]);
	
	forall(d in Demands)
	    span(demand[d], all(st in Steps : d.productId == st.productId) prodSteps[<d,st>]);
	    
	
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

