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
    key string prevStepId;
    key string storageTankId;
    string nextStepId;
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


dvar interval demandInterval[demand in Demands]
    optional
    in 0..demand.deliveryMax;

tuple ProductionStepForDemand {
    Demand demand;
    Step step;
}

{ProductionStepForDemand} ProductionStepForDemandSet =
    {
        <demand, step> |
        demand in Demands, 
        step in Steps :
            demand.productId == step.productId
    };

dvar interval productionStepInterval[<demand, step> in ProductionStepForDemandSet] // size is taken from alternatives.
    optional;

tuple AlternativeResourceForProductionStep {
    Demand demand;
    Step step;
    Alternative alternativeResource;
}

{AlternativeResourceForProductionStep} AlternativeResourceForProductionStepSet = 
    {
        <demand, step, alternativeResource> | 
        <demand, step> in ProductionStepForDemandSet,
        alternativeResource in Alternatives:
            step.stepId == alternativeResource.stepId
    };
    
dvar interval alternativeResourceForProductionStepInterval[<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet]
    optional(1)
    in 0..demand.deliveryMax
    size ftoi(ceil(alternativeResource.fixedProcessingTime + alternativeResource.variableProcessingTime * demand.quantity));

dvar sequence resourceScheduleIntervalSequence[resource in Resources] in
    all (<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet:
            resource.resourceId == alternativeResource.resourceId
        ) alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]
    types all(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet:
            resource.resourceId == alternativeResource.resourceId
        ) demand.productId; 

{int} ProductIds = union(p in Products) {p.productId};

tuple TransitionMatrixItem {
    key int prod1; 
    key int prod2; 
    int value;
}; 

{TransitionMatrixItem} resourceSetupTimeTransitionMatrix[resource in Resources] =
    {<p1, p2, time> | <resource.setupMatrixId, p1, p2, time, cost> in Setups};

int resourceSetupCost[r in Resources][p1 in ProductIds union {-1}][p2 in ProductIds] =
    sum(<r.setupMatrixId, p1, p2, time, cost> in Setups) cost;
    
int resourceSetupTime[r in Resources][prevProductId in ProductIds union {-1}][nextProductId in ProductIds] =
    sum(<r.setupMatrixId, prevProductId, nextProductId, time, cost> in Setups) time;
      
//                 Setups
dvar interval productionStepSetupInterval[<demand, step> in ProductionStepForDemandSet]
    optional(1);
//  size 0..9999;
//  size 0..maxl(max(res in Resources, <p1,p2> in productSetsInMatrix[res.setupMatrixId]
//              : res.resourceId == alt.resourceId && res.setupMatrixId != "NULL") 
//              item(Setups, <res.setupMatrixId, p1,p2>).setupTime, 0); //maybe calculate it better?

dvar sequence setupResourceScheduleIntervalSequence[setupResource in SetupResources] in
    all(<demand, step> in ProductionStepForDemandSet :
            setupResource.setupResourceId == step.setupResourceId
       )
            productionStepSetupInterval[<demand, step>];

dvar int setupCostOfAlternativeResourceForProductionStep[<dem, st, alt> in AlternativeResourceForProductionStepSet]; 

//                   Storage tanks
 
//todo this calculation can be better. The sum of all minimum alternative of lenghths of intervals of steps. ???
int maxDemandStoreTime[dem in Demands] = dem.deliveryMax;
      //- sum(st in Steps) min(alt in Alternatives) where st.productId == dem.productId && alt.stepId == st.stepId;

    
// TODO replace with storage for each precedence
// A storage step happens between 2 consecutive production steps and is therefore
// characterized by them
tuple StorageStepForDemand {
    Demand demand;
    Step prevStep;
    Step nextStep;
    Precedence precedence;
}

{StorageStepForDemand} StorageStepForDemandSet = 
    {
        <demand, prevStep, nextStep, precedence> | 

        <demand, prevStep> in ProductionStepForDemandSet,
        <demand, nextStep> in ProductionStepForDemandSet,
        precedence in Precedences :
            prevStep.stepId == precedence.predecessorId &&
            nextStep.stepId == precedence.successorId
    };

dvar interval storageStepInterval[<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet] // size is taken from alternatives.
    optional
    in 0..demand.deliveryMax
    size precedence.delayMin
         ..
         precedence.delayMax;

tuple AlternativeTankForStorageStep {
    Demand demand;
    Step prevStep;
    Step nextStep;
    Precedence precedence;
    StorageProduction alternativeTank;
}

{AlternativeTankForStorageStep} AlternativeTankForStorageStepSet = 
    {
        <demand, prevStep, nextStep, precedence, alternativeTank> | 

        <demand, prevStep, nextStep, precedence> in StorageStepForDemandSet,
        alternativeTank in StorageProductions : // StorageProductions ~= AlternativeTanks
            alternativeTank.prevStepId == prevStep.stepId &&
            alternativeTank.nextStepId == nextStep.stepId
    };

dvar interval alternativeTankForStorageStepInterval[<demand, prevStep, nextStep, precedence, alternativeTank> in AlternativeTankForStorageStepSet]
    optional
    in 0..demand.deliveryMax
    size precedence.delayMin
         ..
         precedence.delayMax;
     
{TransitionMatrixItem} tankSetupTimeTransitionMatrix[tank in StorageTanks] =
    {<p1, p2, time> | <tank.setupMatrixId, p1, p2, time, cost> in Setups};
    
stateFunction tankState[tank in StorageTanks] with tankSetupTimeTransitionMatrix[tank];

// ???? is this correct??
cumulFunction tankStoredAmountOverTime[tank in StorageTanks] =
        sum(<demand, prevStep, nextStep, precedence, alternativeTank> in AlternativeTankForStorageStepSet :  // all storage tanks available for a storage step
                alternativeTank.storageTankId == tank.storageTankId
           //) pulse(storageStepInterval[<demand, prevStep, nextStep, precedence>], demand.quantity);
           ) pulse(alternativeTankForStorageStepInterval[<demand, prevStep, nextStep, precedence, alternativeTank>], demand.quantity);

//                       COSTS

pwlFunction tardinessFees[demand in Demands] = 
                piecewise{0->demand.due_time; demand.tardinessVariableCost}(demand.due_time, 0);
dexpr float TardinessCost = sum(demand in Demands) endEval(demandInterval[demand], tardinessFees[demand]);

dexpr float NonDeliveryCost = sum(demand in Demands)
                (1 - presenceOf(demandInterval[demand])) * (demand.quantity * demand.nonDeliveryVariableCost);

dexpr float ProcessingCost = sum(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet) 
                presenceOf(alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]) *
                (alternativeResource.fixedProcessingCost + demand.quantity * alternativeResource.variableProcessingCost);

//dexpr float SetupCost = 0; 
dexpr float SetupCost = sum(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet)
                            setupCostOfAlternativeResourceForProductionStep[<demand, step, alternativeResource>];
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
    

  var f = cp.factory;
  cp.setSearchPhases(f.searchPhase(resourceScheduleIntervalSequence));
}
minimize 
  TotalCost;
subject to {
    // TODO Alternative resources for production steps
    forall(<demand, step> in ProductionStepForDemandSet)
        alternative(productionStepInterval[<demand, step>], 
            all(alternativeResource in Alternatives: alternativeResource.stepId == step.stepId)
                alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]);

    // TODO Alternative storages between production steps
    forall(<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet)
        alternative(storageStepInterval[<demand, prevStep, nextStep, precedence>], 
            all(alternativeTank in StorageProductions :
                    alternativeTank.prevStepId == prevStep.stepId &&
                    alternativeTank.nextStepId == nextStep.stepId
               ) alternativeTankForStorageStepInterval[<demand, prevStep, nextStep, precedence, alternativeTank>]);

    // TODO Alternative setup intervals ???? what does that even mean?

    // TODO Each demand interval must span all production steps on the demand.
    forall(demand in Demands)
        span(demandInterval[demand], 
            all(<demand, step> in ProductionStepForDemandSet)
                productionStepInterval[<demand, step>]);

    // If a demand is produced, then all production step intervals for that demand must be present.
    forall(<demand, step> in ProductionStepForDemandSet)
        presenceOf(demandInterval[demand]) == presenceOf(productionStepInterval[<demand, step>]);

    // ???? Is this necessary? Does it improve performance? Test it!
    forall(demand in Demands)
        span(demandInterval[demand],
            all(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet)  
                alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]);
    
    // TODO precedences between production steps on a demand.
    // TODO endBeforeStart and startBeforeEnd for minimum and -maximum delay of storage.
    forall(<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet)
    {
        // Enforce precedences and min/max delay between them.
        endBeforeStart(productionStepInterval[<demand, prevStep>], productionStepInterval[<demand, nextStep>], precedence.delayMin);
        startBeforeEnd(productionStepInterval[<demand, nextStep>], productionStepInterval[<demand, prevStep>], -precedence.delayMax);

        // The intervals for all production steps for a demand must have the same presence value.
        presenceOf(productionStepInterval[<demand, prevStep>]) == presenceOf(productionStepInterval[<demand, nextStep>]);

        // TODO add storages between each 2 successive production steps
        // TODO Each storage step needs to fit exactly between the two production steps around it.
        endAtStart
        (
            productionStepInterval[<demand, prevStep>],
            productionStepInterval[<demand, nextStep>], 
            lengthOf(storageStepInterval[<demand, prevStep, nextStep, precedence>])
        );

        startAtEnd
        (
            storageStepInterval[<demand, prevStep, nextStep, precedence>],
            productionStepInterval[<demand, prevStep>]
        );

        endAtStart
        (
            storageStepInterval[<demand, prevStep, nextStep, precedence>],
            productionStepInterval[<demand, nextStep>]
        );
    }


    // TODO No overlap on all intervals for a resource.
    forall(resource in Resources) {
        noOverlap(resourceScheduleIntervalSequence[resource], resourceSetupTimeTransitionMatrix[resource], 1);
    }

    // TODO No overlap on all intervals for a setup resource.
    // setups using the same setup resource must not overlap
    forall(setupResource in SetupResources) {
        noOverlap(setupResourceScheduleIntervalSequence[setupResource]);
    }

    // ???? Should we have another constraint for all precedences of alternative resources?
   

    

    // TODO Specify the size of the setup of each productionScheduleInterval.

    // TODO Specify the cost of the setup of each productionScheduleInterval.

    // setting the setup time and cost of setups before each step. 
    forall
    (
        arfps in AlternativeResourceForProductionStepSet,
        resource in Resources : resource.resourceId == arfps.alternativeResource.resourceId
    ) {
        
        presenceOf(alternativeResourceForProductionStepInterval[arfps]) 
        == 
        presenceOf(productionStepSetupInterval[<arfps.demand, arfps.step>]);
        
        setupLenConstraint: 
        lengthOf(productionStepSetupInterval[<arfps.demand, arfps.step>])// == 0;
        ==
        resourceSetupTime[resource]
        [
            typeOfPrev
            (
                resourceScheduleIntervalSequence[resource],
                alternativeResourceForProductionStepInterval[arfps],
                resource.initialProductId,
                -1
            )
        ][arfps.demand.productId];
        setupCostConstraint:
        setupCostOfAlternativeResourceForProductionStep[arfps]//== 0;
        ==
        resourceSetupCost[resource]
        [
            typeOfPrev
            (
                resourceScheduleIntervalSequence[resource], 
                alternativeResourceForProductionStepInterval[arfps], 
                resource.initialProductId, 
                -1
            )
        ][arfps.demand.productId];
    }

    // TODO the setup of each productionScheduleInterval needs to happen before it and also must happen after the previous interval that uses the same resource (found in the resource sequence)

    // TODO A demand should be delivered after its minimum delivery time.

    // TODO Step and Cumul functions for each storage.


    // tank intervals with different products and same tank should not overlap
    forall(atfss in AlternativeTankForStorageStepSet,
            tank in StorageTanks : tank.storageTankId == atfss.alternativeTank.storageTankId)
            alwaysEqual(tankState[tank], alternativeTankForStorageStepInterval[atfss], atfss.demand.productId);

    forall(tank in StorageTanks)
        tankStoredAmountOverTime[tank] <= tank.quantityMax;
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
        demand.demandId, 
        step.stepId, 
        startOf(productionStepInterval[<demand, step>]), 
        endOf(productionStepInterval[<demand, step>]), 
        alternativeResource.resourceId,
        presenceOf(alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]) * 
            (alternativeResource.fixedProcessingCost + (alternativeResource.variableProcessingCost * demand.quantity)),
        
        resourceSetupCost
            [resource]
            [
                typeOfPrev(resourceScheduleIntervalSequence[resource],
                     alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>],
                     resource.initialProductId,
                     -1)
            ]
            [demand.productId],

        startOf(productionStepSetupInterval[<demand, step>]),             
        endOf(productionStepSetupInterval[<demand, step>]),
        step.setupResourceId
    > | <demand, step> in ProductionStepForDemandSet,
        <demand, step, alternativeResource> in AlternativeResourceForProductionStepSet,
        resource in Resources :
            presenceOf(alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]) && 
            step.stepId == alternativeResource.stepId &&
            alternativeResource.resourceId == resource.resourceId
};

tuple StorageAssignment {
    key string demandId;
    key string fromStepId;
    int startTime;
    int endTime;
    int quantity;
    string storageTankId;
};

//{StorageAssignment} storageAssignments = fill in from your decision variables.


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
