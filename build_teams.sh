#!/bin/bash

run(){

	#Parse arguments
	local OPTIND

	while getopts f:t: flag
	 do
		case "${flag}" in
			f) #path to csv file containing team names. Must end with newline char.
				file=($OPTARG);;
			t) #types of installers to create. Pass an individual flag for each type
				types+=($OPTARG);;
		esac
	 done
  
	#Set up installer types. Default to deb, pkg and msi if not specified or "all".
	if [[ (-z $types ) || ($types == "all")]]
	 	then 
		types=("deb" "pkg" "msi" "rpm")
	fi
	#Verify that passed filepath exists
	if !(test -f $file)
		then
			echo "File not found"
			return
  fi

  create_teams
}

create_teams(){
  #Loop through csv and generate yaml to apply
	while IFS=, read -r name
		do
		  if [[ "$name" != "Name" ]] 
				then
					secret=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/random | head -c 24);
					add_team_to_fleet
					wait
					generate_packages
					wait
			fi
		done < $file
}


add_team_to_fleet(){

  #Generate yml based on template provided
	rm -f final.yml temp.yml

	( echo "cat <<EOF >final.yml";
	cat team_config.yml;
	) >temp.yml
	. temp.yml

  # Apply the new team to fleet
	echo "Adding team to Fleet: $name"
	# fleetctl apply -f final.yml
	wait
}

generate_packages(){
	echo "Generating installers for $name"
	echo "The whole list of values is '${types[@]}'"
  
  name_formatted=$(printf "$name" | tr '[:upper:]' '[:lower:]' | tr -s ' ' | tr ' ' '_')

	if !(test -d $name_formatted)
		then
				mkdir $name_formatted
	fi
  
	for type in ${types[@]}
  do
		fleetctl package --type=$type --fleet-desktop --fleet-url=https://dogfood.fleetdm.com --enroll-secret=$secret
		wait
		find . -type f -name 'fleet-osquery*' -exec mv -f {} $name_formatted/fleet_osquery_$name_formatted.$type ';'
	done
}
run "$@"



