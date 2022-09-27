/**
* Name: Parte3
* Objetivo: Medir contaminación
* Author: Lili
* Tags: 
*/


model Parte3

import "Traffic.gaml"

global {
	float 	traffic_light_interval parameter: 'Traffic light interval' init: 30#s;
	float 	seed 					<- 42.0;
	float 	step 					<- 0.5#s;
	date 	starting_date 			<- date([2022,10,8,0,0,0]);
	string 	scenario 				<- "experimento_1";
	string 	output_path 			<- "../includes/output/";
	bool 	export					<- false;
	bool 	activate_intervention 	<- false;

	string map_name 				<- "rouen";
	file shp_roads 					<- file("../includes/" + map_name + "/roads.shp");
	file shp_nodes 					<- file("../includes/" + map_name + "/nodes.shp");

	geometry shape 					<- envelope(shp_roads) + 50;
	
	int num_cars;
	int num_motorbikes;

	graph road_network;
	map edge_weights;
	list<intersection_recolector> non_deadend_nodes;
	
	// Variable para almacenar el no. de coches esperando para cruzar una intersección
	map<string,int> congestioned_road <- ["Top1"::0,"Top2"::0,"Top3"::0,"Top4"::0,"Top5"::0];
	float avg_pollution <- 0.0;
	
	init {
		create road from: shp_roads {
			num_lanes 		<- rnd(4, 6);
			// Crear un camino en la dirección opuesta
			create road 
			{
				num_lanes 			<- myself.num_lanes;
				shape 				<- polyline(reverse(myself.shape.points));
				maxspeed 			<- myself.maxspeed;
				linked_road 		<- myself;
				myself.linked_road 	<- self;
			}
		}
		
		create intersection_recolector from: shp_nodes with: [is_traffic_signal::(read("type") = "traffic_signals")] 
		{
			time_to_change <- traffic_light_interval;
		}
		
		// Crea un grafo donde los pesos son representados por la distancia
		edge_weights 		<- road as_map (each::each.shape.perimeter);
		road_network 		<- as_driving_graph(road, intersection_recolector) with_weights edge_weights;
		non_deadend_nodes 	<- intersection_recolector where !empty(each.roads_out);
		
		// Initialize the traffic lights
		ask intersection_recolector {
			do initialize;
		}
		
		create motorbike number: num_motorbikes;
		create car number: num_cars;
	}
	
	
	// Reflejo que permite pausar la simulación
	reflex stop_simulation when: cycle = 600
	{
		do pause;
	}
	
	
	// Reducir y difundir la contaminación
	reflex pollution_evolution{
		//pide a todas las celdas que disminuyan su nivel de contaminación
		ask cell {pollution <- pollution * 0.7;}
		
		// Difundir la contaminación en las celdas vecinas
		diffuse var: pollution on: cell proportion: 0.9 ;
		
		do save_pollution;
	}
	
	
	action save_pollution
	{
		avg_pollution <- mean(cell collect each.pollution);
		
		if export 
		{
			save data:[   cycle
						, avg_pollution
			] to:output_path+scenario+"_overall.csv" type:csv rewrite:false;
			
			
			ask intersection_recolector 
			{
				do measure_pollution;
				save data:[   cycle
							, name
							, pollution_measure
				] to:output_path+scenario+"_intersection.csv" type:csv rewrite:false;
			}			
		}
	}
}



species intersection_recolector parent: intersection
{
	float pollution_measure;
	int cars_crossing;
	map<int,int> vehicles_crossing_record <- [];

	action measure_pollution
	{
		pollution_measure <- mean((cell overlapping location) collect each.pollution);
	}
	
	reflex measure_poll when:every(5#cycles)
	{
		do measure_pollution;
	}
}


species vehicle_sim parent: base_vehicle {
	float pollution_generated <- 10.0;
	bool recompute_path <- false;
	list<intersection_recolector> dst_nodes;
	                      
	intersection_recolector current_target_t;
	
	init {
		road_graph 			<- road_network;
		location 			<- one_of(non_deadend_nodes).location;
		right_side_driving 	<- false;
	}
 
 
                            
	reflex select_next_path when: current_path = nil 
	{
		dst_nodes <- sample(list(intersection_recolector),2,false);
		
		do compute_path graph: road_network nodes: dst_nodes;
		current_target_t <-  intersection_recolector first_with (each.name = current_target.name);
	}
	


	reflex commute when: current_path != nil 
	{
		do drive;
		
		ask (cell overlapping location) 
		{
			pollution <- pollution + myself.pollution_generated;
		}
		
	}		

}


species motorbike parent: vehicle_sim {
	init {
		vehicle_length 				<- 1.9#m;
		num_lanes_occupied 			<- 1;
		max_speed 					<- (50 + rnd(20)) #km / #h;

		proba_block_node 			<- 0.0;
		proba_respect_priorities 	<- 1.0;
		proba_respect_stops 		<- [1.0];
		proba_use_linked_road 		<- 0.8;

		lane_change_limit 			<- 2;		
		linked_lane_limit 			<- 1;
	}
}

species car parent: vehicle_sim {
	road road_on;
	init {
		vehicle_length 				<- 3.8 #m;
		num_lanes_occupied 			<- 2;
		max_speed 					<- (60 + rnd(10)) #km / #h;
				
		proba_block_node 			<- 0.0;
		proba_respect_priorities 	<- 1.0;
		proba_respect_stops 		<- [1.0];
		proba_use_linked_road 		<- 0.0;

		lane_change_limit 			<- 2;			
		linked_lane_limit 			<- 0;
	}
}


grid cell height: 100 width: 100 neighbors: 100
{
	//Nivel de contaminación 
	float pollution <- 0.0 min: 0.0 max: 100.0;
	
	//Actualización de color (Rojo - alta conaminación / Verde - no contaminación)
	rgb color <- #green update: rgb(255 *(pollution/30.0) , 255 * (1 - (pollution/30.0)), 0.0);
}



experiment city type: gui {
	action _init_{
		create simulation with:[
			 seed::10.0
			,map_name::"rouen"
			,num_cars::2000
			,num_motorbikes::20
		];
	}

	output synchronized: true {
		layout #split;
		display map type: opengl background: #gray  axes:false{
			species road aspect: base;
			species intersection_recolector aspect: base;
			species motorbike aspect: base;
			species car aspect: base;
			
			//Capa que muestra el nivel de contaminación
			grid cell elevation: pollution * 3.0 triangulation: true transparency: 0.7;
		
		}
		
	
	}
		
}

