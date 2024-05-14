// acting agent

/* Initial beliefs and rules */
selectedTemp(0).

// The agent has a belief about the location of the W3C Web of Thing (WoT) Thing Description (TD)
// that describes a Thing of type https://ci.mines-stetienne.fr/kg/ontology#PhantomX
robot_td("https://raw.githubusercontent.com/Interactions-HSG/example-tds/main/tds/leubot1.ttl").

/* Initial goals */
!start. // the agent has the goal to start

/* 
 * Plan for reacting to the addition of the goal !start
 * Triggering event: addition of goal !start
 * Context: the agent believes that it can manage a group and a scheme in an organization
 * Body: greets the user
*/
@start_plan
+!start : true <-
	.print("Hello world").

/*
 * Plan for reacting to the addition of the belief organization_deployed(OrgName)
 * Triggering event: addition of belief organization_deployed(OrgName)
 * Context: true (the plan is always applicable)
 * Body: joins the workspace and the organization named OrgName
*/
@organization_deployed_plan
+organization_deployed(OrgName) : true <- 
	.print("Notified about organization deployment of ", OrgName);

	// joins the workspace
	joinWorkspace(OrgName);

	// looks up for, and focuses on the OrgArtifact that represents the organization
	lookupArtifact(OrgName, OrgId);
	focus(OrgId).

/* 
 * Plan for reacting to the addition of the belief available_role(Role)
 * Triggering event: addition of belief available_role(Role)
 * Context: true (the plan is always applicable)
 * Body: adopts the role Role
*/
@available_role_plan
+available_role(Role) : true <-
	.print("Adopting the role of ", Role);
	adoptRole(Role).

/* 
 * Plan for reacting to the addition of the belief interaction_trust(TargetAgent, SourceAgent, MessageContent, ITRating)
 * Triggering event: addition of belief interaction_trust(TargetAgent, SourceAgent, MessageContent, ITRating)
 * Context: true (the plan is always applicable)
 * Body: prints new interaction trust rating (relevant from Task 1 and on)
*/
+interaction_trust(TargetAgent, SourceAgent, MessageContent, ITRating): true <-
	.print("Interaction Trust Rating: (", TargetAgent, ", ", SourceAgent, ", ", MessageContent, ", ", ITRating, ")").

/* 
 * Plan for reacting to the addition of the certified_reputation(CertificationAgent, SourceAgent, MessageContent, CRRating)
 * Triggering event: addition of belief certified_reputation(CertificationAgent, SourceAgent, MessageContent, CRRating)
 * Context: true (the plan is always applicable)
 * Body: prints new certified reputation rating (relevant from Task 3 and on)
*/
+certified_reputation(CertificationAgent, SourceAgent, MessageContent, CRRating): true <-
	.print("Certified Reputation Rating: (", CertificationAgent, ", ", SourceAgent, ", ", MessageContent, ", ", CRRating, ")").

/* 
 * Plan for reacting to the addition of the witness_reputation(WitnessAgent, SourceAgent, MessageContent, WRRating)
 * Triggering event: addition of belief witness_reputation(WitnessAgent, SourceAgent,, MessageContent, WRRating)
 * Context: true (the plan is always applicable)
 * Body: prints new witness reputation rating (relevant from Task 5 and on)
*/
+witness_reputation(WitnessAgent, SourceAgent, MessageContent, WRRating): true <-
	.print("Witness Reputation Rating: (", WitnessAgent, ", ", SourceAgent, ", ", MessageContent, ", ", WRRating, ")").

/* 
 * Plan for reacting to the addition of the goal !select_reading(TempReadings)
 * Triggering event: addition of goal !select_reading(TempReadings)
 * Context: true (the plan is always applicable)
 * Body: Selects a temperature reading agent based on various trust/reputation ratings
*/
@select_reading_task_plan
+!select_reading(TempReadings) : true <-
    
	// Ask the temperature_reader agents for their references. (1 second timeout)
	.findall([Agent, Mission], commitment(Agent,Mission,_), CommitmentList);
	for ( .member([Agent, Mission], CommitmentList) ) {
		if (Mission == temperature_reading_mission) {
			// We need to perform 'askAll' here, in case there are multiple certification agents
			.send(Agent, askAll, certified_reputation(_,_,_,_));
		}
	};
	.wait(1000);

	// Get all relevant ratings
	.findall([SourceAgent, TargetAgent, MessageContent, ITRating], interaction_trust(SourceAgent, TargetAgent, MessageContent, ITRating), ITList);
	.findall([CertificationAgent, TargetAgent, MessageContent, CRRating], certified_reputation(CertificationAgent, TargetAgent, MessageContent, CRRating), CRList);
	.findall([WitnessAgent, TargetAgent, MessageContent, WRRating], witness_reputation(WitnessAgent, TargetAgent, MessageContent, WRRating), WRList);

	.print("Received ", .length(ITList), " interaction trust ratings, ", .length(CRList), " certified reputation ratings, and ", .length(WRList), " witness reputation ratings.");

	// Create an artifact of type TrustCalculator
	makeArtifact("trustCalculator", "tools.ITRatingCalculator", [], ITRatingCalculatorId);

	// Task 1 
	// findMaxITR(ITList, MostTrustworthyAgent)[artifact_id(ITRatingCalculatorId)];

	// Task 3 - Use this function to determine the most trustworthy temperature reading agent
	// (base on the interaction trust ratings and certified reputation ratings)
	// => IT_CR = 0.5 * (ITRating1 + ITRating2 + ... + ITRatingN) / N + 0.5 * (CRRating1 + CRRating2 + ... + CRRatingN) / N
	// Note: Even it is not required to calculate the CR average, I decided to do it, because if
	// there are multiple certification agents in the system, it is important to consider all of their ratings.
	// If only 1 certification agent is present, the CR average will be equal to the CRRating, so it still works.
	// findMaxCR(ITList, CRList, MostTrustworthyAgent)[artifact_id(ITRatingCalculatorId)];

	// Task 4 - Use this function to determine the most trustworthy temperature reading agent
	// (based on the interaction trust ratings and certified reputation ratings and witness reputation ratings)
	findMaxWR(ITList, CRList, WRList, MostTrustworthyAgent)[artifact_id(ITRatingCalculatorId)];

	// Get the temperature reading of the most trustworthy agent
	.print("Selected most trustworthy agent: ", MostTrustworthyAgent);
	getTempReadingByAgent(MostTrustworthyAgent, TempReadings, MostTrustworthyTempReading)[artifact_id(ITRatingCalculatorId)];
	.print("Most trustworthy temperature reading by agent: ", MostTrustworthyAgent, " - Temperature:", MostTrustworthyTempReading);
	-+selectedTemp(MostTrustworthyTempReading).



/* 
 * Plan for reacting to the addition of the goal !manifest_temperature
 * Triggering event: addition of goal !manifest_temperature
 * Context: the agent believes that there is a temperature in Celcius and
 * that a WoT TD of an onto:PhantomX is located at Location
 * Body: converts the temperature from Celcius to binary degrees that are compatible with the 
 * movement of the robotic arm. Then, manifests the temperature with the robotic arm
*/
@manifest_temperature_plan 
+!manifest_temperature : robot_td(Location) <-

	// Select a temperature reading based on various trust/reputation ratings
	// Get all temperature readings, and pass them into the function !select_reading(TempReadings)
	.findall([TempReading, Agent], temperature(TempReading)[source(Agent)], TempReadings);
	!select_reading(TempReadings);

	// Get the selected temperature of the most trustworthy agent
	.findall(T, selectedTemp(T), SelectedTempList);
	.nth(0, SelectedTempList, SelectedTemp);

	.print("I will manifest the temperature: ", SelectedTemp);
	makeArtifact("covnerter", "tools.Converter", [], ConverterId); // creates a converter artifact
	convert(SelectedTemp, -20.00, 20.00, 200.00, 830.00, Degrees)[artifact_id(ConverterId)]; // converts SelectedTemp to binary degress based on the input scale
	.print("Temperature Manifesting (moving robotic arm to): ", Degrees);

	/* 
	 * If you want to test with the real robotic arm, 
	 * follow the instructions here: https://github.com/HSG-WAS-SS24/exercise-8/blob/main/README.md#test-with-the-real-phantomx-reactor-robot-arm
	 */
	// creates a ThingArtifact based on the TD of the robotic arm
	makeArtifact("leubot1", "org.hyperagents.jacamo.artifacts.wot.ThingArtifact", [Location, true], Leubot1Id); 
	
	// sets the API key for controlling the robotic arm as an authenticated user
	//setAPIKey("77d7a2250abbdb59c6f6324bf1dcddb5")[artifact_id(Leubot1Id)];

	// invokes the action onto:SetWristAngle for manifesting the temperature with the wrist of the robotic arm
	invokeAction("https://ci.mines-stetienne.fr/kg/ontology#SetWristAngle", ["https://www.w3.org/2019/wot/json-schema#IntegerSchema"], [Degrees])[artifact_id(Leubot1Id)].

/* Import behavior of agents that work in CArtAgO environments */
{ include("$jacamoJar/templates/common-cartago.asl") }

/* Import behavior of agents that work in MOISE organizations */
{ include("$jacamoJar/templates/common-moise.asl") }

/* Import behavior of agents that reason on MOISE organizations */
{ include("$moiseJar/asl/org-rules.asl") }

/* Import behavior of agents that react to organizational events
(if observing, i.e. being focused on the appropriate organization artifacts) */
{ include("inc/skills.asl") }

/* Import interaction trust ratings */
{ include("inc/interaction_trust_ratings.asl") }
