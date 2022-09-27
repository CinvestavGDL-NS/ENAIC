/**
* Name: Tutorial1
* Objetivo:  Cargar mapa (nodos y aristas) y librerías
* Author: Lili
* Tags: 
*/


model Parte1

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
	

	graph road_network;
	map edge_weights;
	list<intersection_recolector> non_deadend_nodes;
	
	// Variable para almacenar el no. de coches esperando para cruzar una intersección
	map<string,int> congestioned_road <- ["Top1"::0,"Top2"::0,"Top3"::0,"Top4"::0,"Top5"::0];

	
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
		
		
	}
	
	
	// Reflejo que permite pausar la simulación
	reflex stop_simulation when: cycle = 600
	{
		do pause;
	}
}



species vehicle_random parent: base_vehicle {
	float pollution_generated <- 10.0;
	bool recompute_path <- false;
	list<intersection_recolector> dst_nodes;
	                      
	intersection_recolector current_target_t;
	
	init {
		road_graph 			<- road_network;
		location 			<- one_of(non_deadend_nodes).location;
		right_side_driving 	<- false;
	}	
}



species intersection_recolector parent: intersection
{
	float pollution_measure;
	int cars_crossing;
	map<int,int> vehicles_crossing_record <- [];

	
}





experiment city type: gui {
	action _init_{
		create simulation with:[
			 seed::10.0
			,map_name::"rouen"
		];
	}

	output synchronized: true {
		layout #split;
		display map type: opengl background: #gray  axes:false{
			species road aspect: base;
			species intersection_recolector aspect: base;
		}
		
	
	}
		
}
