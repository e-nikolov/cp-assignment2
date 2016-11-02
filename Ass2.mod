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

//								End of input data





tuple DemandStep {
	Demand demand;
	Step step;
}
{DemandStep} DemSteps = {<d,st> | d in Demands, st in Steps : d.productId == st.productId};

dvar interval prodSteps[<dem,st> in DemSteps] //todo add "in min .. max" 
	optional(1);

//todo, some demands have minimum start 
dvar interval demand[d in Demands] //todo add "in min .. max" !!!!!!!!!!!!!!!!!!!!!! maybe no max.
	optional(1);

{int} ProductIds = union(p in Products) {p.productId};
tuple triplet {
	key int prod1; 
	key int prod2; 
	int value;
}; 

int maxResTime = max(s in Setups) s.setupTime;
{triplet} setupTimes[res in Resources] = // todo turn this into intervals somehow..
	{<p1,p2,t> | p1,p2 in ProductIds, stp in Setups, t in 0..maxResTime
		: stp.fromState == p1 && stp.toState == p2 
			&& stp.setupMatrixId == res.setupMatrixId && t == stp.setupTime};

{triplet} setupCosts[res in Resources] = // todo turn this into intervals somehow..
	{<p1,p2,c> | p1,p2 in ProductIds, stp in Setups, c in 0..maxint
		: stp.fromState == p1 && stp.toState == p2 
			&& stp.setupMatrixId == res.setupMatrixId && c == stp.setupCost};
//{triplet} setupTimesMissing[res in Resources] = // todo create the zeroes and unite this with 
//	{<p1,p2,0> | p1,p2 in ProductIds, stp in Setups // the above setupTimes?
//		: (stp.fromState != p1 || stp.toState != p2) 
//			&& stp.setupMatrixId == res.setupMatrixId};


range resRange = 0..max(res in Resources) res.resourceNr;
range prodRange = 0..max(p in ProductIds) p;
//int stpTimes[res in Resources][p1 in ProductIds][p2 in ProductIds] = [
int stpTimes[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];
int stpCosts[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];

tuple DemandStepAlternatives {
	DemandStep demStep;
	Alternative altern;
}
{DemandStepAlternatives} DemandStepAlternative = 
	{<<dem,st>,alt> | <dem,st> in DemSteps, alt in Alternatives
		: st.stepId == item(Steps, ord(Steps, <alt.stepId>)).stepId};
	
dvar interval demandStepAlternative[<<dem,st>,alt> in DemandStepAlternative] //todo add "in min .. max"
	optional(1)
	size ftoi(ceil(alt.fixedProcessingTime + alt.variableProcessingTime * dem.quantity));

dvar sequence resources[res in Resources] in
	all (dem in Demands,st in Steps, alt in Alternatives
		: res.resourceId == alt.resourceId && st.stepId == alt.stepId 
		  && dem.productId == item(Steps, ord(Steps, <alt.stepId>)).productId)
		    demandStepAlternative[<<dem,st>,alt>]
	types all(dem in Demands,st in Steps, alt in Alternatives
		: res.resourceId == alt.resourceId && st.stepId == alt.stepId 
		  && dem.productId == item(Steps, ord(Steps, <alt.stepId>)).productId) dem.productId; 

//                 Setups
{string} setupMatrixIDsNoNull = union(s in Setups) {s.setupMatrixId}; //{"SMX_CLEAN", "SMX_PROCESS", "SMX_STORAGE"};//
{string} setupMatrixIDs = setupMatrixIDsNoNull union {"NULL"}; //{"SMX_CLEAN", "SMX_PROCESS", "SMX_STORAGE", "NULL"};//
tuple ProductSetsInMatrix {
	int p1;
	int p2;
}
{ProductSetsInMatrix} productSetsInMatrix[s in setupMatrixIDs] 
						= {<stp.fromState, stp.toState> | stp in Setups: stp.setupMatrixId == s};

//dvar int costSetupMatrix[p in productSetsInMatrix] =;

dvar interval setupDemandStepAlternative[<<dem,st>,alt> in DemandStepAlternative]
	optional(1)
	size 0..maxl(max(res in Resources, <p1,p2> in productSetsInMatrix[res.setupMatrixId]
				: res.resourceId == alt.resourceId && res.setupMatrixId != "NULL") 
				item(Setups, ord(Setups, <res.setupMatrixId, p1,p2>)).setupTime, 0); //maybe calculate it better?

dvar int costSetupDemandeStepAlternative[<<dem,st>,alt> in DemandStepAlternative]; 

//dvar sequence setupResources[sRes in SetupResources] in //this is for the setups on steps
//	all (smth in smth : some condition) smthElse


//                  Storage tanks here
//dvar sequence storageTanks[stT in StorageTanks]
//	in all();

//make cumulFunctions with a sum of pulse (interval, quantity)

//todo add constraint alwaysIn for every storageTank. using the cumulFunction

pwlFunction tardinessFees[dem in Demands] = 
				piecewise{0->dem.due_time; dem.tardinessVariableCost}(dem.due_time, 0);
dexpr float TardinessCost = sum(dem in Demands) endEval(demand[dem], tardinessFees[dem]);

dexpr float NonDeliveryCost = sum(dem in Demands)
		 		(1 - presenceOf(demand[dem])) * (dem.quantity * dem.nonDeliveryVariableCost);

dexpr float ProcessingCost = sum(<<dem,st>,alt> in DemandStepAlternative) 
				presenceOf(demandStepAlternative[<<dem,st>,alt>]) // verify !!
				*(alt.fixedProcessingCost + dem.quantity * alt.variableProcessingCost);

//dexpr float SetupCost = 0; 
dexpr float SetupCost = sum(<<dem,st>,alt> in DemandStepAlternative)
				presenceOf(demandStepAlternative[<<dem,st>,alt>]) // verify !!
				* costSetupDemandeStepAlternative[<<dem,st>,alt>];
				//todo the cost of Storage settup needs to be added too !!!

dexpr float WeightedTardinessCost = 
		TardinessCost * item(CriterionWeights, ord(CriterionWeights, <"TardinessCost">)).weight;
dexpr float WeightedNonDeliveryCost = 
		NonDeliveryCost * item(CriterionWeights, ord(CriterionWeights, <"NonDeliveryCost">)).weight;
dexpr float WeightedProcessingCost =
		ProcessingCost * item(CriterionWeights, ord(CriterionWeights, <"ProcessingCost">)).weight;
dexpr float WeightedSetupCost = 
		SetupCost * item(CriterionWeights, ord(CriterionWeights, <"SetupCost">)).weight;

dexpr float TotalCost = WeightedTardinessCost + WeightedNonDeliveryCost + WeightedProcessingCost + WeightedSetupCost;

execute {
//	cp.param.Workers = 1;
	cp.param.TimeLimit = 10;
	
	for(var res in Resources)
		for(var t in setupTimes[res])
			stpTimes[Opl.ord(Resources, res)][t.prod1][t.prod2] = t.value;
			
	for(var res in Resources)
		for(var c in setupCosts[res])
			stpCosts[Opl.ord(Resources, res)][c.prod1][c.prod2]	= c.value;
//			stpCosts[Opl.ord(Resources, res)][c.prod1][c.prod2]	= Opl.item(Setups, Opl.ord(Setups, <res.setupMatrixId, c.prod1, c.prod2>)).setupCost;
//			stpCosts[Opl.ord(Resources, res)][c.prod1][c.prod2]	= Opl.item(Setups, Opl.ord(Setups, <"SMX_FERMENT", 0, 0>)).setupCost;

//	writeln(stpCosts);
//	writeln(stpTimes);
}
minimize 
  TotalCost;
subject to {	

  	forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
  	  : res.setupMatrixId == "NULL" && res.resourceId == alt.resourceId) {
  	  	!presenceOf(setupDemandStepAlternative[<<dem,st>,alt>]);
  	}

	forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
			: res.setupMatrixId != "NULL" && res.resourceId == alt.resourceId) {
		//depending on the dem.prodID and typeOfPrev(resources[res], demandStepAlternative[<<d,st>,alt>])	
		SetupTimeValid: lengthOf(setupDemandStepAlternative[<<dem,st>,alt>]) 
//			== item(setupTimes[res], ord(setupTimes[res], <typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId), dem.productId>)).value;
//			== item(setupTimes[res], ord(setupTimes[res], <0, dem.productId>)).value; //OVER HERE
//			== item(setupTimes[res], ord(setupTimes[res], <0, 0>)).value; 
//			== dem.productId
//			== typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId);
//			== 0;
			== stpTimes[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId)][dem.productId];

//		Or use a set of alternative intervals for each demStepAlt depending on the type of prev in resources[res] and make only the presenceOf the correct one True

		costSetupDemandeStepAlternative[<<dem,st>,alt>]
			== stpCosts[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId)][dem.productId];
  	}
//  	forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
//			: !(res.setupMatrixId != "NULL" && res.resourceId == alt.resourceId)) { //todo fix this forall. It's not doing what it's supposed to	
//		SetupTimeInvalid: lengthOf(setupDemandStepAlternative[<<dem,st>,alt>]) == 0;
//		costSetupDemandeStepAlternative[<<dem,st>,alt>] == 0; 
//  	}
  	forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
			: (res.setupMatrixId == "NULL" && res.resourceId == alt.resourceId)) { //todo fix this forall. It's not doing what it's supposed to	
		SetupTimeInvalid: lengthOf(setupDemandStepAlternative[<<dem,st>,alt>]) == 0;
		costSetupDemandeStepAlternative[<<dem,st>,alt>] == 0; 
  	}
  	
  	forall(<<dem,st>,alt> in DemandStepAlternative)
  		endAtStart(setupDemandStepAlternative[<<dem,st>,alt>], demandStepAlternative[<<dem,st>,alt>]);
  	    
	forall(<d,st> in DemSteps)
  		alternative(prodSteps[<d,st>], 
  			all(alt in Alternatives: alt.stepId == st.stepId) demandStepAlternative[<<d,st>,alt>]);
  	
	forall(res in Resources)
	    ResNoOverlap: noOverlap(resources[res], setupTimes[res], 1);
	    
	forall(<d,st> in DemSteps)
	  	presenceOf(demand[d]) == presenceOf(prodSteps[<d,st>]);
	
	forall(<d1,st1> in DemSteps, <d2,st2> in DemSteps, p in Precedences
				:st1.stepId == p.predecessorId && st2.stepId == p.successorId && d1 == d2)
		endBeforeStart(prodSteps[<d1,st1>], prodSteps[<d2,st2>]);
	
	forall(d in Demands)
	    span(demand[d], all(st in Steps : d.productId == st.productId) prodSteps[<d,st>]);
	
	//todo use endAtStart for storage!
	
	//todo if the 
	

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

