/*********************************************
 * OPL 12.6.3.0 Model
 * Authors: Emil Nikolov - 0972305 - e.e.nikolov@student.tue.nl
 *          Petar Stoykov - 0976265 - p.stoykov@student.tue.nl
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
    int productId   ;
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

//                              End of input data





tuple DemandStep {
    Demand demand;
    Step step;
}
{DemandStep} DemSteps = {<d,st> | d in Demands, st in Steps : d.productId == st.productId};

dvar interval prodSteps[<dem,st> in DemSteps] // size is taken from alternatives.
    optional;

dvar interval demand[d in Demands]
    optional
    in 0..d.deliveryMax;

{int} ProductIds = union(p in Products) {p.productId};

tuple triplet {
    key int prod1; 
    key int prod2; 
    int value;
}; 

{triplet} setupTimesResources[res in Resources] =
    {
        <stp.fromState,stp.toState,stp.setupTime> | 
        stp in Setups : stp.setupMatrixId == res.setupMatrixId
    };

//{triplet} setupCostsResources[res in Resources] =
//  {<p1,p2,c> | p1,p2 in ProductIds, stp in Setups, c in 0..maxint
//      : stp.fromState == p1 && stp.toState == p2 
//          && stp.setupMatrixId == res.setupMatrixId && c == stp.setupCost};


//range resRange = 0..card(Resources)-1;
//range prodRange = 0..card(ProductIds)-1;
//int stpTimes[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];
//int stpCosts[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];

int resSetupCost[r in Resources][p1 in ProductIds union {-1}][p2 in ProductIds] =
    sum(<r.setupMatrixId, p1, p2, time, cost> in Setups) cost;
    
int resSetupTime[r in Resources][p1 in ProductIds union {-1}][p2 in ProductIds] =
    sum(<r.setupMatrixId, p1, p2, time, cost> in Setups) time;
      
tuple DemandStepAlternatives {
    DemandStep demStep;
    Alternative altern;
}
{DemandStepAlternatives} DemandStepAlternative = 
    {<<dem,st>,alt> | <dem,st> in DemSteps, alt in Alternatives
        : st.stepId == alt.stepId};
    
dvar interval demandStepAlternative[<<dem,st>,alt> in DemandStepAlternative]
    optional
    in 0..dem.deliveryMax
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
//{string} setupMatrixIDsNoNull = union(s in Setups) {s.setupMatrixId};
//{string} setupMatrixIDs = setupMatrixIDsNoNull union {"NULL"};
//tuple ProductSetsInMatrix {
//    int p1;
//    int p2;
//}
//{ProductSetsInMatrix} productSetsInMatrix[s in setupMatrixIDs] 
//                        = {<stp.fromState, stp.toState> | stp in Setups: stp.setupMatrixId == s};

dvar interval setupDemandStepAlternative[<<dem,st>,alt> in DemandStepAlternative]
    optional;
//  size 0..9999;
//  size 0..maxl(max(res in Resources, <p1,p2> in productSetsInMatrix[res.setupMatrixId]
//              : res.resourceId == alt.resourceId && res.setupMatrixId != "NULL") 
//              item(Setups, <res.setupMatrixId, p1,p2>).setupTime, 0); //maybe calculate it better?

dvar sequence setupResources[setRes in SetupResources] in
    all (dem in Demands, st in Steps, alt in Alternatives
        : setRes.setupResourceId == st.setupResourceId && st.stepId == alt.stepId 
          && dem.productId == item(Steps, <alt.stepId>).productId)
            setupDemandStepAlternative[<<dem,st>,alt>];

dvar int costSetupDemandeStepAlternative[<<dem,st>,alt> in DemandStepAlternative]; 

//                   Storage tanks

// get the stepID's of steps that are last. The storage after these steps will be 0 0 0.
{string} stepIDs = union(step in Steps) {step.stepId};
{string} stepsWithPredecessorIDs = union(precedence in Precedences) {precedence.successorId};
{string} stepsWithSuccessorIDs = union(precedence in Precedences) {precedence.predecessorId};
{string} endingStepsIDs = stepIDs diff stepsWithSuccessorIDs;
{string} startingStepsIDs = stepIDs diff stepsWithPredecessorIDs;
 
//todo this calculation can be better. The sum of all minimum alternative of lenghths of intervals of steps. 
int maxDemandStoreTime[dem in Demands] = dem.deliveryMax;
//      - sum(st in Steps) min(alt in Alternatives) where st.productId == dem.productId && alt.stepId == st.stepId;

tuple minMaxStorageTimes {
    key string stepId;
    int minTime;
    int maxTime;
}

// The time bounds depend both on the previous and following step, but it seems like this is only calculating it based on the previous step??
{minMaxStorageTimes} minMaxStepStorageTime[st in stepIDs]
                        = {<st, pr.delayMin, pr.delayMax> | pr in Precedences : pr.predecessorId == st}
                          union 
                          {<st2, 0, 0> | st2 in endingStepsIDs : st2 == st};

dvar interval storageAfterProdStep[<dem,st> in DemSteps]
    optional
    //in 0..dem.deliveryMax
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
    //in 0..dem.deliveryMax
    size item(minMaxStepStorageTime[st.stepId], <st.stepId>).minTime 
         .. 
         minl(item(minMaxStepStorageTime[st.stepId], <st.stepId>).maxTime, maxDemandStoreTime[dem]);    

{triplet} setupTimesStorage[t in StorageTanks] =
    {<p1, p2, time> | <t.setupMatrixId, p1, p2, time, cost> in Setups};
//  {<stp.fromState, stp.toState, stp.setupTime> 
//      | stp in Setups : stp.setupMatrixId == t.setupMatrixId};

int tankSetupTime[t in StorageTanks][p1 in ProductIds union {-1}][p2 in ProductIds] =
    sum(<t.setupMatrixId, p1, p2, time, cost> in Setups) time;
//{triplet} setupCostsStorage[t in StorageTanks] =
//  {<p1, p2, cost> | <t.setupMatrixId, p1, p2, time, cost> in Setups};
//  {<stp.fromState, stp.toState, stp.setupCost> 
//      | stp in Setups : stp.setupMatrixId == t.setupMatrixId};


//range tankRange = 0..card(StorageTanks)-1;
//int storageSetupCosts[tankRange][prodRange][prodRange] = [ t : [ p1 : [ p2: 0]] | t in tankRange, p1,p2 in prodRange];

//dvar int costStorageAfterProdStepAlternatives[<<dem,st>,storProd> in StorageAfterProdStepAlternative]; 
    
statefunction tankState[stT in StorageTanks] with setupTimesStorage[stT];

//dvar sequence storageTankSeq[t in StorageTanks]
//      in all(<<dem,st>,storProd> in StorageAfterProdStepAlternative
//                  : storProd.storageTankId == t.storageTankId)
//          storageAfterProdStepAlternatives[<<dem,st>,storProd>]
//      types all(<<dem,st>,storProd> in StorageAfterProdStepAlternative
//                  : storProd.storageTankId == t.storageTankId)
//          dem.productId;

cumulFunction tankCapOverTime[tank in StorageTanks] 
        = sum(<dem,st> in DemSteps, alternativeTank in StorageProductions 
            : alternativeTank.storageTankId == tank.storageTankId && alternativeTank.prodStepId == st.stepId)
                pulse(storageAfterProdStepAlternatives[<<dem,st>, alternativeTank>], dem.quantity);

//                       COSTS

pwlFunction tardinessFees[dem in Demands] = 
                piecewise{0->dem.due_time; dem.tardinessVariableCost}(dem.due_time, 0);
dexpr float TotalTardinessCost = sum(dem in Demands) endEval(demand[dem], tardinessFees[dem]);

dexpr float TotalNonDeliveryCost = sum(dem in Demands)
                (1 - presenceOf(demand[dem])) * (dem.quantity * dem.nonDeliveryVariableCost);

dexpr float TotalProcessingCost = sum(<<dem,st>,alt> in DemandStepAlternative) 
                presenceOf(demandStepAlternative[<<dem,st>,alt>])
                *(alt.fixedProcessingCost + dem.quantity * alt.variableProcessingCost);

//dexpr float SetupCost = 0; 
dexpr float TotalSetupCost = sum(<<dem,st>,alt> in DemandStepAlternative)
                            costSetupDemandeStepAlternative[<<dem,st>,alt>];
//                      + sum(<<dem,st>,storProd> in StorageAfterProdStepAlternative)
//                          costStorageAfterProdStepAlternatives[<<dem,st>,storProd>]; 

dexpr float WeightedTardinessCost = 
        TotalTardinessCost * item(CriterionWeights, <"TardinessCost">).weight;
dexpr float WeightedNonDeliveryCost = 
        TotalNonDeliveryCost * item(CriterionWeights, <"NonDeliveryCost">).weight;
dexpr float WeightedProcessingCost =
        TotalProcessingCost * item(CriterionWeights, <"ProcessingCost">).weight;
dexpr float WeightedSetupCost = 
        TotalSetupCost * item(CriterionWeights, <"SetupCost">).weight;

dexpr float TotalCost = WeightedTardinessCost + WeightedNonDeliveryCost + WeightedProcessingCost + WeightedSetupCost;

execute {
    cp.param.Workers = 1;
    
//    cp.param.DefaultInferenceLevel = "Extended";
//    cp.param.DefaultInferenceLevel = "Low";
    cp.param.DefaultInferenceLevel = "Medium";
    
    if(Opl.card(Demands) < 33)
    	cp.param.restartfaillimit = 100;
    
    var f = cp.factory;
//  cp.setSearchPhases(f.searchPhase(resources));
//  cp.setSearchPhases(f.searchPhase(prodSteps));
//	cp.setSearchPhases(f.searchPhase(demand));
//	cp.setSearchPhases(f.searchPhase(setupResources));
    if (Opl.card(Demands) < 30) {
	   cp.setSearchPhases(f.searchPhase(demandStepAlternative));
    }
//  cp.setSearchPhases(f.searchPhase(resources), f.searchPhase(prodSteps), f.searchPhase(demand));
    
    cp.param.TimeLimit = Opl.card(Demands);
//    cp.param.TimeLimit = 10*Opl.card(Demands);
}

minimize 
  TotalCost;
subject to {
    
    //end of the last steps must be after the mindeliverytime.
    forall(<dem,st> in DemSteps : st.stepId in endingStepsIDs) {
        endOf(prodSteps[<dem,st>], dem.deliveryMin) >= dem.deliveryMin;
        endOf(prodSteps[<dem,st>], dem.deliveryMax) <= dem.deliveryMax;
    }
    
    // this won't be needed in the new model
    forall(<dem,st> in DemSteps : st.stepId in endingStepsIDs) {
        !presenceOf(storageAfterProdStep[<dem,st>]);
        lengthOf(storageAfterProdStep[<dem,st>]) == 0;
    }
           
    //causes valid but worse solutions.
//    forall(<<dem,st>,storProd> in StorageAfterProdStepAlternative : st.stepId in endingStepsIDs){
//        !presenceOf(storageAfterProdStepAlternatives[<<dem,st>,storProd>]);
//        lengthOf(storageAfterProdStepAlternatives[<<dem,st>,storProd>]) == 0;
//    }
    
    // All setup intervals are just before the interval they precede
    forall(<<dem,st>,alt> in DemandStepAlternative)
        endAtStart(setupDemandStepAlternative[<<dem,st>,alt>], demandStepAlternative[<<dem,st>,alt>]);
    
    //fix the position of all storage intervals (their end times and start times)
    forall(<<dem,st>,storProd> in StorageAfterProdStepAlternative : st.stepId in stepsWithSuccessorIDs){
        endAtStart(storageAfterProdStepAlternatives[<<dem,st>,storProd>]
            , prodSteps[<dem,item(Steps, <storProd.consStepId>)>]);
        startAtEnd(storageAfterProdStepAlternatives[<<dem,st>,storProd>]
            , prodSteps[<dem,st>]);
     }
    
    // storages need to chose which tank to use. chose just one alternative each
    forall(<dem,st> in DemSteps : st.stepId in stepsWithSuccessorIDs)
        alternative(storageAfterProdStep[<dem,st>],
            all(storProd in StorageProductions : st.stepId == storProd.prodStepId) 
                storageAfterProdStepAlternatives[<<dem,st>,storProd>]);
    
    // if a demand is not present, there must not be any storage happening.
    // this will be handled in the print end because it doesnt affect the other var's, it just slows the model down.
//    forall(<dem,st> in DemSteps, storProd in StorageProductions 
//    	: st.stepId in stepsWithSuccessorIDs && st.stepId == storProd.prodStepId)
//          	!presenceOf(demand[dem]) => !presenceOf(storageAfterProdStepAlternatives[<<dem,st>,storProd>]); 
    
    // If a demand is present, all the steps it requires must be present too (and vice versa)
    forall(<dem,st> in DemSteps)
        presenceOf(demand[dem]) == presenceOf(prodSteps[<dem,st>]);
    
    //// storage intervals are present/absent the same as their demand
    //// ???? what if a product doesn't need to be stored? the storage interval should not be present

    //// storage intervals are present/absent the same as their demand
    //forall(<dem,st> in DemSteps : st.stepId in stepsWithSuccessorIDs) {
    //    //presenceOf(demand[dem]) == presenceOf(storageAfterProdStep[<dem,st>]);
    //    presenceOf(storageAfterProdStep[<dem,st>]) == (lengthOf(storageAfterProdStep[<dem,st>]) > 0);  
    //}

    //forall(<<dem,st>,storProd> in StorageAfterProdStepAlternative : st.stepId in stepsWithSuccessorIDs){

    //    //!presenceOf(storageAfterProdStep[<dem,st>] => presenceOf(demand[dem]);
    //    presenceOf(storageAfterProdStepAlternatives[<<dem,st>,storProd>]) == (lengthOf(storageAfterProdStepAlternatives[<<dem,st>,storProd>]) > 0);  
    //}        
//       if a demand is not present then all the setup intervals should not be present too.
    // seems to give worse results sometimes
    //forall(<<dem,st>,alt> in DemandStepAlternative)
    //    !presenceOf(demand[dem]) => !presenceOf(setupDemandStepAlternative[<<dem,st>,alt>]);

    // Every step must be one and only one of it's alternatives 
    forall(<dem,st> in DemSteps)
        alternative(prodSteps[<dem,st>], 
            all(alt in Alternatives: alt.stepId == st.stepId) demandStepAlternative[<<dem,st>,alt>]);
    
    // steps using the same resource must not overlap
    forall(res in Resources)
        noOverlap(resources[res], setupTimesResources[res], 1);
    
        
    // setting the setup time and cost of setups before each step. 
    forall(<<dem,st>,alt> in DemandStepAlternative, res in Resources 
                    : res.resourceId == alt.resourceId) {
        
        presenceOf(setupDemandStepAlternative[<<dem,st>,alt>]) ==
            presenceOf(demandStepAlternative[<<dem,st>,alt>]);
        
        setupLenConstraint: lengthOf(setupDemandStepAlternative[<<dem,st>,alt>])// == 0;
            == resSetupTime[res][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId, -1)][dem.productId];
//          == stpTimes[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId)][dem.productId];
            
        setupCostConstraint: costSetupDemandeStepAlternative[<<dem,st>,alt>]//== 0;
            == resSetupCost[res][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId, -1)][dem.productId];
//          == stpCosts[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<<dem,st>,alt>], res.initialProductId)][dem.productId];
    }
        
    // setups using the same setup resource must not overlap
    forall(stpRes in SetupResources)
        noOverlap(setupResources[stpRes]);
    
    // precedence requirement for different steps on a product
    forall(<d1,st1> in DemSteps, <d2,st2> in DemSteps, p in Precedences
                :st1.stepId == p.predecessorId && st2.stepId == p.successorId && d1 == d2) {
        endBeforeStart(prodSteps[<d1,st1>], prodSteps[<d2,st2>], p.delayMin);
        startBeforeEnd(prodSteps[<d2,st2>], prodSteps[<d1,st1>], -p.delayMax);

        endAtStart(prodSteps[<d1,st1>], prodSteps[<d2,st2>], lengthOf(storageAfterProdStep[<d1, st1>]));

        //presenceOf(demand[dem]) == presenceOf(storageAfterProdStep[<dem,st>]);
        presenceOf(storageAfterProdStep[<d1,st1>]) == (lengthOf(storageAfterProdStep[<d1,st1>]) > 0);  
    }
    
    // the steps on a product of a demand should be spanned in the demand interval
    forall(dem in Demands)
        span(demand[dem], all(st in Steps : dem.productId == st.productId) prodSteps[<dem,st>]);
    
    // tank intervals with different products and same tank should not overlap
    forall(stT in StorageTanks, <<dem,st>,storProd> in StorageAfterProdStepAlternative 
        : storProd.storageTankId == stT.storageTankId) {
            alwaysEqual(tankState[stT], storageAfterProdStepAlternatives[<<dem,st>,storProd>], dem.productId);
    }
	//storages after the first steps should start after a certain setup time if such is needed.
	// presenceof => is much better on all instances except 3.
	forall(<dem,st> in DemSteps, storProd in StorageProductions, stT in StorageTanks
    	: st.stepId in startingStepsIDs && st.stepId == storProd.prodStepId 
          && stT.storageTankId == storProd.storageTankId) 
            presenceOf(storageAfterProdStep[<dem,st>]) => 
          	  startOf(storageAfterProdStep[<dem,st>]) 
          		   >= tankSetupTime[stT][dem.productId][stT.initialProductId];
	
    // tank should not overfill
    forall(stT in StorageTanks) {
        CumulConstraint:
            tankCapOverTime[stT] <= stT.quantityMax;
    }
};     
 

tuple DemandAssignment {
    key string demandId;
    int startTime;
    int endTime;
    float nonDeliveryCost;
    float tardinessCost;
};

{DemandAssignment} demandAssignments = //{};
{
    <
        dem.demandId,
        startOf(demand[dem]),
        endOf(demand[dem]),
        (1 - presenceOf(demand[dem])) * (dem.quantity * dem.nonDeliveryVariableCost),
        endEval(demand[dem], tardinessFees[dem])
    > | dem in Demands
};

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
{StepAssignment} stepAssignments =
{
    <
        dem.demandId, 
        step.stepId, 
        startOf(prodSteps[<dem, step>]), 
        endOf(prodSteps[<dem, step>]), 
        alternativeResource.resourceId,

        presenceOf(demandStepAlternative[<<dem, step>, alternativeResource>]) * 
            (alternativeResource.fixedProcessingCost + (alternativeResource.variableProcessingCost * dem.quantity)),

        costSetupDemandeStepAlternative[<<dem, step>, alternativeResource>],

        startOf(setupDemandStepAlternative[<<dem, step>, alternativeResource>]), 
        endOf(setupDemandStepAlternative[<<dem, step>, alternativeResource>]),
        step.setupResourceId
    > | <dem, step> in DemSteps,
        <<dem, step>, alternativeResource> in DemandStepAlternative,
        resource in Resources :
            presenceOf(demandStepAlternative[<<dem, step>, alternativeResource>]) && 
            step.stepId == alternativeResource.stepId &&
            alternativeResource.resourceId == resource.resourceId
};

tuple StorageAssignment {
   key string demandId;
   key string prodStepId;
   int startTime;
   int endTime;
   int quantity;
   string storageTankId;
};
{StorageAssignment} storageAssignments = 
{
    <
        dem.demandId,
        st.stepId,
        startOf(storageAfterProdStepAlternatives[<<dem,st>, storProd>]),
        endOf(storageAfterProdStepAlternatives[<<dem,st>, storProd>]),
        dem.quantity,
        storProd.storageTankId
    > | <dem,st> in DemSteps, storProd in StorageProductions 
        : st.stepId == storProd.prodStepId && st.stepId in stepsWithSuccessorIDs
          && presenceOf(storageAfterProdStepAlternatives[<<dem,st>, storProd>])
          && presenceOf(demand[dem])
};

execute {
 writeln("Total Non-Delivery Cost : ", TotalNonDeliveryCost);
 writeln("Total Processing Cost : ", TotalProcessingCost);
 writeln("Total Setup Cost : ", TotalSetupCost);
 writeln("Total Tardiness Cost : ", TotalTardinessCost);
 writeln();
 writeln("Weighted Non-Delivery Cost : ",WeightedNonDeliveryCost);
 writeln("Weighted Processing Cost : ", WeightedProcessingCost);
 writeln("Weighted Setup Cost : ", WeightedSetupCost);
 writeln("Weighted Tardiness Cost : ", WeightedTardinessCost);
 writeln();
 writeln("Total Weighted Cost :", TotalCost);
 writeln(); // ? shown in example output, absent from example code
 
 for(var d in demandAssignments) 
 {
     writeln(d.demandId, ": [",  d.startTime, ",", d.endTime, "] ");
     writeln(" non-delivery cost: ", d.nonDeliveryCost,  ", tardiness cost: " , d.tardinessCost);
 }
 writeln();
 for(var sa in stepAssignments) {
     writeln(sa.stepId, " of ", sa.demandId,": [", sa.startTime, ",", sa.endTime, "] ","on ", sa.resourceId);
     write(" processing cost: ", sa.procCost);
     if (sa.setupCost > 0)
         write(", setup cost: ", sa.setupCost);
     writeln();
     if (sa.startTimeSetup < sa.endTimeSetup)
         writeln(" setup step: [",sa.startTimeSetup, ",", sa.endTimeSetup, "] ","on ", sa.setupResourceId);
 }
 writeln();
 for(var sta in storageAssignments) {
     if (sta.startTime < sta.endTime) {
         writeln(sta.prodStepId, " of ", sta.demandId," produces quantity ", sta.quantity," in storage tank ", sta.storageTankId," at time ", sta.startTime," which is consumed at time ", sta.endTime);
     }
 }
 writeln();
}