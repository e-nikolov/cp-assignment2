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

dvar interval prodSteps[<dem,st> in DemSteps] // size is taken from alternatives.
	optional;

dvar interval demand[d in Demands]
	optional
	in d.deliveryMin..d.deliveryMax;

{int} ProductIds = union(p in Products) {p.productId};

tuple triplet {
	key int prod1; 
	key int prod2; 
	int value;
}; 

int maxResTime = max(s in Setups) s.setupTime;
{triplet} setupTimes[res in Resources] =
	{<p1,p2,t> | p1,p2 in ProductIds, stp in Setups, t in 0..maxResTime
		: stp.fromState == p1 && stp.toState == p2 
			&& stp.setupMatrixId == res.setupMatrixId && t == stp.setupTime};

{triplet} setupCosts[res in Resources] =
	{<p1,p2,c> | p1,p2 in ProductIds, stp in Setups, c in 0..maxint
		: stp.fromState == p1 && stp.toState == p2 
			&& stp.setupMatrixId == res.setupMatrixId && c == stp.setupCost};


range resRange = 0..card(Resources);
range prodRange = 0..card(ProductIds);

int stpTimes[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];
int stpCosts[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];

tuple DemandStepAlternatives {
	DemandStep demStep;
	Alternative altern;
}
{DemandStepAlternatives} DemandStepAlternative = 
	{<<dem,st>,alt> | <dem,st> in DemSteps, alt in Alternatives
		: st.stepId == item(Steps, <alt.stepId>).stepId};
	
dvar interval demandStepAlternative[<<dem,st>,alt> in DemandStepAlternative]
	optional(1)
	in dem.deliveryMin..dem.deliveryMax
	size ftoi(ceil(alt.fixedProcessingTime + alt.variableProcessingTime * dem.quantity));

dvar sequence resources[res in Resources] in
	all (dem in Demands, st in Steps, alt in Alternatives
		: res.resourceId == alt.resourceId && st.stepId == alt.stepId 
		  && dem.productId == item(Steps, <alt.stepId>).productId)
		    demandStepAlternative[<<dem,st>,alt>]
	types all(dem in Demands,st in Steps, alt in Alternatives
		: res.resourceId == alt.resourceId && st.stepId == alt.stepId 
		  && dem.productId == item(Steps, <alt.stepId>).productId) dem.productId; 

//                 Setups
{string} setupMatrixIDsNoNull = union(s in Setups) {s.setupMatrixId};
{string} setupMatrixIDs = setupMatrixIDsNoNull union {"NULL"};
tuple ProductSetsInMatrix {
	int p1;
	int p2;
}
{ProductSetsInMatrix} productSetsInMatrix[s in setupMatrixIDs] 
						= {<stp.fromState, stp.toState> | stp in Setups: stp.setupMatrixId == s};

dvar interval setupDemandStepAlternative[<<dem,st>,alt> in DemandStepAlternative]
	optional(1) //todo try it with (0) .. the size is already set to 0 when uneeded.
	size 0..maxl(max(res in Resources, <p1,p2> in productSetsInMatrix[res.setupMatrixId]
				: res.resourceId == alt.resourceId && res.setupMatrixId != "NULL") 
				item(Setups, <res.setupMatrixId, p1,p2>).setupTime, 0); //maybe calculate it better?

dvar sequence setupResources[setRes in SetupResources] in
	all (dem in Demands, st in Steps, alt in Alternatives
		: setRes.setupResourceId == st.setupResourceId && st.stepId == alt.stepId 
		  && dem.productId == item(Steps, <alt.stepId>).productId)
		    setupDemandStepAlternative[<<dem,st>,alt>];

dvar int costSetupDemandeStepAlternative[<<dem,st>,alt> in DemandStepAlternative]; 

//                   Storage tanks

// get the stepID's of steps that are first. The storage before these steps will be 0 0 0.
{string} stepIDs = union(st in Steps) {st.stepId};
//{string} stepsWithPredecessorIDs = union(pr in Precedences) {pr.successorId};
{string} stepsWithSuccessorIDs = union(pr in Precedences) {pr.predecessorId};
{string} endingStepsIDs = stepIDs diff stepsWithSuccessorIDs;
 
//todo this calculation can be better. The sum of the minimum quantit 
int maxDemandStoreTime[dem in Demands] = dem.deliveryMax - dem.deliveryMin;
//		- sum(st in Steps) min(alt in Alternatives) where st.productId == dem.productId && alt.stepId == st.stepId;

tuple minMaxStorageTimes {
	key string stepId;
	int minTime;
	int maxTime;
}

{minMaxStorageTimes} minMaxStepStorageTime[st in stepIDs]
						= {<st, pr.delayMin, pr.delayMax> | pr in Precedences : pr.predecessorId == st}
						  union 
						  {<st2, 0, 0> | st2 in endingStepsIDs : st2 == st};

dvar interval storageAfterProdStep[<dem,st> in DemSteps]
	optional
	in dem.deliveryMin..dem.deliveryMax
	size item(minMaxStepStorageTime[st.stepId], <st.stepId>).minTime 
		 .. 
		 minl(item(minMaxStepStorageTime[st.stepId], <st.stepId>).maxTime, maxDemandStoreTime[dem]);
	
tuple StorageAfterProdStepAlternatives {
	DemandStep demStep;
	StorageProduction storProd;
}	
{StorageAfterProdStepAlternatives} StorageAfterProdStepAlternative = 
	 {<<dem,st>,storProd> | <dem,st> in DemSteps, storProd in StorageProductions
	 : st.stepId == storProd.prodStepId};
	 
dvar interval storageAfterProdStepAlternatives[<<dem,st>,storProd> in StorageAfterProdStepAlternative]
	optional
	in dem.deliveryMin..dem.deliveryMax
	size item(minMaxStepStorageTime[st.stepId], <st.stepId>).minTime 
		 .. 
		 minl(item(minMaxStepStorageTime[st.stepId], <st.stepId>).maxTime, maxDemandStoreTime[dem]);	

tuple Shits {
	StorageAfterProdStepAlternatives alt1;
	StorageAfterProdStepAlternatives alt2;
}
// all sets of 2 intervals that need to not overlap!
{Shits} Shit = {<<<dem1,st1>,storProd1>, <<dem2,st2>,storProd2>> | 
					<<dem1,st1>,storProd1> in StorageAfterProdStepAlternative,
					<<dem2,st2>,storProd2> in StorageAfterProdStepAlternative 
					: dem1.productId != dem2.productId 
					  && storProd1.storageTankId == storProd2.storageTankId};

dvar sequence storageShit[<sht1, sht2> in Shit] 
		in all(sht in StorageAfterProdStepAlternative : sht == sht1 || sht == sht2) 
						storageAfterProdStepAlternatives[sht]
		types all(sht in StorageAfterProdStepAlternative : sht == sht1 || sht == sht2) 
						sht.demStep.demand.productId;

cumulFunction tankCapOverTime[stT in StorageTanks] 
		= sum(<dem,st> in DemSteps, stPrd in StorageProductions : stPrd.storageTankId == stT.storageTankId && stPrd.consStepId == st.stepId)
			pulse(storageAfterProdStep[<dem,st>], dem.quantity);

//todo setup costs for the storage need to be added too..

//                       COSTS

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
		TardinessCost * item(CriterionWeights, <"TardinessCost">).weight;
dexpr float WeightedNonDeliveryCost = 
		NonDeliveryCost * item(CriterionWeights, <"NonDeliveryCost">).weight;
dexpr float WeightedProcessingCost =
		ProcessingCost * item(CriterionWeights, <"ProcessingCost">).weight;
dexpr float WeightedSetupCost = 
		SetupCost * item(CriterionWeights, <"SetupCost">).weight;

dexpr float TotalCost = WeightedTardinessCost + WeightedNonDeliveryCost + WeightedProcessingCost + WeightedSetupCost;

execute {
	cp.param.Workers = 1;
	cp.param.TimeLimit = Opl.card(Demands);
	
	for(var res in Resources)
		for(var t in setupTimes[res])
			stpTimes[Opl.ord(Resources, res)][t.prod1][t.prod2] = t.value;
			
	for(var res in Resources)
		for(var c in setupCosts[res])
			stpCosts[Opl.ord(Resources, res)][c.prod1][c.prod2]	= c.value;

}
minimize 
  TotalCost;
subject to {
	// Making sure the unimportnat intervals are not cousing any useless test cases
  	forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
			: res.setupMatrixId == "NULL" && res.resourceId == alt.resourceId) {
						
		!presenceOf(setupDemandStepAlternative[<<dem,st>,alt>]);
		lengthOf(setupDemandStepAlternative[<<dem,st>,alt>]) == 0;
		costSetupDemandeStepAlternative[<<dem,st>,alt>] == 0; 
  	}

  	//todo set the size of all storage intervals of before first steps to 0!
  	//todo also set their start/end times to 0
//  	forall(<dem,st> in DemSteps : st.stepId in endingStepsIDs) {
//  	    !presenceOf(storageAfterProdStep[<dem,st>]);
//  	    startOf(storageAfterProdStep[<dem,st>]) == dem.deliveryMin; //todo remove?
//     }  	    
 	
  	// All setup intervals are just before the interval they precede
  	forall(<<dem,st>,alt> in DemandStepAlternative)
  		endAtStart(setupDemandStepAlternative[<<dem,st>,alt>], demandStepAlternative[<<dem,st>,alt>]);
  	
  	//fix the position of all storage intervals (their end times and start times) //todo Actually do it
  	forall(<<dem,st>,storProd> in StorageAfterProdStepAlternative : st.stepId in stepsWithSuccessorIDs){
  	  	endAtStart(storageAfterProdStepAlternatives[<<dem,st>,storProd>]
  	  		, prodSteps[<dem,item(Steps, <storProd.consStepId>)>]);
  	  	startAtEnd(storageAfterProdStepAlternatives[<<dem,st>,storProd>]
  	  		, prodSteps[<dem,st>]);
     }  
     
     forall(<dem,st> in DemSteps : st.stepId in stepsWithSuccessorIDs)
       presenceOf(storageAfterProdStep[<dem,st>]);//todo necessary? wrong?	    	
    
    // storages need to chose which tank to use. chose just one alternative each
    forall(<dem,st> in DemSteps : st.stepId in stepsWithSuccessorIDs)
  	  	alternative(storageAfterProdStep[<dem,st>],
  	  		all(storProd in StorageProductions : st.stepId == storProd.prodStepId) 
  	  			storageAfterProdStepAlternatives[<<dem,st>,storProd>]);
	
  	// If a demand is present, all the steps it requires must be present too (and vice versa)
  	forall(<dem,st> in DemSteps)
	  	presenceOf(demand[dem]) == presenceOf(prodSteps[<dem,st>]);
	
	forall(<dem,st> in DemSteps : st.stepId in stepsWithSuccessorIDs)
  	    presenceOf(demand[dem]) == presenceOf(storageAfterProdStep[<dem,st>]);

  	// Every step must be one and only one of it's alternatives 
	forall(<dem,st> in DemSteps)
  		alternative(prodSteps[<dem,st>], 
  			all(alt in Alternatives: alt.stepId == st.stepId) demandStepAlternative[<<dem,st>,alt>]);
  	
  	// steps using the same resource must not overlap
	forall(res in Resources)
	    noOverlap(resources[res], setupTimes[res], 1);
	
	// tank intervals with different products and same tank should not overlap
	//todo add setup time for the tanks!
//	forall(sht in Shit)
//		noOverlap(storageShit[sht]);
		
	// setting the setup time and cost of setups before each step. 
	forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
					: res.setupMatrixId != "NULL" && res.resourceId == alt.resourceId) {	
		lengthOf(setupDemandStepAlternative[<<dem,st>,alt>]) 
			== stpTimes[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId)][dem.productId];
			
		costSetupDemandeStepAlternative[<<dem,st>,alt>]
			== stpCosts[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId)][dem.productId];
  	}
	    
	// setups using the same setup resource must not overlap
	forall(stpRes in SetupResources)
	  	noOverlap(setupResources[stpRes]);
	
	// precedence requirement for different steps on a product
	forall(<d1,st1> in DemSteps, <d2,st2> in DemSteps, p in Precedences
				:st1.stepId == p.predecessorId && st2.stepId == p.successorId && d1 == d2)
		endBeforeStart(prodSteps[<d1,st1>], prodSteps[<d2,st2>]);
  	
  	// the steps on a product of a demand should be spanned in the demand interval
	forall(dem in Demands)
	    span(demand[dem], all(st in Steps : dem.productId == st.productId) prodSteps[<dem,st>]);
	
	//todo add constraint that the cumulFucntion's are <= the cap of the storageTank
	forall(stT in StorageTanks)
	    tankCapOverTime[stT] <= stT.quantityMax;
	
	//todo if the ..{ I wonder what I was going to write here if the IDE hadn't crashed before finishing this line }
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
