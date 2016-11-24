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

{int} ProductIDSet = union(p in Products) {p.productId};

tuple Demand {
    key string demandId;
    int productId;
    int quantity;
    int deliveryMin;
    int deliveryMax;
    float nonDeliveryVariableCost;
    int dueTime;
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

int maxDelayDiff = max(p in Precedences) (p.delayMax - p.delayMin);

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


int NumberOfEquivalentDemands =
        sum
        (
            demand1, demand2 in Demands :
                demand1.productId                   == demand2.productId &&
                demand1.deliveryMin                 == demand2.deliveryMin &&
                demand1.deliveryMax                 == demand2.deliveryMax &&
                demand1.dueTime                     == demand2.dueTime &&
                demand1.nonDeliveryVariableCost     == demand2.nonDeliveryVariableCost &&
                demand1.quantity                    == demand2.quantity &&
                demand1.tardinessVariableCost       == demand2.tardinessVariableCost                
        ) (demand1.demandId < demand2.demandId);


dvar interval demandInterval[demand in Demands]
    optional
//    in 0..demand.deliveryMax
    ;

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
        alternativeResource in Alternatives :
            step.stepId == alternativeResource.stepId
    };

dvar interval alternativeResourceForProductionStepInterval[<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet]
    optional
    size ftoi(ceil(alternativeResource.fixedProcessingTime + alternativeResource.variableProcessingTime * demand.quantity));


dvar sequence resourceScheduleIntervalSequence[resource in Resources] in
    all (<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet:
            resource.resourceId == alternativeResource.resourceId
        ) alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]
    types all(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet:
            resource.resourceId == alternativeResource.resourceId
        ) demand.productId; 

tuple TransitionMatrixItem {
    key int prod1; 
    key int prod2; 
    int value;
}; 

{TransitionMatrixItem} resourceSetupTimeTransitionMatrix[resource in Resources] =
    {<prevProductId, nextProductId, time> | <resource.setupMatrixId, prevProductId, nextProductId, time, cost> in Setups};


int resourceSetupTime[r in Resources][prevProductId in ProductIDSet union {-1}][nextProductId in ProductIDSet] =
    sum(<r.setupMatrixId, prevProductId, nextProductId, time, cost> in Setups) time;

int resourceSetupCost[r in Resources][prevProductId in ProductIDSet union {-1}][nextProductId in ProductIDSet] =
    sum(<r.setupMatrixId, prevProductId, nextProductId, time, cost> in Setups) cost;      

//                 Setups
dvar interval alternativeResourceForProductionStepSetupInterval[<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet]
    optional;

dvar sequence setupResourceScheduleIntervalSequence[setupResource in SetupResources] in
    all(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet :
            setupResource.setupResourceId == step.setupResourceId
       ) alternativeResourceForProductionStepSetupInterval[<demand, step, alternativeResource>];

dvar int setupCostOfAlternativeResourceForProductionStep[<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet]; 

//                   Storage tanks

{string} ProductionStepIDSet = union(step in Steps) {step.stepId};
{string} StepWithPredecessorIDSet = union(precedence in Precedences) {precedence.successorId};
{string} StepWithSuccessorIDSet = union(precedence in Precedences) {precedence.predecessorId};
{string} EndingStepIDSet = ProductionStepIDSet diff StepWithSuccessorIDSet;
{string} StartingStepIDSet = ProductionStepIDSet diff StepWithPredecessorIDSet;

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
//    in 0..demand.deliveryMax
//    size precedence.delayMin
//         ..
//         precedence.delayMax
    ;

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

{TransitionMatrixItem} tankSetupTimeTransitionMatrix[t in StorageTanks] =
    {<p1, p2, time> | <t.setupMatrixId, p1, p2, time, cost> in Setups};

int tankSetupTime[t in StorageTanks][p1 in ProductIDSet union {-1}][p2 in ProductIDSet] =
    sum(<t.setupMatrixId, p1, p2, time, cost> in Setups) time;
    
stateFunction tankStoredProductState[tank in StorageTanks] with tankSetupTimeTransitionMatrix[tank];

cumulFunction tankStoredAmountOverTime[tank in StorageTanks] =
        sum(atfss in AlternativeTankForStorageStepSet :
                atfss.alternativeTank.storageTankId == tank.storageTankId
           ) pulse(alternativeTankForStorageStepInterval[atfss], atfss.demand.quantity);

//                       COSTS

pwlFunction tardinessFees[demand in Demands] = 
                piecewise{0->demand.dueTime; demand.tardinessVariableCost}(demand.dueTime, 0);
dexpr float TotalTardinessCost = sum(demand in Demands) endEval(demandInterval[demand], tardinessFees[demand]);

dexpr float TotalNonDeliveryCost = sum(demand in Demands)
                (1 - presenceOf(demandInterval[demand])) * (demand.quantity * demand.nonDeliveryVariableCost);

dexpr float TotalProcessingCost = sum(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet) 
                presenceOf(alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>])
                *(alternativeResource.fixedProcessingCost + demand.quantity * alternativeResource.variableProcessingCost);

dexpr float TotalSetupCost = sum(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet)
                            setupCostOfAlternativeResourceForProductionStep[<demand, step, alternativeResource>];

dexpr float WeightedTardinessCost = 
        TotalTardinessCost * item(CriterionWeights, <"TardinessCost">).weight;
dexpr float WeightedNonDeliveryCost = 
        TotalNonDeliveryCost * item(CriterionWeights, <"NonDeliveryCost">).weight;
dexpr float WeightedProcessingCost =
        TotalProcessingCost * item(CriterionWeights, <"ProcessingCost">).weight;
dexpr float WeightedSetupCost = 
        TotalSetupCost * item(CriterionWeights, <"SetupCost">).weight;

dexpr float TotalCost = WeightedTardinessCost + WeightedNonDeliveryCost + WeightedProcessingCost + WeightedSetupCost;

dexpr int PreviousProductOnResource[arfps in AlternativeResourceForProductionStepSet] =
    typeOfPrev
    (
        resourceScheduleIntervalSequence[item(Resources, <arfps.alternativeResource.resourceId>)],
        alternativeResourceForProductionStepInterval[arfps],
        item(Resources, <arfps.alternativeResource.resourceId>).initialProductId,
        -1
    );

execute {
    cp.param.Workers = 1;
 
    cp.param.DefaultInferenceLevel = "Medium";
    
    cp.param.restartfaillimit = 200;
    
    var f = cp.factory;
    
    // It appears that for larger instances, setting the search phase to first decide on the 
    // alternativeResourceForProductionStepIntervals results in no solutions being found, but without it,
    // it works fine on larger instances.
    if (maxDelayDiff < 200) {
       cp.setSearchPhases(f.searchPhase(alternativeResourceForProductionStepInterval));
    }
    
    //cp.param.TimeLimit = Opl.card(Demands) * 10;
    cp.param.TimeLimit = Opl.card(Demands);
}

minimize 
  TotalCost;
subject to {
    
    // End of the last steps must be before/after the demand's minimum/maximum delivery time.
    forall(<demand, step> in ProductionStepForDemandSet : step.stepId in EndingStepIDSet) {
        endOf(productionStepInterval[<demand,step>], demand.deliveryMin) >= demand.deliveryMin;
        endOf(productionStepInterval[<demand,step>], demand.deliveryMax) <= demand.deliveryMax;
    }
    
    // All resource setup intervals are just before the interval they are setting up.
    forall(arfps in AlternativeResourceForProductionStepSet)
        endAtStart(alternativeResourceForProductionStepSetupInterval[arfps], alternativeResourceForProductionStepInterval[arfps]);
    
    // Storage steps need to choose one of the available alternative tanks.
    forall(<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet)
        alternative(storageStepInterval[<demand, prevStep, nextStep, precedence>], 
            all(alternativeTank in StorageProductions :
                    alternativeTank.prevStepId == prevStep.stepId &&
                    alternativeTank.nextStepId == nextStep.stepId
               ) alternativeTankForStorageStepInterval[<demand, prevStep, nextStep, precedence, alternativeTank>]);
    
    // If a demand is chosen to be delivered, all the production steps it requires must be performed as well (and vice versa)
    forall(<demand, step> in ProductionStepForDemandSet)
        presenceOf(demandInterval[demand]) == presenceOf(productionStepInterval[<demand, step>]);
    
    // Each production step must use exactly one of the available alternative resources.
    forall(<demand, step> in ProductionStepForDemandSet)
        alternative(productionStepInterval[<demand, step>], 
            all(alternativeResource in Alternatives: alternativeResource.stepId == step.stepId) alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]);
    
    // Production steps using the same resource must not overlap.
    forall(resource in Resources)
        noOverlap(resourceScheduleIntervalSequence[resource], resourceSetupTimeTransitionMatrix[resource], 1);
    
        
    // Setting the setup time and cost of setups before each step. 
    forall(arfps in AlternativeResourceForProductionStepSet, resource in Resources :
            resource.resourceId == arfps.alternativeResource.resourceId) {

        presenceOf(alternativeResourceForProductionStepSetupInterval[arfps])
        ==
        presenceOf(alternativeResourceForProductionStepInterval[arfps]);
        
        // Constrain the length of setup intervals.
        lengthOf(alternativeResourceForProductionStepSetupInterval[arfps])
        ==
        resourceSetupTime
            [resource]
            [PreviousProductOnResource[arfps]]
            [arfps.demand.productId];
            
        // Constrain the cost of setup intervals.
        setupCostOfAlternativeResourceForProductionStep[arfps]
        == 
        resourceSetupCost
            [resource]
            [PreviousProductOnResource[arfps]]
            [arfps.demand.productId];
    }
        
    // Setup steps using the same setup resource must not overlap.
    forall(setupResource in SetupResources)
        noOverlap(setupResourceScheduleIntervalSequence[setupResource]);


    // Storage steps fit exactly between two consecutive production steps.
    forall(<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet)
    {
  
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
    
    forall(<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet)
    {      
        // Enforce precedences between production steps and min/max delay between them.
        endBeforeStart
        (
            productionStepInterval[<demand, prevStep>], 
            productionStepInterval[<demand, nextStep>], 
            maxl(precedence.delayMin, 0)
        );

        startBeforeEnd
        (
            productionStepInterval[<demand, nextStep>], 
            productionStepInterval[<demand, prevStep>], 
            minl(-precedence.delayMax, 0)
        );

        // Placing the following constraints here instead of upstairs with the rest of the storage constraints
        // seems to improve the result on Instance4 by about 4000.

        // The time between two consecutive production steps is equal to the length of the storage step between them 
        endAtStart
        (
            productionStepInterval[<demand, prevStep>],
            productionStepInterval[<demand, nextStep>], 
            lengthOf(storageStepInterval[<demand, prevStep, nextStep, precedence>])
        );

        // A storage step interval is present iff its length is more than 0.
        // This is done in order for a demand to be able to be transfered directly to the next production step if no storage is necessary
        // without having to perform a setup for the storage.
        presenceOf(storageStepInterval[<demand, prevStep, nextStep, precedence>])
        ==
        (lengthOf(storageStepInterval[<demand, prevStep, nextStep, precedence>]) > 0);  
    }

    // The production steps on a product of a demand should be span the demand's interval.
    forall(demand in Demands)
        span(demandInterval[demand], all(step in Steps : demand.productId == step.productId) productionStepInterval[<demand,step>]);
    
    // Storage steps on the same tank should not overlap for demands of different products.
    forall(atfss in AlternativeTankForStorageStepSet,
            tank in StorageTanks : tank.storageTankId == atfss.alternativeTank.storageTankId)
            alwaysEqual(tankStoredProductState[tank], alternativeTankForStorageStepInterval[atfss], atfss.demand.productId);

    // The maximum capacity of tanks should not be exceeded.
    forall(tank in StorageTanks) {
        tankStoredAmountOverTime[tank] <= tank.quantityMax;
    }

    // Storages after the first steps should start after a certain setup time if such is needed.
    forall
    (
        atfss in AlternativeTankForStorageStepSet,
        tank in StorageTanks : tank.storageTankId == atfss.alternativeTank.storageTankId && atfss.prevStep.stepId in StartingStepIDSet
    ) 
    { 
        // presenceOf => is better on all instances except Instance3.
        presenceOf(storageStepInterval[<atfss.demand, atfss.prevStep, atfss.nextStep, atfss.precedence>]) => 
            startOf(storageStepInterval[<atfss.demand, atfss.prevStep, atfss.nextStep, atfss.precedence>]) 
               >= tankSetupTime[tank][atfss.demand.productId][tank.initialProductId];
    }
    
    // Symmetry breaking constraint for different, but equivalent demands.
    // Only used on instances with more than 7 equivalent demands in order to not decrease the performance on the other ones.
    if(NumberOfEquivalentDemands > 7) {
        forall
        (
            demand1, demand2 in Demands :
                demand1.productId                   == demand2.productId &&
                demand1.deliveryMin                 == demand2.deliveryMin &&
                demand1.deliveryMax                 == demand2.deliveryMax &&
                demand1.dueTime                     == demand2.dueTime &&
                demand1.nonDeliveryVariableCost     == demand2.nonDeliveryVariableCost &&
                demand1.quantity                    == demand2.quantity &&
                demand1.tardinessVariableCost       == demand2.tardinessVariableCost &&
                demand1.demandId                    < demand2.demandId
                
        ) {
            startOf(demandInterval[demand1]) < startOf(demandInterval[demand2]);             
        }
    }    
};     
 

// Outputs
tuple DemandAssignment {
    key string demandId;
    int startTime;
    int endTime;
    float nonDeliveryCost;
    float tardinessCost;
};

{DemandAssignment} demandAssignments =
    {
        <
            demand.demandId,
            startOf(demandInterval[demand]),
            endOf(demandInterval[demand]),
            (1 - presenceOf(demandInterval[demand])) * (demand.quantity * demand.nonDeliveryVariableCost),
            endEval(demandInterval[demand], tardinessFees[demand])
        > | demand in Demands
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

            setupCostOfAlternativeResourceForProductionStep[<demand, step, alternativeResource>],

            startOf(alternativeResourceForProductionStepSetupInterval[<demand, step, alternativeResource>]), 
            endOf(alternativeResourceForProductionStepSetupInterval[<demand, step, alternativeResource>]),
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
   key string prevStepId;
   int startTime;
   int endTime;
   int quantity;
   string storageTankId;
};
{StorageAssignment} storageAssignments = 
    {
        <
            atfss.demand.demandId,
            atfss.prevStep.stepId,
            startOf(alternativeTankForStorageStepInterval[atfss]),
            endOf(alternativeTankForStorageStepInterval[atfss]),
            atfss.demand.quantity,
            atfss.alternativeTank.storageTankId
        > | atfss in AlternativeTankForStorageStepSet :
              presenceOf(alternativeTankForStorageStepInterval[atfss])
              && presenceOf(demandInterval[atfss.demand])
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
         writeln(sta.prevStepId, " of ", sta.demandId," produces quantity ", sta.quantity," in storage tank ", sta.storageTankId," at time ", sta.startTime," which is consumed at time ", sta.endTime);
     }
 }
 writeln();
}