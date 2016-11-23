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

{TransitionMatrixItem} setupTimesResourceScheduleIntervalSequence[resource in Resources] =
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

// get the stepID's of steps that are last. The storage after these steps will be 0 0 0.
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
         precedence.delayMax
    ;

// The time bounds depend both on the previous and following step, but it seems like this is only calculating it based on the previous step??
{TransitionMatrixItem} tankSetupTimeTransitionMatrix[t in StorageTanks] =
    {<p1, p2, time> | <t.setupMatrixId, p1, p2, time, cost> in Setups};

int tankSetupTime[t in StorageTanks][p1 in ProductIDSet union {-1}][p2 in ProductIDSet] =
    sum(<t.setupMatrixId, p1, p2, time, cost> in Setups) time;
    
stateFunction tankStoredProductState[tank in StorageTanks] with tankSetupTimeTransitionMatrix[tank];

cumulFunction tankStoredAmountOverTime[tank in StorageTanks] =
        sum(<demand, prevStep, nextStep, precedence, alternativeTank> in AlternativeTankForStorageStepSet :  // all storage tanks available for a storage step
                alternativeTank.storageTankId == tank.storageTankId
           ) pulse(alternativeTankForStorageStepInterval[<demand, prevStep, nextStep, precedence, alternativeTank>], demand.quantity);

//                       COSTS

pwlFunction tardinessFees[demand in Demands] = 
                piecewise{0->demand.dueTime; demand.tardinessVariableCost}(demand.dueTime, 0);
dexpr float TotalTardinessCost = sum(demand in Demands) endEval(demandInterval[demand], tardinessFees[demand]);

dexpr float TotalNonDeliveryCost = sum(demand in Demands)
                (1 - presenceOf(demandInterval[demand])) * (demand.quantity * demand.nonDeliveryVariableCost);

dexpr float TotalProcessingCost = sum(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet) 
                presenceOf(alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>])
                *(alternativeResource.fixedProcessingCost + demand.quantity * alternativeResource.variableProcessingCost);

//dexpr float SetupCost = 0; 
dexpr float TotalSetupCost = sum(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet)
                            setupCostOfAlternativeResourceForProductionStep[<demand, step, alternativeResource>];
//                      + sum(<<demand,step>,storProd> in StorageAfterProdStepAlternative)
//                          costStorageAfterProdStepAlternatives[<<demand,step>,storProd>]; 

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
 
    if (Opl.card(Demands) < 33) {
       cp.setSearchPhases(f.searchPhase(alternativeResourceForProductionStepInterval));
    }
    
//    cp.param.TimeLimit = Opl.card(Demands) * 10;
    cp.param.TimeLimit = Opl.card(Demands);
}

minimize 
  TotalCost;
subject to {
    
    //end of the last steps must be after the mindeliverytime.
    forall(<demand, step> in ProductionStepForDemandSet : step.stepId in EndingStepIDSet) {
        endOf(productionStepInterval[<demand,step>], demand.deliveryMin) >= demand.deliveryMin;
        endOf(productionStepInterval[<demand,step>], demand.deliveryMax) <= demand.deliveryMax;
    }
    
//    
    
    // All resource setup intervals are just before the interval they precede
    forall(<demand, step, alternativeResource> in AlternativeResourceForProductionStepSet)
        endAtStart(alternativeResourceForProductionStepSetupInterval[<demand, step, alternativeResource>], alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]);
    
    // storages need to chose which tank to use. chose just one alternative each
    forall(<demand, prevStep, nextStep, precedence> in StorageStepForDemandSet)
        alternative(storageStepInterval[<demand, prevStep, nextStep, precedence>], 
            all(alternativeTank in StorageProductions :
                    alternativeTank.prevStepId == prevStep.stepId &&
                    alternativeTank.nextStepId == nextStep.stepId
               ) alternativeTankForStorageStepInterval[<demand, prevStep, nextStep, precedence, alternativeTank>]);
    
    // If a demand is present, all the steps it requires must be present too (and vice versa)
    forall(<demand,step> in ProductionStepForDemandSet)
        presenceOf(demandInterval[demand]) == presenceOf(productionStepInterval[<demand,step>]);
    
    // Every step must be one and only one of it's alternatives 
    forall(<demand,step> in ProductionStepForDemandSet)
        alternative(productionStepInterval[<demand,step>], 
            all(alternativeResource in Alternatives: alternativeResource.stepId == step.stepId) alternativeResourceForProductionStepInterval[<demand, step, alternativeResource>]);
    
    // steps using the same resource must not overlap
    forall(resource in Resources)
        noOverlap(resourceScheduleIntervalSequence[resource], setupTimesResourceScheduleIntervalSequence[resource], 1);
    
        
    // setting the setup time and cost of setups before each step. 
    forall(arfps in AlternativeResourceForProductionStepSet, resource in Resources 
                    : resource.resourceId == arfps.alternativeResource.resourceId) {
        presenceOf(alternativeResourceForProductionStepSetupInterval[arfps])
        ==
        presenceOf(alternativeResourceForProductionStepInterval[arfps]);
        
        setupLenConstraint: 
        lengthOf(alternativeResourceForProductionStepSetupInterval[arfps])
        ==
        resourceSetupTime
        [resource]
        [PreviousProductOnResource[arfps]]
        [arfps.demand.productId];
            
        setupCostConstraint:
        setupCostOfAlternativeResourceForProductionStep[arfps]
        == 
        resourceSetupCost
        [resource]
        [PreviousProductOnResource[arfps]]
        [arfps.demand.productId];
    }
        
    // setups using the same setup resource must not overlap
    forall(stpRes in SetupResources)
        noOverlap(setupResourceScheduleIntervalSequence[stpRes]);


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
        // Enforce precedences and min/max delay between them.
        endBeforeStart(productionStepInterval[<demand, prevStep>], productionStepInterval[<demand, nextStep>], maxl(precedence.delayMin, 0));
        startBeforeEnd(productionStepInterval[<demand, nextStep>], productionStepInterval[<demand, prevStep>], minl(-precedence.delayMax, 0));

        // TODO add storages between each 2 successive production steps
        // TODO Each storage step needs to fit exactly between the two production steps around it.
        endAtStart
        (
            productionStepInterval[<demand, prevStep>],
            productionStepInterval[<demand, nextStep>], 
            lengthOf(storageStepInterval[<demand, prevStep, nextStep, precedence>])
        );

        presenceOf(storageStepInterval[<demand, prevStep, nextStep, precedence>]) == (lengthOf(storageStepInterval[<demand, prevStep, nextStep, precedence>]) > 0);  
        // The intervals for all production steps for a demand must have the same presence value.
        //presenceOf(productionStepInterval[<demand, prevStep>]) == presenceOf(productionStepInterval[<demand, nextStep>]);
  
    }

    // the steps on a product of a demand should be spanned in the demand interval
    forall(demand in Demands)
        span(demandInterval[demand], all(step in Steps : demand.productId == step.productId) productionStepInterval[<demand,step>]);
    
    // tank intervals with different products and same tank should not overlap
    forall(atfss in AlternativeTankForStorageStepSet,
            tank in StorageTanks : tank.storageTankId == atfss.alternativeTank.storageTankId)
            alwaysEqual(tankStoredProductState[tank], alternativeTankForStorageStepInterval[atfss], atfss.demand.productId);

    // tank should not overfill
    forall(tank in StorageTanks) {
        CumulConstraint:
            tankStoredAmountOverTime[tank] <= tank.quantityMax;
    }

    //storages after the first steps should start after a certain setup time if such is needed.
    //presenceof => is much better on all instances except 3.
    forall
    (
        atfss in AlternativeTankForStorageStepSet,
        tank in StorageTanks : tank.storageTankId == atfss.alternativeTank.storageTankId && atfss.prevStep.stepId in StartingStepIDSet
    ) 
    { 
        presenceOf(storageStepInterval[<atfss.demand, atfss.prevStep, atfss.nextStep, atfss.precedence>]) => 
            startOf(storageStepInterval[<atfss.demand, atfss.prevStep, atfss.nextStep, atfss.precedence>]) 
               >= tankSetupTime[tank][atfss.demand.productId][tank.initialProductId];
    }
    
    if(card(Demands) > 33) {
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
// writeln("Total Non-Delivery Cost : ", TotalNonDeliveryCost);
// writeln("Total Processing Cost : ", TotalProcessingCost);
// writeln("Total Setup Cost : ", TotalSetupCost);
// writeln("Total Tardiness Cost : ", TotalTardinessCost);
// writeln();
// writeln("Weighted Non-Delivery Cost : ",WeightedNonDeliveryCost);
// writeln("Weighted Processing Cost : ", WeightedProcessingCost);
// writeln("Weighted Setup Cost : ", WeightedSetupCost);
// writeln("Weighted Tardiness Cost : ", WeightedTardinessCost);
// writeln();
 writeln("Total Weighted Cost :", TotalCost);
 writeln(); // ? shown in example output, absent from example code
 
// for(var d in demandAssignments) 
// {
//     writeln(d.demandId, ": [",  d.startTime, ",", d.endTime, "] ");
//     writeln(" non-delivery cost: ", d.nonDeliveryCost,  ", tardiness cost: " , d.tardinessCost);
// }
// writeln();
// for(var sa in stepAssignments) {
//     writeln(sa.stepId, " of ", sa.demandId,": [", sa.startTime, ",", sa.endTime, "] ","on ", sa.resourceId);
//     write(" processing cost: ", sa.procCost);
//     if (sa.setupCost > 0)
//         write(", setup cost: ", sa.setupCost);
//     writeln();
//     if (sa.startTimeSetup < sa.endTimeSetup)
//         writeln(" setup step: [",sa.startTimeSetup, ",", sa.endTimeSetup, "] ","on ", sa.setupResourceId);
// }
// writeln();
// for(var sta in storageAssignments) {
//     if (sta.startTime < sta.endTime) {
//         writeln(sta.prevStepId, " of ", sta.demandId," produces quantity ", sta.quantity," in storage tank ", sta.storageTankId," at time ", sta.startTime," which is consumed at time ", sta.endTime);
//     }
// }
// writeln();
}