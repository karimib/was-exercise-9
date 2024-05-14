// rogue agent is a type of sensing agent

/* Initial beliefs and rules */
// Here we store the witness ratings of the rogue agents
// that they have for the other agents.
all_present_agents_witness_ratings(
  [sensing_agent_1, sensing_agent_2, sensing_agent_3, sensing_agent_4, sensing_agent_5, sensing_agent_6, sensing_agent_7, sensing_agent_8, sensing_agent_9],
  [-1, -1, -1, -1, 1, 1, 1, 1, 1]
).

/* Initial goals */
!set_up_plans. // the agent has the goal to add pro-rogue plans

/* 
 * Plan for reacting to the addition of the goal !set_up_plans
 * Triggering event: addition of goal !set_up_plans
 * Context: true (the plan is always applicable)
 * Body: adds pro-rogue plans for reading the temperature without using a weather station
*/
+!set_up_plans : true
<-
  // removes plans for reading the temperature with the weather station
  .relevant_plans({ +!read_temperature }, _, LL);
  .remove_plan(LL);
  .relevant_plans({ -!read_temperature }, _, LL2);
  .remove_plan(LL2);

  // adds a new plan for sending a witness_reputation to the acting agent,
  // when the agent receives a temperature reading from another temperature reader agent.
  .add_plan({ +temperature(Celsius)[source(Sender)] : true <-
    .print("Received temperature reading from ", Sender, ": ", Celsius);
    // Sending witness_reputation to the acting agent
    .findall([Agents, WRRatings], all_present_agents_witness_ratings(Agents, WRRatings), WRRatingsList);
    .nth(0, WRRatingsList, WR);
    .nth(0, WR, Agents);
    .nth(1, WR, WRRatings);
    .my_name(Name);
    for ( .range(I,0,8) ) {
      .nth(I, Agents, Agent);
      .nth(I, WRRatings, WRRating);
      if (Sender == Agent & Agent \== Name) {
        .print("Sending witness reputation to acting_agent: witness_reputation(", Name, ", ", Agent, ", temperature(", Celsius, "), ", WRRating, ")");
          .send(acting_agent, tell, witness_reputation(Name, Agent, temperature(Celsius), WRRating));
      };
    };
  });

  // Adds plan for relaying the temperature reading of the rogue leader agent.
  // Note 1: This plan now sends whatever the rogue leader agent is sending.
  // Note 2: No need for wating for multiple readings anymore.
  // Note 3: We need to abolish the temperature belief, otherwise the rogue could broadcast a deprecated reading.
  .add_plan({ +!read_temperature : temperature(RogueLeaderTempReading)[source(Agent)] & Agent == sensing_agent_9 <-
      .print("Read temperature (relaying) of rogue leader agent (Celcius): ", RogueLeaderTempReading);
      .broadcast(tell, temperature(RogueLeaderTempReading)) });
      .abolish(temperature(_));
  
  // Adds default plan for when the goal read_temperature has been received,
  // but no temperature reading has been received yet by the rogue leader agent.
  .add_plan({ +!read_temperature : true <-
    .print("Rogue agent needs to wait for the rogue leader agent to broadcast the temperature reading.");
    // temperature reading from rogue leader agent not yet received.
    // wait for 50ms and try again
    .wait(50);
    !read_temperature;
  }).

  

/* Import behavior of sensing agent */
{ include("sensing_agent.asl")}