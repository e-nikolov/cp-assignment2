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
    int productId;
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
    key string fromStepId;
    key string storageTankId;
    string toStepId;
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





tuple ProductionStepForDemand {
    Demand demand;
    Step step;
}
{ProductionStepForDemand} ProductionStepForDemandsSet = {<dem, st> | dem in Demands, st in Steps : dem.productId == st.productId};

dvar interval productionStepIntervals[<dem, st> in ProductionStepForDemandsSet] // size is taken from alternatives.
    optional;

dvar interval demandIntervals[demand in Demands]
    optional
    in 0..demand.deliveryMax;

{int} ProductIds = union(p in Products) {p.productId};

tuple TransitionMatrixItem {
    key int prod1; 
    key int prod2; 
    int value;
}; 

int maxResTime = max(s in Setups) s.setupTime;
{TransitionMatrixItem} setupTimesResources[res in Resources] =
    {<p1, p2, t> | p1, p2 in ProductIds, stp in Setups, t in 0..maxResTime
        : stp.fromState == p1 && stp.toState == p2 
            && stp.setupMatrixId == res.setupMatrixId && t == stp.setupTime};

//{TransitionMatrixItem} setupCostsResources[res in Resources] =
//  {<p1,p2,c> | p1,p2 in ProductIds, stp in Setups, c in 0..maxint
//      : stp.fromState == p1 && stp.toState == p2 
//          && stp.setupMatrixId == res.setupMatrixId && c == stp.setupCost};


//range resRange = 0..card(Resources)-1;
//range prodRange = 0..card(ProductIds)-1;
//int stpTimes[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];
//int stpCosts[resRange][prodRange][prodRange] = [ r : [ p1 : [ p2: 0]] | r in resRange, p1,p2 in prodRange ];

int resourceSetupCost[r in Resources][p1 in ProductIds union {-1}][p2 in ProductIds] =
    sum(<r.setupMatrixId, p1, p2, time, cost> in Setups) cost;
    
int resourceSetupTime[r in Resources][p1 in ProductIds union {-1}][p2 in ProductIds] =
    sum(<r.setupMatrixId, p1, p2, time, cost> in Setups) time;
      
//tuple AlternativeResourceForProductionStepForDemandOnDemand {
tuple ProductionScheduleItem {
 //how about StepsForDemand + AlternativeResourcesForStep
//tuple StepOnAlternativeResourceForDemand {
    Demand demand;
    Step step;
    Alternative alternativeResource;
}
{ProductionScheduleItem} ProductionScheduleSet = 
//{StepOnAlternativeResourceForDemand} StepsOnAlternativeResourcesForDemands = 
    {<demand, step, alternativeResource> | <demand, step> in ProductionStepForDemandsSet, alternativeResource in Alternatives
        : step.stepId == alternativeResource.stepId};
    
dvar interval productionScheduleIntervals[<demand, step, alternativeResource> in ProductionScheduleSet]
//dvar interval stepOnAlternativeResourceForDemandIntervals[<demand, step, alternativeResource> in StepsOnAlternativeResourcesForDemands]
    optional(1)
    in 0..demand.deliveryMax
    size ftoi(ceil(alternativeResource.fixedProcessingTime + alternativeResource.variableProcessingTime * demand.quantity));

//dvar sequence resources[resource in Resources] in
//    all (demand in Demands, step in Steps, alternativeResource in Alternatives
//        : resource.resourceId == alternativeResource.resourceId && step.stepId == alternativeResource.stepId 
//          && demand.productId == item(Steps, <alternativeResource.stepId>).productId)
//            stepOnAlternativeResourceForDemandIntervals[<demand, step, alternativeResource>]
//    types all(demand in Demands, step in Steps, alternativeResource in Alternatives
//        : resource.resourceId == alternativeResource.resourceId && step.stepId == alternativeResource.stepId 
//          && demand.productId == item(Steps, <alternativeResource.stepId>).productId) demand.productId; 

dvar sequence resources[resource in Resources] in
    all (<demand, step, alternativeResource> in ProductionScheduleSet:
            resource.resourceId == alternativeResource.resourceId
        ) productionScheduleIntervals[<demand, step, alternativeResource>]
    types all(<demand, step, alternativeResource> in ProductionScheduleSet:
            resource.resourceId == alternativeResource.resourceId
        ) demand.productId; 

//                 Setups
{string} setupMatrixIDsNoNull = union(s in Setups) {s.setupMatrixId};
{string} setupMatrixIDs = setupMatrixIDsNoNull union {"NULL"};
tuple ProductSetsInMatrix {
    int p1;
    int p2;
}
{ProductSetsInMatrix} productSetsInMatrix[sid in setupMatrixIDs] 
                        = {<setup.fromState, setup.toState> | setup in Setups: setup.setupMatrixId == sid};

dvar interval productionSheduleSetupIntervals[<dem, st, alt> in ProductionScheduleSet]
    optional(1);
//  size 0..9999;
//  size 0..maxl(max(res in Resources, <p1,p2> in productSetsInMatrix[res.setupMatrixId]
//              : res.resourceId == alt.resourceId && res.setupMatrixId != "NULL") 
//              item(Setups, <res.setupMatrixId, p1,p2>).setupTime, 0); //maybe calculate it better?

// dvar sequence setupResources[setRes in SetupResources] in
//     all (dem in Demands, st in Steps, alt in Alternatives
//         : setRes.setupResourceId == st.setupResourceId && st.stepId == alt.stepId 
//           && dem.productId == item(Steps, <alt.stepId>).productId)
//             productionSheduleSetupIntervals[<dem, st, alt>];
dvar sequence setupResources[setRes in SetupResources] in
    all(<dem, st, alt> in ProductionScheduleSet
            : setRes.setupResourceId == st.setupResourceId)
                productionSheduleSetupIntervals[<dem, st, alt>];

dvar int productionScheduleSetupCost[<dem, st, alt> in ProductionScheduleSet]; 

//                   Storage tanks

// get the stepID's of steps that are last. The storage after these steps will be 0 0 0.
{string} stepIDs = union(st in Steps) {st.stepId};
//{string} stepsWithPredecessorIDs = union(pr in Precedences) {pr.successorId};
{string} stepsWithSuccessorIDs = union(pr in Precedences) {pr.predecessorId};
{string} endingStepsIDs = stepIDs diff stepsWithSuccessorIDs;
 
//todo this calculation can be better. The sum of all minimum alternative of lenghths of intervals of steps. ???
int maxDemandStoreTime[dem in Demands] = dem.deliveryMax;
//      - sum(st in Steps) min(alt in Alternatives) where st.productId == dem.productId && alt.stepId == st.stepId;

tuple StorageTimeBound {
    key string stepId;
    int minTime;
    int maxTime;
}

{StorageTimeBound} StorageTimeBounds[st in stepIDs]
                        = {<st, pr.delayMin, pr.delayMax> | pr in Precedences : pr.predecessorId == st}
                          union 
                          {<st2, 0, 0> | st2 in endingStepsIDs : st2 == st};

dvar interval storageAfterProdStep[<dem, st> in ProductionStepForDemandsSet]
    optional
    in 0..dem.deliveryMax
    size item(StorageTimeBounds[st.stepId], <st.stepId>).minTime 
         .. 
         minl(item(StorageTimeBounds[st.stepId], <st.stepId>).maxTime, maxDemandStoreTime[dem]);
    
tuple StorageAfterProdStepAlternatives {
    Demand demand;
    Step step;
    StorageProduction storProd;
}   
{StorageAfterProdStepAlternatives} StorageAfterProdStepAlternative = 
     {<dem, st, storProd> | <dem, st> in ProductionStepForDemandsSet, storProd in StorageProductions
     : st.stepId == storProd.fromStepId};
     
dvar interval storageAfterProdStepAlternatives[<demand, step, storProd> in StorageAfterProdStepAlternative]
    optional
    in 0..demand.deliveryMax
    size item(StorageTimeBounds[step.stepId], <step.stepId>).minTime 
         .. 
         item(StorageTimeBounds[step.stepId], <step.stepId>).maxTime;
         //minl(item(StorageTimeBounds[step.stepId], <step.stepId>).maxTime, maxDemandStoreTime[demand]);    

{TransitionMatrixItem} setupTimesStorage[t in StorageTanks] =
    {<p1, p2, time> | <t.setupMatrixId, p1, p2, time, cost> in Setups};
//  {<stp.fromState, stp.toState, stp.setupTime> 
//      | stp in Setups : stp.setupMatrixId == t.setupMatrixId};

//{TransitionMatrixItem} setupCostsStorage[t in StorageTanks] =
//  {<p1, p2, cost> | <t.setupMatrixId, p1, p2, time, cost> in Setups};
//  {<stp.fromState, stp.toState, stp.setupCost> 
//      | stp in Setups : stp.setupMatrixId == t.setupMatrixId};


//range tankRange = 0..card(StorageTanks)-1;
//int storageSetupCosts[tankRange][prodRange][prodRange] = [ t : [ p1 : [ p2: 0]] | t in tankRange, p1,p2 in prodRange];

//dvar int costStorageAfterProdStepAlternatives[<dem, st, storProd> in StorageAfterProdStepAlternative]; 
    
statefunction tankState[tank in StorageTanks] with setupTimesStorage[tank];

//dvar sequence storageTankSeq[t in StorageTanks]
//      in all(<dem, st, storProd> in StorageAfterProdStepAlternative
//                  : storProd.storageTankId == t.storageTankId)
//          storageAfterProdStepAlternatives[<dem, st, storProd>]
//      types all(<dem, st, storProd> in StorageAfterProdStepAlternative
//                  : storProd.storageTankId == t.storageTankId)
//          dem.productId;

cumulFunction tankCapOverTime[storageTank in StorageTanks] =
        sum(<demand, step> in ProductionStepForDemandsSet, storageProduction in StorageProductions  // all storage tanks after a production step
            : storageProduction.storageTankId == storageTank.storageTankId && storageProduction.fromStepId == step.stepId)
                pulse(storageAfterProdStep[<demand, step>], demand.quantity);

//                       COSTS

pwlFunction tardinessFees[demand in Demands] = 
                piecewise{0->demand.due_time; demand.tardinessVariableCost}(demand.due_time, 0);
dexpr float TardinessCost = sum(demand in Demands) endEval(demandIntervals[demand], tardinessFees[demand]);

dexpr float NonDeliveryCost = sum(demand in Demands)
                (1 - presenceOf(demandIntervals[demand])) * (demand.quantity * demand.nonDeliveryVariableCost);

dexpr float ProcessingCost = sum(<demand, step, alternativeResource> in ProductionScheduleSet) 
                presenceOf(productionScheduleIntervals[<demand, step, alternativeResource>]) *
                (alternativeResource.fixedProcessingCost + demand.quantity * alternativeResource.variableProcessingCost);

//dexpr float SetupCost = 0; 
dexpr float SetupCost = sum(<demand, step, alternativeResource> in ProductionScheduleSet)
                            productionScheduleSetupCost[<demand, step, alternativeResource>];
//                      + sum(<dem, st, storProd> in StorageAfterProdStepAlternative)
//                          costStorageAfterProdStepAlternatives[<dem, st, storProd>]; 

dexpr float WeightedTardinessCost = 
        TardinessCost * item(CriterionWeights, <"TardinessCost">).weight;
dexpr float WeightedNonDeliveryCost = 
        NonDeliveryCost * item(CriterionWeights, <"NonDeliveryCost">).weight;
dexpr float WeightedProcessingCost =
        ProcessingCost * item(CriterionWeights, <"ProcessingCost">).weight;
dexpr float WeightedSetupCost = 
        SetupCost * item(CriterionWeights, <"SetupCost">).weight;

dexpr float TotalCost = WeightedTardinessCost + WeightedNonDeliveryCost + WeightedProcessingCost + WeightedSetupCost;

//todo assert that the everything in StorageProduction is according to Precedence, that there is nothing funny going on.

execute {
    cp.param.Workers = 1;
//  cp.param.TimeLimit = Opl.card(Demands)*10;
    cp.param.TimeLimit = Opl.card(Demands);
    
//  for(var res in Resources)
//      for(var t in setupTimesResources[res])
//          stpTimes[Opl.ord(Resources, res)][t.prod1][t.prod2] = t.value;
//          
//  for(var res in Resources)
//      for(var c in setupCostsResources[res])
//          stpCosts[Opl.ord(Resources, res)][c.prod1][c.prod2] = c.value;
    
//  for(var tank in StorageTanks)
//      for(var c in setupCostsStorage[tank])
//          storageSetupCosts[Opl.ord(StorageTanks, tank)][c.prod1][c.prod2] = c.value;

}
minimize 
  TotalCost;
subject to {
    // Making sure the unimportnat intervals are not cousing any useless test cases
    // every setup for a step who's resource has no setup goes to 0. the cost too.
//    forall(<dem, st, alt> in ProductionScheduleSet, res in Resources 
//            : res.setupMatrixId == "NULL" && res.resourceId == alt.resourceId) {               
//        !presenceOf(productionSheduleSetupIntervals[<dem, st, alt>]);
//      lengthOf(setupProductionStepForDemandAlternative[<dem, st, alt>]) == 0;
//        productionScheduleSetupCost[<dem, st, alt>] == 0; 
//    }
    
    //end of the last steps must be after the mindeliverytime.
    forall(<dem, st> in ProductionStepForDemandsSet : st.stepId in endingStepsIDs)
        endOf(productionStepIntervals[<dem, st>], dem.deliveryMin) >= dem.deliveryMin;
    
//    forall(<dem, st> in ProductionStepForDemandsSet : st.stepId in endingStepsIDs) {
//        !presenceOf(storageAfterProdStep[<dem, st>]);
//        lengthOf(storageAfterProdStep[<dem, st>]) == 0;
//    }       
//    forall(<dem, st, storProd> in StorageAfterProdStepAlternative : st.stepId in endingStepsIDs){
//        !presenceOf(storageAfterProdStepAlternatives[<dem, st, storProd>]);
//        lengthOf(storageAfterProdStepAlternatives[<dem, st, storProd>]) == 0;
//    }
    
    // All setup intervals are just before the interval they precede
    forall(<dem, st, alt> in ProductionScheduleSet)
        endAtStart(productionScheduleIntervals[<dem, st, alt>], productionScheduleIntervals[<dem, st, alt>]);
    
    //fix the position of all storage intervals (their end times and start times)
    forall(<dem, st, storProd> in StorageAfterProdStepAlternative : st.stepId in stepsWithSuccessorIDs){
        endAtStart(storageAfterProdStepAlternatives[<dem, st, storProd>], productionStepIntervals[<dem, item(Steps, <storProd.toStepId>)>]);
        startAtEnd(storageAfterProdStepAlternatives[<dem, st, storProd>], productionStepIntervals[<dem, st>]);
     }
    
    // storages need to chose which tank to use. chose just one alternative each
    forall(<dem, st> in ProductionStepForDemandsSet : st.stepId in stepsWithSuccessorIDs)
        alternative(storageAfterProdStep[<dem, st>],
            all(storProd in StorageProductions : st.stepId == storProd.fromStepId) 
                storageAfterProdStepAlternatives[<dem, st, storProd>]);
    
    // If a demand is present, all the steps it requires must be present too (and vice versa)
    forall(<dem, st> in ProductionStepForDemandsSet)
        presenceOf(demandIntervals[dem]) == presenceOf(productionStepIntervals[<dem, st>]);
    
    // storage intervals are present/absent the same as their demand
    forall(<dem, st> in ProductionStepForDemandsSet : st.stepId in stepsWithSuccessorIDs)
        presenceOf(demandIntervals[dem]) == presenceOf(storageAfterProdStep[<dem, st>]);
        
//       if a demand is not present then all the setup intervals should not be present too.
//    forall(<dem, st, alt> in ProductionScheduleSet)
//        !presenceOf(demandIntervals[dem]) => !presenceOf(productionScheduleIntervals[<dem, st, alt>]);

    // Every step must be one and only one of it's alternatives 
    forall(<dem, st> in ProductionStepForDemandsSet)
        alternative(productionStepIntervals[<dem, st>], 
            all(alt in Alternatives: alt.stepId == st.stepId) productionScheduleIntervals[<dem, st, alt>]);
    
    // steps using the same resource must not overlap
    forall(res in Resources)
        noOverlap(resources[res], setupTimesResources[res], 1);
    
    // tank intervals with different products and same tank should not overlap
    forall(stT in StorageTanks, <dem, st, storProd> in StorageAfterProdStepAlternative:
           storProd.storageTankId == stT.storageTankId)
        alwaysEqual(tankState[stT], storageAfterProdStepAlternatives[<dem, st, storProd>], dem.productId);
        
    // setting the setup time and cost of setups before each step. 
    forall(<dem, st, alt> in ProductionScheduleSet, res in Resources:
            /*res.setupMatrixId != "NULL" && */res.resourceId == alt.resourceId) {

        
//        !presenceOf(productionScheduleIntervals[<dem, st, alt>]) 
//            => !presenceOf(productionScheduleIntervals[<dem, st, alt>]);
//todo fix, not just comment.        
         setupLenConstraint: lengthOf(productionScheduleIntervals[<dem, st, alt>]) >= 0;// == 0;
        //     == resourceSetupTime[res][typeOfPrev(resources[res], productionScheduleIntervals[<dem, st, alt>], res.initialProductId, -1)][dem.productId];
//          == stpTimes[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<dem, st, alt>], res.initialProductId)][dem.productId];
//todo fix, not just comment.
         setupCostConstraint: productionScheduleSetupCost[<dem, st, alt>] >= 0;//== 0;
        //     == resourceSetupCost[res][typeOfPrev(resources[res], productionScheduleIntervals[<dem, st, alt>], res.initialProductId, -1)][dem.productId];
//          == stpCosts[ord(Resources, res)][typeOfPrev(resources[res], demandStepAlternative[<dem, st, alt>], res.initialProductId)][dem.productId];
    }
        
    // setups using the same setup resource must not overlap
    forall(stpRes in SetupResources)
        noOverlap(setupResources[stpRes]);
    
    // precedence requirement for different steps on a product
    forall(<d1, st1> in ProductionStepForDemandsSet, <d2, st2> in ProductionStepForDemandsSet, p in Precedences:
        st1.stepId == p.predecessorId && st2.stepId == p.successorId && d1 == d2)
        endBeforeStart(productionStepIntervals[<d1, st1>], productionStepIntervals[<d2, st2>]);
    
    // the steps on a product of a demand should be spanned in the demand interval
    forall(dem in Demands)
        span(demandIntervals[dem], all(st in Steps : dem.productId == st.productId) productionStepIntervals[<dem, st>]);
    
    forall(stT in StorageTanks)
        tankCapOverTime[stT] <= stT.quantityMax;
 };     
 
//{DemandAssignment} demandAssignments = fill in from your decision variables.
//{DemandAssignment} demandAssignments =
//{
//  <d.demandId,
//  startOf(something),
//  endOf(something),
//  someExpression,
//  someOtherExpression>
//  | d in Demands
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
    key string fromStepId;
    int startTime;
    int endTime;
    int quantity;
    string storageTankId;
};

//{StorageAssignment} storageAssignments = fill in from your decision variables.
//{StepAssignment} stepAssignments =
//    {<d.demandId, 
//      st.stepId, 
//      startOf(productionStepIntervals[<d, st>]), 
//      endOf(productionStepIntervals[<d, st>]), 
//      a.resourceId,
//      presenceOf(productionStepOnAlternatives[<d, a>]) * (a.fixedProcCost + (a.variableProcCost * d.quantity)),
//      setupCostArray[r]
//                 [typeOfPrev(resources[r],
//                             productionStepsOnAlternatives[<d, a>],
//                             r.initialProductId,
//                             -1)]
//                 [d.productId],
//    startOf(setupSteps[<d, st>]),             
//    endOf(setupSteps[<d, st>]),
//    st.setupResourceId
//
//    >
//    | <d, st> in ProductionStepForDemandsSet, <d, a> in DemandAlternatives, r in Resources
//    : presenceOf(productionStepIntervalsOnAlternatives[<d, a>]) && 
//     st.stepId == a.stepId &&
//     a.resourceId == r.resourceId
//    };


execute {
//  writeln("Total Non-Delivery Cost : ", TotalNonDeliveryCost);
//  writeln("Total Processing Cost : ", TotalProcessingCost);
//  writeln("Total Setup Cost : ", TotalSetupCost);
//  writeln("Total Tardiness Cost : ", TotalTardinessCost);
//  writeln();
//  writeln("Weighted Non-Delivery Cost : ",WeightedNonDeliveryCost);
//  writeln("Weighted Processing Cost : ", WeightedProcessingCost);
//  writeln("Weighted Setup Cost : ", WeightedSetupCost);
//  writeln("Weighted Tardiness Cost : ", WeightedTardinessCost);
//  writeln();
//  
//  for(var d in demandAssignments) 
//  {
//      writeln(d.demandId, ": [",  d.startTime, ",", d.endTime, "] ");
//      writeln(" non-delivery cost: ", d.nonDeliveryCost,  ", tardiness cost: " , d.tardinessCost);
//  }
//  writeln();
//  for(var sa in stepAssignments) {
//      writeln(sa.stepId, " of ", sa.demandId,": [", sa.startTime, ",", sa.endTime, "] ","on ", sa.resourceId);
//      write(" processing cost: ", sa.procCost);
//      if (sa.setupCost > 0)
//          write(", setup cost: ", sa.setupCost);
//      writeln();
//      if (sa.startTimeSetup < sa.endTimeSetup)
//          writeln(" setup step: [",sa.startTimeSetup, ",", sa.endTimeSetup, "] ","on ", sa.setupResourceId);
//  }
//  writeln();
//  for(var sta in storageAssignments) {
//      if (sta.startTime < sta.endTime) {
//          writeln(sta.fromStepId, " of ", sta.demandId," produces quantity ", sta.quantity," in storage tank ", sta.storageTankId," at time ", sta.startTime," which is consumed at time ", sta.endTime);
//      }
//  }
}
