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
{ProductionStepForDemand} ProductionStepForDemandSet = {<dem, st> | dem in Demands, st in Steps : dem.productId == st.productId};

dvar interval productionStepInterval[<dem, st> in ProductionStepForDemandSet] // size is taken from alternatives.
    optional;

dvar interval demandInterval[demand in Demands]
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
tuple ProductionStepOnAlternativeResource {
 //how about StepsForDemand + AlternativeResourcesForStep
//tuple StepOnAlternativeResourceForDemand {
    Demand demand;
    Step step;
    Alternative alternativeResource;
}
{ProductionStepOnAlternativeResource} ProductionStepOnAlternativeResourceSet = 
//{StepOnAlternativeResourceForDemand} StepsOnAlternativeResourcesForDemands = 
    {<demand, step, alternativeResource> | <demand, step> in ProductionStepForDemandSet, alternativeResource in Alternatives
        : step.stepId == alternativeResource.stepId};
    
dvar interval productionStepOnAlternativeResourceInterval[<demand, step, alternativeResource> in ProductionStepOnAlternativeResourceSet]
//dvar interval stepOnAlternativeResourceForDemandIntervals[<demand, step, alternativeResource> in StepsOnAlternativeResourcesForDemands]
    optional(1)
    in 0..demand.deliveryMax
    size ftoi(ceil(alternativeResource.fixedProcessingTime + alternativeResource.variableProcessingTime * demand.quantity));

dvar sequence resourceScheduleIntervalSequence[resource in Resources] in
    all (<demand, step, alternativeResource> in ProductionStepOnAlternativeResourceSet:
            resource.resourceId == alternativeResource.resourceId
        ) productionStepOnAlternativeResourceInterval[<demand, step, alternativeResource>]
    types all(<demand, step, alternativeResource> in ProductionStepOnAlternativeResourceSet:
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

dvar interval productionSheduleSetupIntervals[<dem, st, alt> in ProductionStepOnAlternativeResourceSet]
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
    all(<dem, st, alt> in ProductionStepOnAlternativeResourceSet
            : setRes.setupResourceId == st.setupResourceId)
                productionSheduleSetupIntervals[<dem, st, alt>];

dvar int productionStepOnAlternativeResourceSetupCost[<dem, st, alt> in ProductionStepOnAlternativeResourceSet]; 

//                   Storage tanks

// get the stepID's of steps that are last. The storage after these steps will be 0 0 0.
{string} stepIDs = union(st in Steps) {st.stepId};
//{string} stepsWithPredecessorIDs = union(pr in Precedences) {pr.successorId};
{string} stepsWithSuccessorIDs = union(pr in Precedences) {pr.predecessorId};
{string} endingStepsIDs = stepIDs diff stepsWithSuccessorIDs;
 
//todo this calculation can be better. The sum of all minimum alternative of lenghths of intervals of steps. ???
int maxDemandStoreTime[dem in Demands] = dem.deliveryMax;
      //- sum(st in Steps) min(alt in Alternatives) where st.productId == dem.productId && alt.stepId == st.stepId;

tuple StorageTimeBound {
    key string stepId;
    int minTime;
    int maxTime;
}

{StorageTimeBound} StorageTimeBounds[step in stepIDs]
                        = {<step, precedence.delayMin, precedence.delayMax> | precedence in Precedences : precedence.predecessorId == step}
                          union 
                          {<step2, 0, 0> | step2 in endingStepsIDs : step2 == step};

dvar interval storageAfterProdStep[<dem, st> in ProductionStepForDemandSet]
    optional
    in 0..dem.deliveryMax
    size item(StorageTimeBounds[st.stepId], <st.stepId>).minTime 
         .. 
         item(StorageTimeBounds[st.stepId], <st.stepId>).maxTime;
    
tuple StorageAfterProdStepAlternatives {
    Demand demand;
    Step step;
    StorageProduction storProd;
}   
{StorageAfterProdStepAlternatives} StorageAfterProdStepAlternative = 
     {<dem, st, storProd> | <dem, st> in ProductionStepForDemandSet, storProd in StorageProductions
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
        sum(<demand, step> in ProductionStepForDemandSet, storageProduction in StorageProductions  // all storage tanks after a production step
            : storageProduction.storageTankId == storageTank.storageTankId && storageProduction.fromStepId == step.stepId)
                pulse(storageAfterProdStep[<demand, step>], demand.quantity);

//                       COSTS

pwlFunction tardinessFees[demand in Demands] = 
                piecewise{0->demand.due_time; demand.tardinessVariableCost}(demand.due_time, 0);
dexpr float TardinessCost = sum(demand in Demands) endEval(demandInterval[demand], tardinessFees[demand]);

dexpr float NonDeliveryCost = sum(demand in Demands)
                (1 - presenceOf(demandInterval[demand])) * (demand.quantity * demand.nonDeliveryVariableCost);

dexpr float ProcessingCost = sum(<demand, step, alternativeResource> in ProductionStepOnAlternativeResourceSet) 
                presenceOf(productionStepOnAlternativeResourceInterval[<demand, step, alternativeResource>]) *
                (alternativeResource.fixedProcessingCost + demand.quantity * alternativeResource.variableProcessingCost);

//dexpr float SetupCost = 0; 
dexpr float SetupCost = sum(<demand, step, alternativeResource> in ProductionStepOnAlternativeResourceSet)
                            productionStepOnAlternativeResourceSetupCost[<demand, step, alternativeResource>];
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
    // TODO Alternative resources for production steps
    forall(<demand, step> in ProductionStepForDemandSet)
        alternative(productionStepInterval[<demand, step>], 
            all(alternativeResource in Alternatives: alternativeResource.stepId == step.stepId)
                productionStepOnAlternativeResourceInterval[<demand, step, alternativeResource>]);

    // TODO Each demand interval must span all production steps on the demand.

    // TODO endBeforeStart and startBeforeEnd for minimum and -maximum delay of storage.

    // TODO Each storage step needs fit exactly between the two production steps around it.

    // TODO precedences between production steps on a demand.

    // TODO No overlap on all intervals for a resource.
    
    // TODO No overlap on all intervals for a setup resource.

    // TODO Specify the size of the setup of each productionScheduleInterval.

    // TODO Specify the cost of the setup of each productionScheduleInterval.

    // TODO the setup of each productionScheduleInterval needs to happen before it and also must happen after the previous interval that uses the same resource (found in the resource sequence)

    // TODO A demand should be delivered after its minimum delivery time.

    // TODO Step and Comul functions for each storage.





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
