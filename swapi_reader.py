#!/usr/bin/env python
import json
import logging
from os import makedirs
from os import path

import requests

# Reference:
# films: {"title":"...","url": "https://swapi.co/api/films/1/",
#   "characters":[".../people/1/"], "planets":[...], "starships":[], "vehicles": [], "species": []}
# people {"name": "...", "url": ".../people/1/", "species":[],"vehicles": [], "starships": []}
# planet {"name":"...", "residents":[".../people/5/"], "films": [], "url": ".../planets/2"}
# species: {"name":"Human", "people":[], "films": [...], "url": "..."}
# starships: {"name":"...", "films": [...], "url": ".../starships/15/"}
# vehicles: {"name":"...", "films": [...], "url": ".../starships/15/"}

class SwapiReader():
    DATA_DIR = path.join(path.dirname(path.realpath(__file__)), "_data")

    def __init__(self, data_dir = None):
        self._data = dict()
        self._path = dict()

        self._data_dir = data_dir if data_dir else SwapiReader.DATA_DIR
        if not path.exists(self._data_dir):
            makedirs(self._data_dir)

    def run(self):
        self._load_data()

        # display people data:
        print("-- people => planet / starships -- ")
        for dt in self._data["people"]:
            planet = self._people_planet_map.get(dt["url"], dict()).get("name", "n/a")
            starships = [self._starship_map[s]["name"] for s in dt["starships"]]
            print("{}=> planet: {} / starships: {}".format(dt["name"], planet, starships))

        # display planet data:
        print("\n-- planet => species --")
        for dt in self._data["planets"]:
            species = set()
            for p_url in dt["residents"]:
                for s_url in self._people_map[p_url]["species"]:
                    species.add(self._species_map[s_url]["name"])
            if len(species) > 1:
                print("{}=> {}".format(dt["name"], str(species) if species else "{}"))

    def _load_local_json(self, target):
        self._path[target] = path.join(self._data_dir, target + ".json")
        if path.isfile(self._path[target]):
            with open(self._path[target], "r") as json_file:
                self._data[target] = json.load(json_file)

    def _fetch_json(self, target):
        logging.info("-- fetch {}...".format(target))
        self._load_local_json(target)   # to reduce hit on external service, use local copy after the 1st time.
        if self._data.get(target, None):
            return self._data[target]

        dtList = list()
        next_page = "https://swapi.co/api/{}".format(target)
        while True:
            response = requests.get(next_page)
            data = response.json()
            dtList.extend(data.get("results", None))

            next_page = data.get('next')
            if not next_page:
                break

        logging.info("Count expected: {}. Actual: {}.".format(data["count"], len(dtList)))
        with open(self._path[target], "w") as fout:
            json.dump(dtList, fout)

        self._data[target] = dtList
        return self._data[target]

    def _parse_planet_data(self):
        # people url -> planet
        dtList = self._data["planets"]
        planet_map = dict()
        people_planet_map = dict()
        for dt in dtList:
            planet_map[dt["url"]] = dt
            for p_url in dt["residents"]:
                people_planet_map[p_url] = dt
        self._planet_map = planet_map
        self._people_planet_map = people_planet_map

    def _parse_starships_data(self):
        dtList = self._data["starships"]
        starship_map = dict()
        for dt in dtList:
            starship_map[dt["url"]] = dt
        self._starship_map = starship_map

    def _parse_species_data(self):
        dtList = self._data["species"]
        species_map = dict()
        for dt in dtList:
            species_map[dt["url"]] = dt
        self._species_map = species_map

    def _parse_people_data(self):
        dtList = self._data["people"]
        people_map = dict()
        for dt in dtList:
            people_map[dt["url"]] = dt
        self._people_map = people_map

    def _load_data(self):
        for tgt in ["films", "people", "planets", "species", "starships", "vehicles"]:
            self._fetch_json(tgt)

        # build references
        self._parse_planet_data()
        self._parse_starships_data()
        self._parse_species_data()
        self._parse_people_data()


if __name__ == "__main__":
    fetcher = SwapiReader()
    fetcher.run()
